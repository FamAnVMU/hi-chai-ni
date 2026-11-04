import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/network/ai/ai.dart';

void main() {
  group('AiModelRegistry Routing Tests', () {
    test('1. Default model routes match verified Google Gemini models', () {
      final registry = AiModelRegistry();

      final chatConfig = registry.getConfigForTask(AiTaskType.chatTutor);
      expect(chatConfig.modelId, equals(AiModelRegistry.modelGemini25FlashLite));
      expect(chatConfig.supportsStreaming, isTrue);

      final grammarConfig = registry.getConfigForTask(AiTaskType.grammarCorrection);
      expect(grammarConfig.modelId, equals(AiModelRegistry.modelGemini25Flash));

      final dictConfig = registry.getConfigForTask(AiTaskType.dictionaryExplanation);
      expect(dictConfig.modelId, equals(AiModelRegistry.modelGemini25FlashLite));
      expect(dictConfig.temperature, equals(0.2)); // Deterministic
    });

    test('2. Dynamic route updates at runtime work properly', () {
      final registry = AiModelRegistry();

      registry.updateRoute(
        AiTaskType.chatTutor,
        const AiModelConfig(modelId: 'custom-experimental-model', temperature: 0.9),
      );

      final updated = registry.getConfigForTask(AiTaskType.chatTutor);
      expect(updated.modelId, equals('custom-experimental-model'));
      expect(updated.temperature, equals(0.9));
    });
  });

  group('AiCredentialStorage Security & Masking Tests', () {
    test('1. Key masking redacts sensitive tokens for zero-leak logging', () {
      expect(AiCredentialStorage.maskKey('AIzaSyD84H9dK2047qWpLk'), equals('AIza...WpLk'));
      expect(AiCredentialStorage.maskKey('short'), equals('********'));
      expect(AiCredentialStorage.maskKey(''), equals('<EMPTY>'));
      expect(AiCredentialStorage.maskKey(null), equals('<EMPTY>'));
    });
  });

  group('MockAiProvider Unit Tests (Offline / Zero Cost)', () {
    late MockAiProvider mockProvider;
    late AiCredentialStorage mockStorage;
    late AiService aiService;

    setUp(() {
      mockProvider = MockAiProvider();
      mockStorage = AiCredentialStorage.inMemory(initialApiKey: 'AIzaSyMockKeyForTesting12345');
      aiService = AiService(
        provider: mockProvider,
        credentialStorage: mockStorage,
      );
    });

    test('1. Success single-turn text generation', () async {
      final request = AiPromptRequest.singlePrompt('Xin chào!');
      final response = await aiService.generateText(request, taskType: AiTaskType.chatTutor);

      expect(response.text.isNotEmpty, isTrue);
      expect(response.text, contains('你好'));
      expect(response.finishReason, equals('STOP'));
      expect(response.usageMetadata, isNotNull);
      expect(response.usageMetadata!.totalTokenCount, greaterThan(0));
      expect(response.modelUsed, equals(AiModelRegistry.modelGemini25FlashLite));
    });

    test('2. Streaming receives sequential chunks incrementally', () async {
      final request = AiPromptRequest.singlePrompt('Dạy tôi tiếng Trung');
      final chunks = <AiStreamChunk>[];

      await for (final chunk in aiService.streamText(request)) {
        chunks.add(chunk);
      }

      expect(chunks.length, greaterThanOrEqualTo(3));
      // Verify strict sequential ordering
      for (int i = 0; i < chunks.length; i++) {
        expect(chunks[i].index, equals(i));
      }

      final fullText = chunks.map((c) => c.text).join();
      expect(fullText, contains('你好'));
      expect(chunks.last.isDone, isTrue);
      expect(chunks.last.usageMetadata, isNotNull);
    });

    test('3. Empty result handling', () async {
      mockProvider.simulateEmptyResponse = true;

      final request = AiPromptRequest.singlePrompt('Prompt leading to empty content');
      final response = await aiService.generateText(request);

      expect(response.text, isEmpty);

      // Streaming empty result yields a single finish chunk with empty text
      final streamChunks = await aiService.streamText(request).toList();
      expect(streamChunks.length, equals(1));
      expect(streamChunks.first.text, isEmpty);
      expect(streamChunks.first.isDone, isTrue);
    });

    test('4. Timeout handling throws AiTimeoutException', () async {
      mockProvider.simulateTimeout = true;

      final request = AiPromptRequest.singlePrompt('Timeout test');
      expect(
        () => aiService.generateText(
          request,
          timeout: const Duration(milliseconds: 50),
        ),
        throwsA(isA<AiTimeoutException>()),
      );
    });

    test('5. Rate limit (HTTP 429) throws AiRateLimitException', () async {
      mockProvider.simulateRateLimit = true;

      final request = AiPromptRequest.singlePrompt('Rate limit test');
      expect(
        () => aiService.generateText(request),
        throwsA(isA<AiRateLimitException>()),
      );

      expect(
        () => aiService.streamText(request).toList(),
        throwsA(isA<AiRateLimitException>()),
      );
    });

    test('6. Unauthorized (HTTP 401) throws AiAuthenticationException', () async {
      mockProvider.simulateUnauthorized = true;

      final request = AiPromptRequest.singlePrompt('Auth test');
      expect(
        () => aiService.generateText(request),
        throwsA(isA<AiAuthenticationException>()),
      );

      final isValid = await aiService.verifyCredentials();
      expect(isValid, isFalse);
    });

    test('7. Network error / connection drop throws AiNetworkException', () async {
      mockProvider.simulateNetworkError = true;

      final request = AiPromptRequest.singlePrompt('Network error test');
      expect(
        () => aiService.generateText(request),
        throwsA(isA<AiNetworkException>()),
      );

      expect(
        () => aiService.streamText(request).toList(),
        throwsA(isA<AiNetworkException>()),
      );
    });

    test('8. Cancellation mid-stream aborts execution with AiCancelledException', () async {
      final request = AiPromptRequest.singlePrompt('Long response stream to be cancelled');
      final cancelToken = CancelToken();

      mockProvider.streamChunkDelay = const Duration(milliseconds: 30);

      final stream = aiService.streamText(request, cancelToken: cancelToken);
      final chunks = <AiStreamChunk>[];

      bool threwCancelled = false;

      try {
        await for (final chunk in stream) {
          chunks.add(chunk);
          if (chunks.length == 2) {
            cancelToken.cancel('User clicked Stop Generating button');
          }
        }
      } on AiCancelledException {
        threwCancelled = true;
      }

      expect(threwCancelled, isTrue);
      expect(chunks.length, equals(2));
      expect(cancelToken.isCancelled, isTrue);
      expect(cancelToken.reason, contains('Stop Generating'));
    });
  });

  group('Real API Integration Tests (Conditional - Marked as [REAL])', () {
    final realApiKey = Platform.environment['RUN_REAL_GEMINI_TEST_API_KEY'] ??
        (Platform.environment['GEMINI_API_KEY']?.startsWith('AIzaSy') == true
            ? Platform.environment['GEMINI_API_KEY']
            : null);

    test('[REAL] Live Gemini REST API connection check', () async {
      if (realApiKey == null || realApiKey.trim().isEmpty) {
        // Explicitly document skip when running in automated offline/mock environment
        debugPrint('[REAL TEST: SKIPPED] Dedicated Gemini AI Studio key (AIzaSy...) not present. Live test safely skipped.');
        return;
      }

      final storage = AiCredentialStorage.inMemory(initialApiKey: realApiKey);

      final realProvider = GeminiRestAiProvider(credentialStorage: storage);
      final isHealthy = await realProvider.verifyCredentials();
      expect(isHealthy, isTrue, reason: 'Live credentials verification against Gemini API must return true');

      final prompt = AiPromptRequest.singlePrompt('Nói "Chào bạn" bằng tiếng Trung giản thể, pinyin và nghĩa tiếng Việt ngắn gọn.');
      final response = await realProvider.generateText(
        prompt,
        config: const AiModelConfig(modelId: AiModelRegistry.modelGemini35FlashLite),
      );

      expect(response.text.isNotEmpty, isTrue);
      expect(response.text, contains('你好'));
    });
  });
}
