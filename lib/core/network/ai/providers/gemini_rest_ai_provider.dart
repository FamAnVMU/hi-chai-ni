import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../interfaces/ai_provider.dart';
import '../models/ai_errors.dart';
import '../models/ai_model_config.dart';
import '../models/ai_request.dart';
import '../models/ai_response.dart';
import '../models/cancel_token.dart';
import '../models/connection_test_result.dart';
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
  void dispose() {
    _client.close();
  }

  @override
  Future<bool> verifyCredentials() async {
    final providerType = await credentialStorage.getProviderType();
    final apiKey = await credentialStorage.getApiKey(provider: providerType);
    if (apiKey == null || apiKey.isEmpty) return false;

    try {
      final base = await _resolveSecureBaseUrl();
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
  Future<ConnectionTestResult> testConnection({String? modelId}) async {
    final effectiveModel = modelId ?? AiModelRegistry.modelGemini35FlashLite;
    final stopwatch = Stopwatch()..start();

    final providerType = await credentialStorage.getProviderType();
    final providerLabel = providerType == AiProviderType.customProxy
        ? 'Custom Backend Proxy'
        : 'Google Gemini REST';
    final apiKey = await credentialStorage.getApiKey(provider: providerType);
    if (apiKey == null || apiKey.trim().isEmpty) {
      return ConnectionTestResult.failure(
        providerName: providerLabel,
        modelTested: effectiveModel,
        latencyMs: 0,
        errorType: ConnectionErrorType.emptyCredentials,
        errorMessage: 'Chưa cấu hình API Key.',
      );
    }

    final base = await _resolveSecureBaseUrl();

    try {
      final uri = Uri.parse('$base/models/$effectiveModel:generateContent');

      final requestBody = json.encode({
        'contents': [
          {
            'role': 'user',
            'parts': [
              {'text': 'Hi'}
            ],
          }
        ],
        'generationConfig': {
          'maxOutputTokens': 5,
        },
      });

      final response = await _client.post(
        uri,
        headers: {
          'x-goog-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: requestBody,
      ).timeout(const Duration(seconds: 15));

      stopwatch.stop();
      final latencyMs = stopwatch.elapsedMilliseconds;

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final candidates = data['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            return ConnectionTestResult.success(
              providerName: providerLabel,
              modelTested: effectiveModel,
              latencyMs: latencyMs,
            );
          } else {
            return ConnectionTestResult.failure(
              providerName: providerLabel,
              modelTested: effectiveModel,
              latencyMs: latencyMs,
              errorType: ConnectionErrorType.malformedResponse,
              errorMessage: 'Phản hồi từ máy chủ không chứa candidate hợp lệ.',
            );
          }
        } catch (_) {
          return ConnectionTestResult.failure(
            providerName: providerLabel,
            modelTested: effectiveModel,
            latencyMs: latencyMs,
            errorType: ConnectionErrorType.malformedResponse,
            errorMessage: 'Không thể giải mã dữ liệu JSON từ phản hồi máy chủ.',
          );
        }
      }

      final sanitizedBody = AiCredentialStorage.sanitizeSecret(response.body, apiKey);
      final errorType = _classifyConnectionStatusCode(response.statusCode, sanitizedBody);

      return ConnectionTestResult.failure(
        providerName: providerLabel,
        modelTested: effectiveModel,
        latencyMs: latencyMs,
        errorType: errorType,
        errorMessage: 'HTTP ${response.statusCode}: ${_extractErrorMessage(sanitizedBody)}',
      );
    } on TimeoutException {
      stopwatch.stop();
      return ConnectionTestResult.failure(
        providerName: providerLabel,
        modelTested: effectiveModel,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorType: ConnectionErrorType.timeout,
        errorMessage: 'Yêu cầu kết nối quá thời gian chờ (15s).',
      );
    } on SocketException catch (e) {
      stopwatch.stop();
      return ConnectionTestResult.failure(
        providerName: providerLabel,
        modelTested: effectiveModel,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorType: ConnectionErrorType.networkError,
        errorMessage: 'Lỗi mạng hoặc không thể phân giải DNS: ${AiCredentialStorage.sanitizeSecret(e.message, apiKey)}',
      );
    } catch (e) {
      stopwatch.stop();
      final sanitizedError = AiCredentialStorage.sanitizeSecret(e.toString(), apiKey);
      final isNetwork = sanitizedError.toLowerCase().contains('clientexception') ||
          sanitizedError.toLowerCase().contains('failed host lookup') ||
          sanitizedError.toLowerCase().contains('connection refused') ||
          sanitizedError.toLowerCase().contains('network is unreachable');

      return ConnectionTestResult.failure(
        providerName: providerLabel,
        modelTested: effectiveModel,
        latencyMs: stopwatch.elapsedMilliseconds,
        errorType: isNetwork ? ConnectionErrorType.networkError : ConnectionErrorType.unknown,
        errorMessage: sanitizedError,
      );
    }
  }

  ConnectionErrorType _classifyConnectionStatusCode(int code, String body) {
    if (code == 401) return ConnectionErrorType.unauthorized;
    if (code == 403) {
      if (body.toLowerCase().contains('app check') || body.toLowerCase().contains('appcheck')) {
        return ConnectionErrorType.appCheckFailed;
      }
      return ConnectionErrorType.unauthorized;
    }
    if (code == 400 && body.contains('API_KEY_INVALID')) {
      return ConnectionErrorType.unauthorized;
    }
    if (code == 429) return ConnectionErrorType.quotaExceeded;
    if (code == 404) return ConnectionErrorType.modelUnavailable;
    return ConnectionErrorType.unknown;
  }

  String _extractErrorMessage(String body) {
    try {
      final jsonMap = json.decode(body) as Map<String, dynamic>;
      if (jsonMap.containsKey('error')) {
        final errorObj = jsonMap['error'] as Map<String, dynamic>;
        return errorObj['message'] as String? ?? body;
      }
    } catch (_) {}
    return body;
  }

  @override
  Future<AiTextResponse> generateText(
    AiPromptRequest request, {
    AiModelConfig? config,
    Duration timeout = const Duration(seconds: 30),
    CancelToken? cancelToken,
  }) async {
    final apiKey = await _getApiKeyOrThrow();
    final model = request.modelId ?? config?.modelId ?? AiModelRegistry.modelGemini35FlashLite;
    final base = await _resolveSecureBaseUrl();
    final uri = Uri.parse('$base/models/$model:generateContent');

    final effectiveRequest = AiPromptRequest(
      contents: request.contents,
      systemInstruction: request.systemInstruction,
      temperature: request.temperature ?? config?.temperature,
      topP: request.topP ?? config?.topP,
      maxOutputTokens: request.maxOutputTokens ?? config?.maxOutputTokens,
      modelId: model,
    );
    final bodyJson = json.encode(effectiveRequest.toGeminiRequestBody());
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
        _handleStatusCode(
          httpResponse.statusCode,
          httpResponse.body,
          model,
          apiKey: apiKey,
        );

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
      } on FormatException catch (e) {
        final safeErr = AiCredentialStorage.sanitizeSecret(e.toString(), apiKey);
        throw AiValidationException('Malformed JSON response from AI server: $safeErr');
      } on AiServerException catch (e) {
        final isRetryable5xx = e.statusCode == 500 ||
            e.statusCode == 502 ||
            e.statusCode == 503 ||
            e.statusCode == 504;
        if (!isRetryable5xx) rethrow;
        attempt++;
        if (attempt > maxRetries || (cancelToken?.isCancelled ?? false)) {
          rethrow;
        }
        await Future<void>.delayed(Duration(milliseconds: 500 * attempt));
      } on AiException {
        rethrow;
      } on TimeoutException catch (e) {
        throw AiTimeoutException('AI request timed out after ${timeout.inSeconds}s.', duration: timeout, originalError: e);
      } catch (e) {
        attempt++;
        final safeErr = AiCredentialStorage.sanitizeSecret(e.toString(), apiKey);
        if (attempt > maxRetries || (cancelToken?.isCancelled ?? false)) {
          throw AiNetworkException('Network failure while communicating with Gemini API: $safeErr', originalError: safeErr);
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
    final model = request.modelId ?? config?.modelId ?? AiModelRegistry.modelGemini35FlashLite;
    final base = await _resolveSecureBaseUrl();
    final uri = Uri.parse('$base/models/$model:streamGenerateContent?alt=sse');

    final effectiveRequest = AiPromptRequest(
      contents: request.contents,
      systemInstruction: request.systemInstruction,
      temperature: request.temperature ?? config?.temperature,
      topP: request.topP ?? config?.topP,
      maxOutputTokens: request.maxOutputTokens ?? config?.maxOutputTokens,
      modelId: model,
    );
    final bodyJson = json.encode(effectiveRequest.toGeminiRequestBody());
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
      final safeErr = AiCredentialStorage.sanitizeSecret(e.toString(), apiKey);
      throw AiNetworkException('Failed to establish streaming connection: $safeErr', originalError: safeErr);
    }

    if (streamedResponse.statusCode != 200) {
      final errorBody = await streamedResponse.stream
          .bytesToString()
          .timeout(timeout);
      _handleStatusCode(
        streamedResponse.statusCode,
        errorBody,
        model,
        apiKey: apiKey,
      );
    }

    int chunkIndex = 0;
    final idleTimeout = timeout < const Duration(seconds: 30)
        ? timeout
        : const Duration(seconds: 30);
    final stream = streamedResponse.stream
        .timeout(idleTimeout)
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    StreamSubscription<String>? subscription;
    late final StreamController<AiStreamChunk> controller;
    controller = StreamController<AiStreamChunk>(
      onCancel: () async {
        await subscription?.cancel();
        subscription = null;
      },
    );

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
          if (err is TimeoutException) {
            controller.addError(
              AiTimeoutException(
                'Streaming idle timeout after ${idleTimeout.inSeconds}s.',
                duration: idleTimeout,
                originalError: err,
              ),
            );
          } else {
            final safeErr = AiCredentialStorage.sanitizeSecret(err.toString(), apiKey);
            controller.addError(
              AiNetworkException('Stream interrupted: $safeErr', originalError: safeErr),
            );
          }
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

  void _validateEndpointSecurity(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.scheme.toLowerCase() != 'https') {
      throw const SecurityException('Endpoint URL không an toàn: Bắt buộc sử dụng giao thức HTTPS.');
    }
    if (AiCredentialStorage.isUnsafeHost(uri.host)) {
      throw const SecurityException('Endpoint URL không an toàn: Không được trỏ về địa chỉ loopback hoặc IP nội bộ.');
    }
  }

  Future<String> _resolveSecureBaseUrl() async {
    final customProxy = await credentialStorage.getCustomProxyUrl();
    if (customProxy != null && customProxy.trim().isNotEmpty) {
      _validateEndpointSecurity(customProxy.trim());
    }
    final providerType = await credentialStorage.getProviderType();
    if (providerType == AiProviderType.customProxy) {
      if (customProxy == null || customProxy.trim().isEmpty) {
        throw const SecurityException('Custom Proxy URL chưa được cấu hình.');
      }
      return customProxy.trim().replaceAll(RegExp(r'/+$'), '');
    }
    _validateEndpointSecurity(_baseUrl);
    return _baseUrl;
  }

  Future<String> _getApiKeyOrThrow() async {
    final providerType = await credentialStorage.getProviderType();
    final apiKey = await credentialStorage.getApiKey(provider: providerType);
    if (apiKey == null || apiKey.isEmpty) {
      throw const AiAuthenticationException(
        'API key is not configured. Please enter your API key in Settings.',
        statusCode: 401,
      );
    }
    return apiKey;
  }

  void _handleStatusCode(
    int statusCode,
    String responseBody,
    String model, {
    String? apiKey,
  }) {
    if (statusCode == 200) return;

    final safeBody = AiCredentialStorage.sanitizeSecret(responseBody, apiKey);
    String errorMessage = 'HTTP $statusCode';
    try {
      final jsonMap = json.decode(safeBody) as Map<String, dynamic>;
      if (jsonMap.containsKey('error')) {
        final errorObj = jsonMap['error'] as Map<String, dynamic>;
        errorMessage = AiCredentialStorage.sanitizeSecret(
          errorObj['message'] as String? ?? errorMessage,
          apiKey,
        );
      }
    } catch (_) {
      errorMessage = safeBody.isNotEmpty ? safeBody : errorMessage;
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
