import 'dart:async';
import '../interfaces/ai_provider.dart';
import '../models/ai_errors.dart';
import '../models/ai_model_config.dart';
import '../models/ai_request.dart';
import '../models/ai_response.dart';
import '../models/cancel_token.dart';

/// Full-featured mock AI provider for testing, CI/CD, and offline demonstration.
class MockAiProvider implements AiProvider {
  @override
  String get providerName => 'mock_ai_provider';

  bool simulateTimeout = false;
  bool simulateRateLimit = false;
  bool simulateUnauthorized = false;
  bool simulateNetworkError = false;
  bool simulateEmptyResponse = false;
  Duration simulatedLatency = const Duration(milliseconds: 30);
  Duration streamChunkDelay = const Duration(milliseconds: 20);

  String defaultMockReply =
      '你好！我是你的中文AI助教。很高兴与你一起学习中文！(Xin chào! Tôi là trợ lý AI tiếng Trung của bạn.)';

  String? customTextResponse;
  List<String>? customStreamChunks;

  @override
  Future<bool> verifyCredentials() async {
    if (simulateUnauthorized) return false;
    return true;
  }

  @override
  Future<AiTextResponse> generateText(
    AiPromptRequest request, {
    AiModelConfig? config,
    Duration timeout = const Duration(seconds: 30),
    CancelToken? cancelToken,
  }) async {
    if (cancelToken?.isCancelled ?? false) {
      throw const AiCancelledException();
    }

    if (simulateUnauthorized) {
      throw const AiAuthenticationException('API key is invalid or missing.', statusCode: 401);
    }
    if (simulateRateLimit) {
      throw const AiRateLimitException('Resource has been exhausted (rate limit exceeded).', statusCode: 429);
    }
    if (simulateNetworkError) {
      throw const AiNetworkException('Failed to connect to host: SocketException');
    }
    if (simulateTimeout) {
      await Future<void>.delayed(timeout + const Duration(milliseconds: 50));
      throw AiTimeoutException('AI request timed out.', duration: timeout);
    }

    if (simulatedLatency > Duration.zero) {
      await Future<void>.delayed(simulatedLatency);
    }

    if (cancelToken?.isCancelled ?? false) {
      throw const AiCancelledException();
    }

    final text = simulateEmptyResponse
        ? ''
        : (customTextResponse ?? defaultMockReply);

    return AiTextResponse(
      text: text,
      finishReason: 'STOP',
      usageMetadata: AiUsageMetadata(
        promptTokenCount: 15,
        candidatesTokenCount: text.length ~/ 2,
        totalTokenCount: 15 + (text.length ~/ 2),
      ),
      latencyMs: simulatedLatency.inMilliseconds,
      modelUsed: config?.modelId ?? 'mock-gemini-3.5',
    );
  }

  @override
  Stream<AiStreamChunk> streamText(
    AiPromptRequest request, {
    AiModelConfig? config,
    Duration timeout = const Duration(seconds: 45),
    CancelToken? cancelToken,
  }) async* {
    if (cancelToken?.isCancelled ?? false) {
      throw const AiCancelledException();
    }

    if (simulateUnauthorized) {
      throw const AiAuthenticationException('API key is invalid or missing.', statusCode: 401);
    }
    if (simulateRateLimit) {
      throw const AiRateLimitException('Rate limit exceeded (HTTP 429).', statusCode: 429);
    }
    if (simulateNetworkError) {
      throw const AiNetworkException('Connection drop during streaming');
    }
    if (simulateTimeout) {
      await Future<void>.delayed(timeout + const Duration(milliseconds: 50));
      throw AiTimeoutException('Streaming timed out.', duration: timeout);
    }

    if (customStreamChunks != null) {
      for (int i = 0; i < customStreamChunks!.length; i++) {
        if (cancelToken?.isCancelled ?? false) {
          throw const AiCancelledException();
        }
        if (streamChunkDelay > Duration.zero) {
          await Future<void>.delayed(streamChunkDelay);
        }
        yield AiStreamChunk(
          index: i,
          text: customStreamChunks![i],
          finishReason: (i == customStreamChunks!.length - 1) ? 'STOP' : null,
        );
      }
      return;
    }

    final sourceText = simulateEmptyResponse ? '' : defaultMockReply;
    if (sourceText.isEmpty) {
      yield const AiStreamChunk(
        index: 0,
        text: '',
        finishReason: 'STOP',
        usageMetadata: AiUsageMetadata(promptTokenCount: 10, candidatesTokenCount: 0, totalTokenCount: 10),
      );
      return;
    }

    // Split text into 5-word / character chunks to simulate realistic incremental token streaming
    final words = sourceText.split(' ');
    int chunkIndex = 0;

    for (int i = 0; i < words.length; i++) {
      if (cancelToken?.isCancelled ?? false) {
        throw const AiCancelledException();
      }

      if (streamChunkDelay > Duration.zero) {
        await Future<void>.delayed(streamChunkDelay);
      }

      if (cancelToken?.isCancelled ?? false) {
        throw const AiCancelledException();
      }

      final piece = (i == words.length - 1) ? words[i] : '${words[i]} ';
      final isLast = i == words.length - 1;

      yield AiStreamChunk(
        index: chunkIndex++,
        text: piece,
        finishReason: isLast ? 'STOP' : null,
        usageMetadata: isLast
            ? AiUsageMetadata(
                promptTokenCount: 12,
                candidatesTokenCount: words.length,
                totalTokenCount: 12 + words.length,
              )
            : null,
      );
    }
  }
}
