import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/network/ai/ai.dart';
import 'package:hi_chinese/features/settings/settings.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('1. Model Registry & Explicit Capabilities Tests', () {
    late AiModelRegistry registry;

    setUp(() {
      registry = AiModelRegistry();
    });

    test('Single source of truth for Model IDs without hardcoding in features', () {
      expect(registry.availableModels, contains(AiModelRegistry.modelGemini35FlashLite));
      expect(registry.availableModels, contains(AiModelRegistry.modelGemini38Flash));
      expect(registry.availableModels, contains(AiModelRegistry.modelGemini31ProPreview));
      expect(registry.availableModels, contains(AiModelRegistry.modelGemini38Live));
    });

    test('Explicit capability verification does NOT infer from model name strings', () {
      // Gemini 3.5 Flash Lite supports Text, Audio Input, Streaming, Vision, but NOT Live API or TTS
      expect(
        registry.hasCapability(AiModelRegistry.modelGemini35FlashLite, requiresText: true),
        isTrue,
      );
      expect(
        registry.hasCapability(AiModelRegistry.modelGemini35FlashLite, requiresAudioInput: true),
        isTrue,
      );
      expect(
        registry.hasCapability(AiModelRegistry.modelGemini35FlashLite, requiresStreaming: true),
        isTrue,
      );
      expect(
        registry.hasCapability(AiModelRegistry.modelGemini35FlashLite, requiresLiveApi: true),
        isFalse,
      );
      expect(
        registry.hasCapability(AiModelRegistry.modelGemini35FlashLite, requiresTts: true),
        isFalse,
      );

      // Gemini 3.8 Live supports Live API, TTS, and Audio Input
      expect(
        registry.hasCapability(AiModelRegistry.modelGemini38Live, requiresLiveApi: true),
        isTrue,
      );
      expect(
        registry.hasCapability(AiModelRegistry.modelGemini38Live, requiresTts: true),
        isTrue,
      );

      // Gemini 3.1 Pro Preview does NOT support Audio Input
      expect(
        registry.hasCapability(AiModelRegistry.modelGemini31ProPreview, requiresAudioInput: true),
        isFalse,
      );

      // Non-existent model returns false for all capabilities
      expect(
        registry.hasCapability('non-existent-model', requiresText: true),
        isFalse,
      );
    });

    test('Dynamic default model update alters chat and general task routes', () {
      expect(
        registry.getConfigForTask(AiTaskType.chatTutor).modelId,
        AiModelRegistry.modelGemini25FlashLite,
      );

      registry.setDefaultModel(AiModelRegistry.modelGemini38Flash);

      expect(registry.activeDefaultModelId, AiModelRegistry.modelGemini38Flash);
      expect(
        registry.getConfigForTask(AiTaskType.chatTutor).modelId,
        AiModelRegistry.modelGemini38Flash,
      );
    });
  });

  group('2. Secure Credential Storage & Zero-Log Redaction Tests', () {
    late AiCredentialStorage storage;

    setUp(() {
      storage = AiCredentialStorage.inMemory();
    });

    test('Saves, retrieves, and clears API key safely', () async {
      expect(await storage.hasApiKey(), isFalse);
      expect(await storage.getApiKey(), isNull);
      expect(await storage.getMaskedApiKey(), isNull);

      await storage.saveApiKey('AIzaSyD-TEST-REAL-KEY-123456789012345');

      expect(await storage.hasApiKey(), isTrue);
      expect(await storage.getApiKey(), 'AIzaSyD-TEST-REAL-KEY-123456789012345');

      // Masked representation hides full secret
      final masked = await storage.getMaskedApiKey();
      expect(masked, 'AIza...2345');
      expect(masked, isNot(contains('REAL-KEY')));

      // Clearing removes key completely
      await storage.clearApiKey();
      expect(await storage.hasApiKey(), isFalse);
      expect(await storage.getApiKey(), isNull);
      expect(await storage.getMaskedApiKey(), isNull);
    });

    test('Zero-Log: sanitizeSecret strictly scrubs secret keys from logs and messages', () {
      const secret = 'AIzaSyA_REAL_SECRET_KEY_9876543210987';
      const rawLog = 'Failed connecting to https://generativelanguage.googleapis.com with key $secret';

      final sanitized = AiCredentialStorage.sanitizeSecret(rawLog, secret);

      expect(sanitized, isNot(contains(secret)));
      expect(sanitized, contains('[REDACTED_API_KEY]'));
    });
  });

  group('3. Live Connection Diagnostics (GeminiRestAiProvider.testConnection)', () {
    test('Empty credentials return emptyCredentials error immediately without network call', () async {
      final storage = AiCredentialStorage.inMemory();
      final provider = GeminiRestAiProvider(credentialStorage: storage);

      final result = await provider.testConnection();

      expect(result.isSuccess, isFalse);
      expect(result.errorType, ConnectionErrorType.emptyCredentials);
      expect(result.troubleshootingHint, contains('Vui lòng nhập API Key'));
      expect(result.latencyMs, 0);
    });

    test('HTTP 401/403 Invalid API Key maps to unauthorized error with hint', () async {
      final storage = AiCredentialStorage.inMemory(initialApiKey: 'AIzaSy_INVALID_KEY');
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'error': {
              'code': 400,
              'message': 'API_KEY_INVALID: Key not valid. Please pass a valid API key.',
              'status': 'INVALID_ARGUMENT',
            }
          }),
          400,
        );
      });

      final provider = GeminiRestAiProvider(
        credentialStorage: storage,
        client: mockClient,
      );

      final result = await provider.testConnection();

      expect(result.isSuccess, isFalse);
      expect(result.errorType, ConnectionErrorType.unauthorized);
      expect(result.troubleshootingHint, contains('API Key không hợp lệ'));
      expect(result.errorMessage, isNot(contains('AIzaSy_INVALID_KEY'))); // Zero secret in message
    });

    test('HTTP 429 Quota Exceeded maps to quotaExceeded with cooldown hint', () async {
      final storage = AiCredentialStorage.inMemory(initialApiKey: 'AIzaSy_VALID_KEY');
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'error': {
              'code': 429,
              'message': 'Resource has been exhausted (e.g. check quota).',
              'status': 'RESOURCE_EXHAUSTED',
            }
          }),
          429,
        );
      });

      final provider = GeminiRestAiProvider(
        credentialStorage: storage,
        client: mockClient,
      );

      final result = await provider.testConnection();

      expect(result.isSuccess, isFalse);
      expect(result.errorType, ConnectionErrorType.quotaExceeded);
      expect(result.troubleshootingHint, contains('Rate Limit 429'));
    });

    test('HTTP 404 Model Not Found maps to modelUnavailable with model switch hint', () async {
      final storage = AiCredentialStorage.inMemory(initialApiKey: 'AIzaSy_VALID_KEY');
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'error': {
              'code': 404,
              'message': 'models/gemini-deprecated is not found for API version v1beta',
              'status': 'NOT_FOUND',
            }
          }),
          404,
        );
      });

      final provider = GeminiRestAiProvider(
        credentialStorage: storage,
        client: mockClient,
      );

      final result = await provider.testConnection(modelId: 'gemini-deprecated');

      expect(result.isSuccess, isFalse);
      expect(result.errorType, ConnectionErrorType.modelUnavailable);
      expect(result.troubleshootingHint, contains('không tồn tại hoặc đã bị ngừng hỗ trợ'));
      expect(result.modelTested, 'gemini-deprecated');
    });

    test('HTTP 403 App Check failure maps to appCheckFailed', () async {
      final storage = AiCredentialStorage.inMemory(initialApiKey: 'AIzaSy_VALID_KEY');
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'error': {
              'code': 403,
              'message': 'App Check token is invalid or expired',
              'status': 'PERMISSION_DENIED',
            }
          }),
          403,
        );
      });

      final provider = GeminiRestAiProvider(
        credentialStorage: storage,
        client: mockClient,
      );

      final result = await provider.testConnection();

      expect(result.isSuccess, isFalse);
      expect(result.errorType, ConnectionErrorType.appCheckFailed);
      expect(result.troubleshootingHint, contains('Play Integrity'));
    });

    test('Timeout maps to timeout error', () async {
      final storage = AiCredentialStorage.inMemory(initialApiKey: 'AIzaSy_VALID_KEY');
      final mockClient = MockClient((request) async {
        throw TimeoutException('Request timed out after 15s');
      });

      final provider = GeminiRestAiProvider(
        credentialStorage: storage,
        client: mockClient,
      );

      final result = await provider.testConnection();

      expect(result.isSuccess, isFalse);
      expect(result.errorType, ConnectionErrorType.timeout);
      expect(result.troubleshootingHint, contains('timeout'));
    });

    test('Network SocketException maps to networkError', () async {
      final storage = AiCredentialStorage.inMemory(initialApiKey: 'AIzaSy_VALID_KEY');
      final mockClient = MockClient((request) async {
        throw const SocketException('Failed host lookup: generativelanguage.googleapis.com');
      });

      final provider = GeminiRestAiProvider(
        credentialStorage: storage,
        client: mockClient,
      );

      final result = await provider.testConnection();

      expect(result.isSuccess, isFalse);
      expect(result.errorType, ConnectionErrorType.networkError);
      expect(result.troubleshootingHint, contains('Không có kết nối mạng'));
    });

    test('Successful 200 response with candidates returns isSuccess: true with latency', () async {
      final storage = AiCredentialStorage.inMemory(initialApiKey: 'AIzaSy_VALID_KEY');
      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Hello!'}
                  ],
                  'role': 'model',
                },
                'finishReason': 'STOP',
              }
            ],
            'usageMetadata': {
              'promptTokenCount': 1,
              'candidatesTokenCount': 2,
              'totalTokenCount': 3,
            }
          }),
          200,
        );
      });

      final provider = GeminiRestAiProvider(
        credentialStorage: storage,
        client: mockClient,
      );

      final result = await provider.testConnection(
        modelId: AiModelRegistry.modelGemini35FlashLite,
      );

      expect(result.isSuccess, isTrue);
      expect(result.errorType, isNull);
      expect(result.errorMessage, isNull);
      expect(result.modelTested, AiModelRegistry.modelGemini35FlashLite);
      expect(result.providerName, 'Google Gemini REST');
      expect(result.troubleshootingHint, contains('sẵn sàng phục vụ'));
    });
  });

  group('4. AiSettingsScreen Widget Tests', () {
    testWidgets('Renders all 4 sections, masked key, capability badges, and connection test',
        (tester) async {
      final fakeStorage = AiCredentialStorage.inMemory(
        initialApiKey: 'AIzaSyD_TEST_EXISTING_KEY_1234',
        initialProviderType: AiProviderType.geminiRest,
        initialSelectedModel: AiModelRegistry.modelGemini35FlashLite,
      );

      final fakeProvider = MockAiProvider();
      final fakeRegistry = AiModelRegistry();
      final fakeService = AiService(
        provider: fakeProvider,
        modelRegistry: fakeRegistry,
        credentialStorage: fakeStorage,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiCredentialStorageProvider.overrideWithValue(fakeStorage),
            aiServiceProvider.overrideWithValue(fakeService),
            aiModelRegistryProvider.overrideWithValue(fakeRegistry),
          ],
          child: const MaterialApp(
            home: AiSettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Section 1: Provider
      expect(find.text('1. Nhà Cung Cấp AI (Provider)'), findsOneWidget);
      expect(find.text('Google AI Studio (BYOK)'), findsOneWidget);
      expect(find.text('Firebase AI Logic'), findsOneWidget);

      // Section 2: Credentials & Key Management
      expect(find.text('2. Thông Tin Xác Thực & Bảo Mật'), findsOneWidget);
      expect(find.text('Khóa API đã lưu an toàn'), findsOneWidget);
      expect(find.text('Giá trị: AIza...1234'), findsOneWidget);
      expect(find.text('AIzaSyD_TEST_EXISTING_KEY_1234'), findsNothing); // Never shows raw full key!

      // Section 3: Model Config & Capabilities
      expect(find.text('3. Cấu Hình Mô Hình & Khả Năng'), findsOneWidget);
      expect(find.text('Gemini 3.5 Flash Lite'), findsOneWidget);
      expect(find.text('💬 Văn bản (Text)'), findsOneWidget);
      expect(find.text('⚡ Streaming'), findsOneWidget);
      expect(find.text('🎙️ Âm thanh vào'), findsOneWidget);

      // Section 4: Live Connection Test
      final testBtn = find.text('Kiểm Tra Kết Nối Thực Tế');
      await tester.ensureVisible(testBtn);
      await tester.pumpAndSettle();

      expect(find.text('4. Kiểm Tra Kết Nối Thực Tế'), findsOneWidget);
      expect(testBtn, findsOneWidget);

      // Tap Connection Test button
      await tester.tap(testBtn);
      await tester.pumpAndSettle();

      // Check results card
      final resultCard = find.text('Kết Nối Thành Công');
      await tester.ensureVisible(resultCard);
      await tester.pumpAndSettle();

      expect(resultCard, findsOneWidget);
      expect(find.textContaining('Mock AI Provider'), findsOneWidget);
    });

    testWidgets('Can enter, toggle visibility, and save new API key', (tester) async {
      final fakeStorage = AiCredentialStorage.inMemory();
      final fakeProvider = MockAiProvider();
      final fakeRegistry = AiModelRegistry();
      final fakeService = AiService(
        provider: fakeProvider,
        modelRegistry: fakeRegistry,
        credentialStorage: fakeStorage,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiCredentialStorageProvider.overrideWithValue(fakeStorage),
            aiServiceProvider.overrideWithValue(fakeService),
            aiModelRegistryProvider.overrideWithValue(fakeRegistry),
          ],
          child: const MaterialApp(
            home: AiSettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Chưa cấu hình API Key. Hãy nhập key bên dưới để kích hoạt AI Tutor.'), findsOneWidget);

      // Enter new API Key
      await tester.enterText(find.byType(TextField).first, 'AIzaSyA_NEW_ENTERED_KEY_9999');
      await tester.pumpAndSettle();

      // Tap Save Key
      await tester.tap(find.text('Lưu Khóa API'));
      await tester.pumpAndSettle();

      // Check that key is now saved in storage and displayed masked
      expect(await fakeStorage.hasApiKey(), isTrue);
      expect(find.text('Khóa API đã lưu an toàn'), findsOneWidget);
      expect(find.text('Giá trị: AIza...9999'), findsOneWidget);
    });

    testWidgets('Simulated connection failure displays error classification and troubleshooting hint',
        (tester) async {
      final fakeStorage = AiCredentialStorage.inMemory(
        initialApiKey: 'AIzaSy_KEY',
      );
      final fakeProvider = MockAiProvider()..simulateUnauthorized = true;
      final fakeRegistry = AiModelRegistry();
      final fakeService = AiService(
        provider: fakeProvider,
        modelRegistry: fakeRegistry,
        credentialStorage: fakeStorage,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiCredentialStorageProvider.overrideWithValue(fakeStorage),
            aiServiceProvider.overrideWithValue(fakeService),
            aiModelRegistryProvider.overrideWithValue(fakeRegistry),
          ],
          child: const MaterialApp(
            home: AiSettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll to button before tapping
      final testBtn = find.text('Kiểm Tra Kết Nối Thực Tế');
      await tester.ensureVisible(testBtn);
      await tester.pumpAndSettle();

      // Run test
      await tester.tap(testBtn);
      await tester.pumpAndSettle();

      // Scroll to failure card
      final failHeader = find.text('Kiểm Tra Thất Bại');
      await tester.ensureVisible(failHeader);
      await tester.pumpAndSettle();

      // Check failure presentation
      expect(failHeader, findsOneWidget);
      expect(find.textContaining('API Key không hợp lệ'), findsOneWidget);
    });
  });
}
