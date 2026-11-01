import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../interfaces/ai_provider.dart';
import '../models/ai_errors.dart';
import '../models/ai_model_config.dart';
import '../models/ai_request.dart';
import '../models/ai_response.dart';
import '../models/cancel_token.dart';
import '../security/ai_credential_storage.dart';

/// Production-ready Google Gemini AI REST provider.
/// Implements official v1beta generateContent and SSE streamGenerateContent APIs.
/// Zero-key logging, bounded retries on transient errors, cancellation support.
class GeminiRestAiProvider implements AiProvider {
  static const String defaultBaseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  final AiCredentialStorage credentialStorage;
  final http.Client _client;
  final String _baseUrl;

  GeminiRestAiProvider({
    required this.credentialStorage,
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? defaultBaseUrl;

  @override
  String get providerName => 'gemini_rest_ai_provider';

  @override
  Future<bool> verifyCredentials() async {
    final apiKey = await credentialStorage.getApiKey();
    if (apiKey == null || apiKey.isEmpty) return false;

    try {
      final customProxy = await credentialStorage.getCustomProxyUrl();
      final base = customProxy?.isNotEmpty == true ? customProxy! : _baseUrl;
      final uri = Uri.parse('$base/models?pageSize=1');

      final response = await _client.get(
        uri,
        headers: {
          'x-goog-api-key': apiKey,
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<AiTextResponse> generateText(
    AiPromptRequest request, {
    AiModelConfig? config,
    Duration timeout = const Duration(seconds: 30),
    CancelToken? cancelToken,
  }) async {
    final apiKey = await _getApiKeyOrThrow();
    final model = config?.modelId ?? request.modelId ?? AiModelRegistry.modelGemini35FlashLite;
    final customProxy = await credentialStorage.getCustomProxyUrl();
    final base = customProxy?.isNotEmpty == true ? customProxy! : _baseUrl;
    final uri = Uri.parse('$base/models/$model:generateContent');

    final bodyJson = json.encode(request.toGeminiRequestBody());
    final headers = {
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    };

    final sw = Stopwatch()..start();
    const maxRetries = 2;
    int attempt = 0;

    while (true) {
      if (cancelToken?.isCancelled ?? false) {
        throw const AiCancelledException();
      }

      try {
        final httpResponse = await _client
            .post(uri, headers: headers, body: bodyJson)
            .timeout(timeout);

        sw.stop();
        _handleStatusCode(httpResponse.statusCode, httpResponse.body, model);

        final responseMap = json.decode(httpResponse.body) as Map<String, dynamic>;
        final candidates = responseMap['candidates'] as List<dynamic>?;

        if (candidates == null || candidates.isEmpty) {
          return AiTextResponse(
            text: '',
            finishReason: 'EMPTY',
            latencyMs: sw.elapsedMilliseconds,
            modelUsed: model,
          );
        }

        final candidate = candidates.first as Map<String, dynamic>;
        final content = candidate['content'] as Map<String, dynamic>?;
        final parts = content?['parts'] as List<dynamic>? ?? [];

        final fullText = parts.map((p) => p['text'] as String? ?? '').join();
        final finishReason = candidate['finishReason'] as String?;

        AiUsageMetadata? usage;
        if (responseMap.containsKey('usageMetadata')) {
          usage = AiUsageMetadata.fromJson(responseMap['usageMetadata'] as Map<String, dynamic>);
        }

        return AiTextResponse(
          text: fullText,
          finishReason: finishReason,
          usageMetadata: usage,
          latencyMs: sw.elapsedMilliseconds,
          modelUsed: model,
        );
      } on AiException {
        rethrow;
      } on TimeoutException catch (e) {
        throw AiTimeoutException('AI request timed out after ${timeout.inSeconds}s.', duration: timeout, originalError: e);
      } catch (e) {
        attempt++;
        if (attempt > maxRetries || (cancelToken?.isCancelled ?? false)) {
          throw AiNetworkException('Network failure while communicating with Gemini API: $e', originalError: e);
        }
        // Exponential backoff: 500ms -> 1000ms
        await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
      }
    }
  }

  @override
  Stream<AiStreamChunk> streamText(
    AiPromptRequest request, {
    AiModelConfig? config,
    Duration timeout = const Duration(seconds: 45),
    CancelToken? cancelToken,
  }) async* {
    final apiKey = await _getApiKeyOrThrow();
    final model = config?.modelId ?? request.modelId ?? AiModelRegistry.modelGemini35FlashLite;
    final customProxy = await credentialStorage.getCustomProxyUrl();
    final base = customProxy?.isNotEmpty == true ? customProxy! : _baseUrl;
    final uri = Uri.parse('$base/models/$model:streamGenerateContent?alt=sse');

    final bodyJson = json.encode(request.toGeminiRequestBody());
    final httpRequest = http.Request('POST', uri);
    httpRequest.headers.addAll({
      'Content-Type': 'application/json',
      'x-goog-api-key': apiKey,
    });
    httpRequest.body = bodyJson;

    http.StreamedResponse streamedResponse;
    try {
      if (cancelToken?.isCancelled ?? false) {
        throw const AiCancelledException();
      }

      final responseFuture = _client.send(httpRequest);
      streamedResponse = await responseFuture.timeout(timeout);
    } on TimeoutException catch (e) {
      throw AiTimeoutException('Streaming connection timed out after ${timeout.inSeconds}s.', duration: timeout, originalError: e);
    } catch (e) {
      if (cancelToken?.isCancelled ?? false) {
        throw const AiCancelledException();
      }
      throw AiNetworkException('Failed to establish streaming connection: $e', originalError: e);
    }

    if (streamedResponse.statusCode != 200) {
      final errorBody = await streamedResponse.stream.bytesToString();
      _handleStatusCode(streamedResponse.statusCode, errorBody, model);
    }

    int chunkIndex = 0;
    final stream = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    StreamSubscription<String>? subscription;
    final controller = StreamController<AiStreamChunk>();

    void cancelSubscription() {
      subscription?.cancel();
      subscription = null;
      if (!controller.isClosed) {
        controller.addError(const AiCancelledException());
        controller.close();
      }
    }

    cancelToken?.onCancelled(cancelSubscription);

    subscription = stream.listen(
      (line) {
        if (cancelToken?.isCancelled ?? false) {
          cancelSubscription();
          return;
        }

        final trimmed = line.trim();
        if (trimmed.isEmpty || !trimmed.startsWith('data:')) {
          return;
        }

        final jsonString = trimmed.substring(5).trim();
        if (jsonString.isEmpty) return;

        try {
          final data = json.decode(jsonString) as Map<String, dynamic>;
          final candidates = data['candidates'] as List<dynamic>?;

          String chunkText = '';
          String? finishReason;
          if (candidates != null && candidates.isNotEmpty) {
            final cand = candidates.first as Map<String, dynamic>;
            finishReason = cand['finishReason'] as String?;
            final content = cand['content'] as Map<String, dynamic>?;
            final parts = content?['parts'] as List<dynamic>? ?? [];
            chunkText = parts.map((p) => p['text'] as String? ?? '').join();
          }

          AiUsageMetadata? usage;
          if (data.containsKey('usageMetadata')) {
            usage = AiUsageMetadata.fromJson(data['usageMetadata'] as Map<String, dynamic>);
          }

          if (chunkText.isNotEmpty || finishReason != null) {
            controller.add(AiStreamChunk(
              index: chunkIndex++,
              text: chunkText,
              finishReason: finishReason,
              usageMetadata: usage,
            ));
          }
        } catch (err) {
          debugPrint('[GeminiRestAiProvider] Failed to parse SSE line: $err');
        }
      },
      onError: (err) {
        if (!controller.isClosed) {
          controller.addError(AiNetworkException('Stream interrupted: $err', originalError: err));
          controller.close();
        }
      },
      onDone: () {
        if (!controller.isClosed) {
          controller.close();
        }
      },
      cancelOnError: true,
    );

    yield* controller.stream;
  }

  Future<String> _getApiKeyOrThrow() async {
    final apiKey = await credentialStorage.getApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw const AiAuthenticationException(
        'Gemini API key is not configured. Please enter your API key in Settings.',
        statusCode: 401,
      );
    }
    return apiKey;
  }

  void _handleStatusCode(int statusCode, String responseBody, String model) {
    if (statusCode == 200) return;

    String errorMessage = 'HTTP $statusCode';
    try {
      final jsonMap = json.decode(responseBody) as Map<String, dynamic>;
      if (jsonMap.containsKey('error')) {
        final errorObj = jsonMap['error'] as Map<String, dynamic>;
        errorMessage = errorObj['message'] as String? ?? errorMessage;
      }
    } catch (_) {
      errorMessage = responseBody.isNotEmpty ? responseBody : errorMessage;
    }

    switch (statusCode) {
      case 400:
        throw AiValidationException('Bad Request (400): $errorMessage');
      case 401:
      case 403:
        throw AiAuthenticationException('Authentication failed ($statusCode): $errorMessage', statusCode: statusCode);
      case 404:
        throw AiModelNotFoundException('Model not found or unavailable ($model): $errorMessage', modelName: model, statusCode: 404);
      case 429:
        throw AiRateLimitException('Rate limit exceeded (429): $errorMessage', statusCode: 429);
      case 500:
      case 502:
      case 503:
      case 504:
        throw AiServerException('Gemini server error ($statusCode): $errorMessage', statusCode: statusCode);
      default:
        throw AiServerException('Unexpected response ($statusCode): $errorMessage', statusCode: statusCode);
    }
  }
}
