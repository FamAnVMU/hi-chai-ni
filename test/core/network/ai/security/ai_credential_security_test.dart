import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hi_chinese/core/database/dao/app_settings_dao.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/network/ai/models/ai_errors.dart';
import 'package:hi_chinese/core/network/ai/models/ai_model_config.dart';
import 'package:hi_chinese/core/network/ai/providers/gemini_rest_ai_provider.dart';
import 'package:hi_chinese/core/network/ai/security/ai_credential_storage.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/features/onboarding/presentation/screens/onboarding_api_key_screen.dart';
import 'package:hi_chinese/features/onboarding/presentation/screens/onboarding_flow_screen.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late AppSettingsDao settingsDao;

  setUp(() async {
    db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE ${DatabaseConstants.tableAppSettings} (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL,
            updated_at TEXT NOT NULL
          );
        ''');
      },
    );
    settingsDao = AppSettingsDao(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('AiCredentialStorage - Security & Verification Unit Tests', () {
    test('1. Save new API key with instant read-back verification', () async {
      final inMemory = <String, String>{};
      final storage = AiCredentialStorage(inMemoryStore: inMemory);

      const validKey = 'AIzaSyA1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P';
      await storage.saveApiKey(validKey);

      final retrieved = await storage.getApiKey();
      expect(retrieved, equals(validKey));
      expect(inMemory['hi_chinese_gemini_api_key'], equals(validKey));
    });

    test('2. Read saved API key and masked representation', () async {
      final inMemory = <String, String>{};
      final storage = AiCredentialStorage(inMemoryStore: inMemory);

      const validKey = 'AIzaSy1234567890abcdefghijklmnopqrst';
      await storage.saveApiKey(validKey);

      final hasKey = await storage.hasApiKey();
      expect(hasKey, isTrue);

      final masked = await storage.getMaskedApiKey();
      expect(masked, isNotNull);
      expect(masked!.startsWith('AIza'), isTrue);
      expect(masked.endsWith('opqrst'.substring(2)), isTrue);
      expect(masked.contains('...'), isTrue);
      expect(masked.contains('1234567890'), isFalse);
    });

    test('3. Empty or whitespace API key clears storage without throwing', () async {
      final inMemory = <String, String>{};
      final storage = AiCredentialStorage(inMemoryStore: inMemory);

      await storage.saveApiKey('AIzaSy1234567890abcdefghijklmnopqrst');
      expect(await storage.hasApiKey(), isTrue);

      // Save empty
      await storage.saveApiKey('');
      expect(await storage.hasApiKey(), isFalse);
      expect(await storage.getApiKey(), isNull);

      // Save whitespace
      await storage.saveApiKey('   \t\n  ');
      expect(await storage.hasApiKey(), isFalse);
      expect(await storage.getApiKey(), isNull);
    });

    test('4. Format validation rejects short keys (<20 chars) and keys with spaces/newlines', () {
      expect(AiCredentialStorage.validateApiKey(null), isNotNull);
      expect(AiCredentialStorage.validateApiKey(''), isNotNull);
      expect(AiCredentialStorage.validateApiKey('AIzaSy1234'), contains('20 ký tự'));
      expect(AiCredentialStorage.validateApiKey('AIzaSy 1234567890abcdefghijklmn'), contains('khoảng trắng'));
      expect(AiCredentialStorage.validateApiKey('AIzaSy\n1234567890abcdefghijklmn'), contains('khoảng trắng'));
      expect(AiCredentialStorage.validateApiKey('AIzaSy1234567890abcdefghijklmnopqrst'), isNull);
    });

    test('5. Simulated secure storage write failure throws StateError and aborts verification', () async {
      final inMemory = <String, String>{};
      final storage = AiCredentialStorage(inMemoryStore: inMemory, simulateFailure: true);

      expect(
        () async => await storage.saveApiKey('AIzaSy1234567890abcdefghijklmnopqrst'),
        throwsA(isA<StateError>()),
      );
    });

    test('6. Multi-provider credential isolation (Gemini, Firebase, OpenAI, Claude)', () async {
      final inMemory = <String, String>{};
      final storage = AiCredentialStorage(inMemoryStore: inMemory);

      const geminiKey = 'AIzaSyGeminiKey12345678901234567890';
      const openaiKey = 'sk-proj-OpenAiKey12345678901234567890';
      const claudeKey = 'sk-ant-ClaudeKey12345678901234567890';

      await storage.saveApiKey(geminiKey, provider: AiProviderType.geminiRest);
      await storage.saveApiKeyForProviderName('openai', openaiKey);
      await storage.saveApiKeyForProviderName('claude', claudeKey);

      expect(await storage.getApiKey(provider: AiProviderType.geminiRest), equals(geminiKey));
      expect(await storage.getApiKeyForProviderName('openai'), equals(openaiKey));
      expect(await storage.getApiKeyForProviderName('claude'), equals(claudeKey));

      // Clearing one does not clear others
      await storage.clearApiKeyForProviderName('openai');
      expect(await storage.getApiKeyForProviderName('openai'), isNull);
      expect(await storage.getApiKey(provider: AiProviderType.geminiRest), equals(geminiKey));
      expect(await storage.getApiKeyForProviderName('claude'), equals(claudeKey));
    });

    test('7. sanitizeSecret strips API keys from log or error messages', () {
      const secret = 'AIzaSyA1B2C3D4E5F6G7H8I9J0K1L2M3N4O5P';
      final rawError = 'Failed to connect with key $secret at endpoint http://example.com';

      final sanitized = AiCredentialStorage.sanitizeSecret(rawError, secret);
      expect(sanitized.contains(secret), isFalse);
      expect(sanitized.contains('[REDACTED_API_KEY]'), isTrue);
    });

    test('7b. saveCustomProxyUrl enforces HTTPS and blocks SSRF / loopback hosts', () async {
      final inMemory = <String, String>{};
      final storage = AiCredentialStorage(inMemoryStore: inMemory);

      // Rejects plain HTTP
      expect(
        () => storage.saveCustomProxyUrl('http://insecure-proxy.com/api'),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('HTTPS'))),
      );

      // Rejects localhost / 127.0.0.1 / private IPs
      expect(
        () => storage.saveCustomProxyUrl('https://localhost:8080'),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('loopback'))),
      );
      expect(
        () => storage.saveCustomProxyUrl('https://127.0.0.1/proxy'),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('loopback'))),
      );
      expect(
        () => storage.saveCustomProxyUrl('https://192.168.1.100/ai'),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('loopback'))),
      );
      expect(
        () => storage.saveCustomProxyUrl('https://10.0.0.1/ai'),
        throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('loopback'))),
      );

      // Accepts valid HTTPS proxy URL
      await storage.saveCustomProxyUrl('https://secure-ai-proxy.company.com/v1');
      expect(await storage.getCustomProxyUrl(), equals('https://secure-ai-proxy.company.com/v1'));

      // Allows clearing proxy URL with null or empty
      await storage.saveCustomProxyUrl(null);
      expect(await storage.getCustomProxyUrl(), isNull);
    });

    test('7c. GeminiRestAiProvider.testConnection throws SecurityException before sending API key if proxy is unsafe', () async {
      final inMemory = <String, String>{};
      final storage = AiCredentialStorage(inMemoryStore: inMemory);
      await storage.saveApiKey('AIzaSyValidGeminiKeyForTest1234567');
      // Inject unsafe proxy directly into store (simulating legacy or tainted store)
      inMemory['hi_chinese_custom_proxy_url'] = 'http://insecure-backend.local';

      final provider = GeminiRestAiProvider(credentialStorage: storage);
      expect(
        () => provider.testConnection(),
        throwsA(isA<SecurityException>()),
      );

      // Also test loopback IP
      inMemory['hi_chinese_custom_proxy_url'] = 'https://127.0.0.1:8080';
      expect(
        () => provider.testConnection(),
        throwsA(isA<SecurityException>()),
      );
    });
  });

  group('Legacy Credential Migration from SQLite to FlutterSecureStorage', () {
    test('8. Full Migration: Reads plaintext, writes secure, verifies, and deletes plaintext from SQLite', () async {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      const legacyGeminiKey = 'AIzaSyLegacyGeminiKey12345678901234567';
      const legacyProxyUrl = 'https://proxy.example.com/v1';

      // Insert legacy plaintext into SQLite app_settings directly
      await db.insert(DatabaseConstants.tableAppSettings, {
        'key': 'gemini_api_key',
        'value': legacyGeminiKey,
        'updated_at': nowIso,
      });
      await db.insert(DatabaseConstants.tableAppSettings, {
        'key': 'custom_proxy_url',
        'value': legacyProxyUrl,
        'updated_at': nowIso,
      });

      final inMemory = <String, String>{};
      final storage = AiCredentialStorage(inMemoryStore: inMemory);

      final result = await storage.migrateLegacyCredentials(db);

      expect(result.isSuccess, isTrue);
      expect(result.migratedCount, equals(2));
      expect(result.failedCount, equals(0));
      expect(result.migratedKeys, containsAll(['gemini_api_key', 'custom_proxy_url']));

      // Verify written to secure storage
      expect(await storage.getApiKey(provider: AiProviderType.geminiRest), equals(legacyGeminiKey));
      expect(await storage.getCustomProxyUrl(), equals(legacyProxyUrl));

      // Verify DELETED from SQLite app_settings
      final remainingKeys = await db.query(DatabaseConstants.tableAppSettings);
      final remainingKeyNames = remainingKeys.map((r) => r['key'] as String).toList();
      expect(remainingKeyNames.contains('gemini_api_key'), isFalse);
      expect(remainingKeyNames.contains('custom_proxy_url'), isFalse);

      // Verify migration completion flag is recorded
      expect(remainingKeyNames.contains('credential_migration_completed'), isTrue);
      final completionRow = remainingKeys.firstWhere((r) => r['key'] == 'credential_migration_completed');
      expect(completionRow['value'], equals('true'));
    });

    test('9. Migration Failure Safety: When secure storage fails, legacy plaintext is preserved in SQLite', () async {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      const legacyKey = 'AIzaSyPreservePlaintext1234567890123456';

      await db.insert(DatabaseConstants.tableAppSettings, {
        'key': 'gemini_api_key',
        'value': legacyKey,
        'updated_at': nowIso,
      });

      final inMemory = <String, String>{};
      final failingStorage = AiCredentialStorage(inMemoryStore: inMemory, simulateFailure: true);

      final result = await failingStorage.migrateLegacyCredentials(db);

      expect(result.isSuccess, isFalse);
      expect(result.migratedCount, equals(0));
      expect(result.failedCount, equals(1));

      // CRITICAL ASSERTION: The plaintext key MUST NOT be deleted from SQLite when migration fails!
      final preservedRows = await db.query(
        DatabaseConstants.tableAppSettings,
        where: 'key = ?',
        whereArgs: ['gemini_api_key'],
      );
      expect(preservedRows.length, equals(1));
      expect(preservedRows.first['value'], equals(legacyKey));
    });

    test('10. Migration Idempotency: Running migration a second time does nothing and leaves 0 migrations', () async {
      final nowIso = DateTime.now().toUtc().toIso8601String();
      const legacyKey = 'AIzaSyIdempotentTest12345678901234567';

      await db.insert(DatabaseConstants.tableAppSettings, {
        'key': 'gemini_api_key',
        'value': legacyKey,
        'updated_at': nowIso,
      });

      final inMemory = <String, String>{};
      final storage = AiCredentialStorage(inMemoryStore: inMemory);

      // Pass 1
      final res1 = await storage.migrateLegacyCredentials(db);
      expect(res1.isSuccess, isTrue);
      expect(res1.migratedCount, equals(1));

      // Pass 2
      final res2 = await storage.migrateLegacyCredentials(db);
      expect(res2.isSuccess, isTrue);
      expect(res2.migratedCount, equals(0));
    });

    test('11. AppSettingsDao defense-in-depth: Throws ArgumentError when attempting to store API keys in SQLite', () async {
      expect(
        () => settingsDao.setSetting('gemini_api_key', 'AIzaSyForbiddenPlaintext123456789'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => settingsDao.setSetting('user_secret_key', 'my_secret_token_1234567890'),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => settingsDao.setSetting('oauth_auth_token', 'token_bearer_1234567890123'),
        throwsA(isA<ArgumentError>()),
      );

      // Non-sensitive settings work fine
      await settingsDao.setSetting('theme_mode', 'dark');
      final val = await settingsDao.getSetting('theme_mode');
      expect(val, equals('dark'));
    });
  });

  group('Onboarding Flow Credential UI & Widget Tests', () {
    testWidgets('12. OnboardingApiKeyScreen validates input and calls onSaveApiKey securely', (tester) async {
      String? savedKey;

      await tester.pumpWidget(
        MaterialApp(
          home: OnboardingApiKeyScreen(
            onSkip: () {},
            onSaveApiKey: (key) async {
              savedKey = key;
              return true;
            },
          ),
        ),
      );

      // Find the TextField
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      // 1. Enter invalid short key (<20 chars)
      await tester.enterText(textFieldFinder, 'short_key');
      final saveBtnFinder = find.byType(HiButton);
      await tester.ensureVisible(saveBtnFinder);
      await tester.tap(saveBtnFinder);
      await tester.pumpAndSettle();

      // Error message should be visible, onSaveApiKey not called
      expect(find.textContaining('20 ký tự'), findsOneWidget);
      expect(savedKey, isNull);

      // 2. Enter valid key
      const validKey = 'AIzaSyValidOnboardingKey1234567890';
      await tester.enterText(textFieldFinder, validKey);
      await tester.ensureVisible(saveBtnFinder);
      await tester.tap(saveBtnFinder);
      await tester.pumpAndSettle();

      expect(savedKey, equals(validKey));
      expect(find.textContaining('20 ký tự'), findsNothing);
    });

    testWidgets('13. OnboardingFlowScreen saves key to AiCredentialStorage and advances step', (tester) async {
      final inMemory = <String, String>{};
      final storage = AiCredentialStorage(inMemoryStore: inMemory);

      bool completed = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: OnboardingFlowScreen(
              onOnboardingComplete: () => completed = true,
              credentialStorageOverride: storage,
            ),
          ),
        ),
      );

      // Step 0: OnboardingApiKeyScreen is showing
      expect(find.text('Cấu hình AI Trợ Giảng (Tùy chọn)'), findsOneWidget);

      // Enter valid API key
      const testKey = 'AIzaSyOnboardingFlowTestKey12345678';
      await tester.enterText(find.byType(TextField), testKey);

      // Tap Save
      final saveBtnFinder = find.byType(HiButton);
      await tester.ensureVisible(saveBtnFinder);
      await tester.tap(saveBtnFinder);
      await tester.pumpAndSettle();

      // Verify saved to secure storage
      expect(await storage.getApiKey(), equals(testKey));

      // Verify advanced to Step 1: Placement Test Intro Screen
      expect(find.text('Khảo Sát Năng Lực Đầu Vào'), findsOneWidget);
      expect(completed, isFalse);
    });
  });
}
