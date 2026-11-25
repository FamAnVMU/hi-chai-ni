import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hi_chinese/core/network/ai/models/ai_errors.dart';
import 'package:hi_chinese/core/network/ai/models/ai_model_config.dart';
import 'package:hi_chinese/core/network/ai/models/ai_request.dart';
import 'package:hi_chinese/core/network/ai/providers/gemini_rest_ai_provider.dart';
import 'package:hi_chinese/core/network/ai/security/ai_credential_storage.dart';

void main() {
  group('SSRF Host Validation & Custom Proxy Security', () {
    test('blocks loopback, RFC1918, CGNAT, link-local, and IPv6 private/mapped addresses', () {
      const blockedHosts = [
        '',
        'localhost',
        'sub.LOCAL',
        'api.internal',
        '127.0.0.1',
        '127.10.20.30',
        '0.0.0.0',
        '10.0.0.1',
        '172.16.0.1',
        '172.31.255.254',
        '192.168.1.10',
        '169.254.169.254',
        '100.64.0.1',
        '100.127.255.254',
        '::',
        '::1',
        '[::1]',
        '::ffff:127.0.0.1',
        '::ffff:10.0.0.5',
        'fc00::1',
        'fd12:3456::1',
        'fe80::1',
      ];

      for (final host in blockedHosts) {
        expect(
          AiCredentialStorage.isUnsafeHost(host),
          isTrue,
          reason: 'Expected host "$host" to be blocked as unsafe',
        );
      }
    });

    test('allows legitimate public domains like fcloud.vn and fd-* without false positives', () {
      const allowedHosts = [
        'fcloud.vn',
        'fd-proxy.example.com',
        'api.openai.com',
        '8.8.8.8',
        '172.15.0.1',
        '172.32.0.1',
        '100.63.255.255',
      ];

      for (final host in allowedHosts) {
        expect(
          AiCredentialStorage.isUnsafeHost(host),
          isFalse,
          reason: 'Expected public host "$host" to be allowed',
        );
      }
    });

    test('isolates BYOK Gemini key from Custom Proxy key in storage', () async {
      final storage = AiCredentialStorage.inMemory(
        initialApiKey: 'AIzaSyByokKey_1234567890',
        initialProxyApiKey: 'proxy-secret-token-xyz',
        initialProxyUrl: 'https://fd-proxy.example.com/v1beta',
        initialProviderType: AiProviderType.geminiRest,
      );

      expect(
        await storage.getApiKey(provider: AiProviderType.geminiRest),
        equals('AIzaSyByokKey_1234567890'),
      );
      expect(
        await storage.getApiKey(provider: AiProviderType.customProxy),
        equals('proxy-secret-token-xyz'),
      );

      await storage.saveApiKey('new-proxy-key-1234567890', provider: AiProviderType.customProxy);
      expect(
        await storage.getApiKey(provider: AiProviderType.geminiRest),
        equals('AIzaSyByokKey_1234567890'),
      );
      expect(
        await storage.getApiKey(provider: AiProviderType.customProxy),
        equals('new-proxy-key-1234567890'),
      );
    });

    test('throws SecurityException when customProxy provider has empty URL', () async {
      final storage = AiCredentialStorage.inMemory(
        initialProxyApiKey: 'proxy-token-123456789',
        initialProxyUrl: '',
        initialProviderType: AiProviderType.customProxy,
      );

      final provider = GeminiRestAiProvider(
        credentialStorage: storage,
        client: MockClient((_) async => http.Response('{}', 200)),
      );

      await expectLater(
        provider.generateText(AiPromptRequest.singlePrompt('你好')),
        throwsA(isA<SecurityException>()),
      );
      await expectLater(
        provider.testConnection(),
        throwsA(isA<SecurityException>()),
      );
      provider.dispose();
    });

    test('retries transient 503 error and succeeds on retry, sanitizing leaked keys', () async {
      const secretKey = 'AIzaSySecretKey_ABCDEF123456';
      var attempts = 0;

      final client = MockClient((request) async {
        attempts++;
        if (attempts == 1) {
          return http.Response(
            '{"error":{"message":"Upstream overload for key $secretKey"}}',
            503,
          );
        }
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': '你好！'}
                  ]
                },
                'finishReason': 'STOP',
              }
            ],
            'usageMetadata': {'totalTokenCount': 12},
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final storage = AiCredentialStorage.inMemory(initialApiKey: secretKey);
      final provider = GeminiRestAiProvider(
        credentialStorage: storage,
        client: client,
      );

      final res = await provider.generateText(AiPromptRequest.singlePrompt('你好'));
      expect(attempts, equals(2));
      expect(res.text, equals('你好！'));

      final sanitized = AiCredentialStorage.sanitizeSecret(
        'Failure calling endpoint with $secretKey',
        secretKey,
      );
      expect(sanitized.contains(secretKey), isFalse);
      expect(sanitized, contains('[REDACTED_API_KEY]'));
      provider.dispose();
    });

    test('restCompatibleModelSpecs excludes Live API and deprecated Gemini 2.5 Pro', () {
      final restIds = AiModelRegistry().restCompatibleModelSpecs.map((s) => s.modelId).toList();
      expect(restIds, isNot(contains(AiModelRegistry.modelGemini38Live)));
      expect(restIds, isNot(contains(AiModelRegistry.modelGemini25Pro)));
      expect(restIds, contains(AiModelRegistry.modelGemini25Flash));
    });
  });
}
