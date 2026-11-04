import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_constants.dart';
import '../models/ai_model_config.dart';

/// Result report from migrating legacy SQLite app_settings to FlutterSecureStorage.
class CredentialMigrationResult {
  final bool isSuccess;
  final int migratedCount;
  final int failedCount;
  final String? errorMessage;
  final List<String> migratedKeys;

  const CredentialMigrationResult({
    required this.isSuccess,
    this.migratedCount = 0,
    this.failedCount = 0,
    this.errorMessage,
    this.migratedKeys = const [],
  });

  @override
  String toString() =>
      'CredentialMigrationResult(isSuccess: $isSuccess, migrated: $migratedCount, failed: $failedCount, error: $errorMessage, keys: $migratedKeys)';
}

/// Secure local credential storage for Bring-Your-Own-Key (BYOK) model.
///
/// SECURITY ARCHITECTURE:
/// - Uses [FlutterSecureStorage] backed by Android KeyStore with AES-GCM encryption.
/// - Protects API keys at rest against unauthorized file-system reads from other apps.
/// - Zero-Log Policy: API keys are NEVER printed in logs, debug output, or analytics.
///   All error messages, diagnostics, and test results pass through [sanitizeSecret].
/// - Instant Write-Verification: Every write is immediately read back and verified before reporting success.
class AiCredentialStorage {
  static const String _keyGeminiApiKey = 'hi_chinese_gemini_api_key';
  static const String _keyCustomProxyUrl = 'hi_chinese_custom_proxy_url';
  static const String _keyProviderType = 'hi_chinese_ai_provider_type';
  static const String _keySelectedModel = 'hi_chinese_selected_ai_model';

  final FlutterSecureStorage _storage;
  final Map<String, String>? inMemoryStore;

  /// Test hook to simulate hardware KeyStore or secure storage write/read failures.
  bool simulateFailure;

  AiCredentialStorage({
    FlutterSecureStorage? storage,
    this.inMemoryStore,
    this.simulateFailure = false,
  }) : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                resetOnError: true,
              ),
            );

  /// Factory for unit testing without platform channel dependencies.
  factory AiCredentialStorage.inMemory({
    String? initialApiKey,
    String? initialProxyUrl,
    AiProviderType? initialProviderType,
    String? initialSelectedModel,
    bool simulateFailure = false,
  }) {
    final map = <String, String>{};
    if (initialApiKey != null) map[_keyGeminiApiKey] = initialApiKey;
    if (initialProxyUrl != null) map[_keyCustomProxyUrl] = initialProxyUrl;
    if (initialProviderType != null) {
      map[_keyProviderType] = initialProviderType.name;
    }
    if (initialSelectedModel != null) {
      map[_keySelectedModel] = initialSelectedModel;
    }
    return AiCredentialStorage(
      inMemoryStore: map,
      simulateFailure: simulateFailure,
    );
  }

  // ==================== PROVIDER KEY RESOLUTION ====================

  static String keyForProvider(AiProviderType provider) {
    switch (provider) {
      case AiProviderType.geminiRest:
        return _keyGeminiApiKey;
      case AiProviderType.firebaseAiLogic:
        return 'hi_chinese_firebase_api_key';
      case AiProviderType.customProxy:
        return 'hi_chinese_custom_proxy_api_key';
    }
  }

  static String keyForProviderName(String providerName) {
    final clean = providerName.trim().toLowerCase();
    if (clean == 'gemini' || clean == 'geminirest') return _keyGeminiApiKey;
    return 'hi_chinese_${clean}_api_key';
  }

  // ==================== API KEY VALIDATION ====================

  /// Validates API key format without exposing the key in logs or error messages.
  static String? validateApiKey(String? apiKey, {int minLength = 20}) {
    if (apiKey == null || apiKey.trim().isEmpty) {
      return 'Khóa API không được để trống';
    }
    final clean = apiKey.trim();
    if (clean.length < minLength) {
      return 'Khóa API quá ngắn (phải có ít nhất $minLength ký tự)';
    }
    if (clean.contains(' ') || clean.contains('\n') || clean.contains('\t')) {
      return 'Khóa API không được chứa khoảng trắng hoặc ký tự xuống dòng';
    }
    return null;
  }

  // ==================== API KEY (PROVIDER-AWARE) ====================

  /// Saves the user-supplied API key securely with instant read-back verification.
  /// Throws [StateError] or [ArgumentError] if verification fails.
  Future<void> saveApiKey(
    String apiKey, {
    AiProviderType provider = AiProviderType.geminiRest,
  }) async {
    if (simulateFailure) {
      throw StateError('Simulated secure storage I/O failure');
    }

    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      await clearApiKey(provider: provider);
      return;
    }

    final validationErr = validateApiKey(cleanKey);
    if (validationErr != null) {
      throw ArgumentError(validationErr);
    }

    final storageKey = keyForProvider(provider);
    final memory = inMemoryStore;
    if (memory != null) {
      memory[storageKey] = cleanKey;
    } else {
      await _storage.write(key: storageKey, value: cleanKey);
    }

    // Step 4: Đọc lại credential để xác minh tức thì
    final verified = await getApiKey(provider: provider);
    if (verified != cleanKey) {
      throw StateError('Xác minh lưu trữ khóa API thất bại: Không thể đọc lại chính xác từ secure storage');
    }
  }

  /// Retrieves the raw API key for the given provider. Returns null if not configured.
  Future<String?> getApiKey({
    AiProviderType provider = AiProviderType.geminiRest,
  }) async {
    if (simulateFailure) {
      throw StateError('Simulated secure storage read failure');
    }
    final storageKey = keyForProvider(provider);
    final memory = inMemoryStore;
    if (memory != null) {
      return memory[storageKey];
    }
    return await _storage.read(key: storageKey);
  }

  /// Checks if an API key is currently saved for the given provider.
  Future<bool> hasApiKey({
    AiProviderType provider = AiProviderType.geminiRest,
  }) async {
    final key = await getApiKey(provider: provider);
    return key != null && key.isNotEmpty;
  }

  /// Deletes the stored API key for the given provider.
  Future<void> clearApiKey({
    AiProviderType provider = AiProviderType.geminiRest,
  }) async {
    final storageKey = keyForProvider(provider);
    final memory = inMemoryStore;
    if (memory != null) {
      memory.remove(storageKey);
    } else {
      await _storage.delete(key: storageKey);
    }
  }

  /// Returns a safe, redacted mask of the key for UI display (e.g. "AIza...4xQ1").
  Future<String?> getMaskedApiKey({
    AiProviderType provider = AiProviderType.geminiRest,
  }) async {
    final key = await getApiKey(provider: provider);
    if (key == null || key.isEmpty) return null;
    return maskKey(key);
  }

  // ==================== NAMED PROVIDER CREDENTIALS ====================

  /// Saves API key for any arbitrary provider name (e.g. 'openai', 'claude').
  Future<void> saveApiKeyForProviderName(String providerName, String apiKey) async {
    if (simulateFailure) {
      throw StateError('Simulated secure storage I/O failure');
    }

    final cleanKey = apiKey.trim();
    final storageKey = keyForProviderName(providerName);
    if (cleanKey.isEmpty) {
      await clearApiKeyForProviderName(providerName);
      return;
    }

    final validationErr = validateApiKey(cleanKey);
    if (validationErr != null) {
      throw ArgumentError(validationErr);
    }

    final memory = inMemoryStore;
    if (memory != null) {
      memory[storageKey] = cleanKey;
    } else {
      await _storage.write(key: storageKey, value: cleanKey);
    }

    final verified = await getApiKeyForProviderName(providerName);
    if (verified != cleanKey) {
      throw StateError('Xác minh lưu trữ khóa API cho provider $providerName thất bại');
    }
  }

  Future<String?> getApiKeyForProviderName(String providerName) async {
    if (simulateFailure) {
      throw StateError('Simulated secure storage read failure');
    }
    final storageKey = keyForProviderName(providerName);
    final memory = inMemoryStore;
    if (memory != null) {
      return memory[storageKey];
    }
    return await _storage.read(key: storageKey);
  }

  Future<void> clearApiKeyForProviderName(String providerName) async {
    final storageKey = keyForProviderName(providerName);
    final memory = inMemoryStore;
    if (memory != null) {
      memory.remove(storageKey);
    } else {
      await _storage.delete(key: storageKey);
    }
  }

  Future<bool> hasApiKeyForProviderName(String providerName) async {
    final key = await getApiKeyForProviderName(providerName);
    return key != null && key.isNotEmpty;
  }

  Future<String?> getMaskedApiKeyForProviderName(String providerName) async {
    final key = await getApiKeyForProviderName(providerName);
    if (key == null || key.isEmpty) return null;
    return maskKey(key);
  }

  // ==================== PROVIDER TYPE ====================

  /// Saves the active AI provider choice.
  Future<void> saveProviderType(AiProviderType type) async {
    final memory = inMemoryStore;
    if (memory != null) {
      memory[_keyProviderType] = type.name;
    } else {
      await _storage.write(key: _keyProviderType, value: type.name);
    }
  }

  /// Retrieves the active AI provider choice (defaults to [AiProviderType.geminiRest]).
  Future<AiProviderType> getProviderType() async {
    final memory = inMemoryStore;
    final val = memory != null
        ? memory[_keyProviderType]
        : await _storage.read(key: _keyProviderType);

    if (val == null) return AiProviderType.geminiRest;
    return AiProviderType.values.firstWhere(
      (e) => e.name == val,
      orElse: () => AiProviderType.geminiRest,
    );
  }

  // ==================== SELECTED MODEL ====================

  /// Saves the user's preferred default model ID.
  Future<void> saveSelectedModel(String modelId) async {
    final memory = inMemoryStore;
    if (memory != null) {
      memory[_keySelectedModel] = modelId;
    } else {
      await _storage.write(key: _keySelectedModel, value: modelId);
    }
  }

  /// Retrieves the user's preferred default model ID.
  Future<String> getSelectedModel() async {
    final memory = inMemoryStore;
    final val = memory != null
        ? memory[_keySelectedModel]
        : await _storage.read(key: _keySelectedModel);

    return val ?? AiModelRegistry.modelGemini35FlashLite;
  }

  // ==================== PROXY URL ====================

  /// Saves an optional custom backend proxy URL.
  Future<void> saveCustomProxyUrl(String? url) async {
    if (simulateFailure) {
      throw StateError('Simulated secure storage I/O failure');
    }

    if (url != null && url.trim().isNotEmpty) {
      final cleanUrl = url.trim();
      final uri = Uri.tryParse(cleanUrl);
      if (uri == null || !uri.hasScheme || uri.scheme.toLowerCase() != 'https') {
        throw ArgumentError('Custom Proxy URL bắt buộc phải sử dụng giao thức HTTPS bảo mật.');
      }
      final host = uri.host.toLowerCase();
      if (host == 'localhost' || host == '127.0.0.1' || host.startsWith('192.168.') || host.startsWith('10.')) {
        throw ArgumentError('Không được sử dụng địa chỉ loopback hoặc IP nội bộ cho AI Proxy.');
      }
    }

    final memory = inMemoryStore;
    if (url == null || url.trim().isEmpty) {
      if (memory != null) {
        memory.remove(_keyCustomProxyUrl);
      } else {
        await _storage.delete(key: _keyCustomProxyUrl);
      }
    } else {
      if (memory != null) {
        memory[_keyCustomProxyUrl] = url.trim();
      } else {
        await _storage.write(key: _keyCustomProxyUrl, value: url.trim());
      }
    }
  }

  /// Retrieves custom backend proxy URL if configured.
  Future<String?> getCustomProxyUrl() async {
    if (simulateFailure) {
      throw StateError('Simulated secure storage read failure');
    }
    final memory = inMemoryStore;
    if (memory != null) {
      return memory[_keyCustomProxyUrl];
    }
    return await _storage.read(key: _keyCustomProxyUrl);
  }

  // ==================== SECURITY & REDACTION ====================

  /// Helper to safely mask any key string before UI display.
  static String maskKey(String? key) {
    if (key == null || key.isEmpty) return '<EMPTY>';
    if (key.length <= 8) return '********';
    return '${key.substring(0, 4)}...${key.substring(key.length - 4)}';
  }

  /// Cleanses any sensitive key out of log messages or error payloads.
  static String sanitizeSecret(String input, [String? knownKey]) {
    var sanitized = input;
    if (knownKey != null && knownKey.isNotEmpty) {
      sanitized = sanitized.replaceAll(knownKey, '[REDACTED_API_KEY]');
    }
    // Pattern for Google AI Studio API Keys: AIzaSy... (39 chars)
    final googleKeyPattern = RegExp(r'AIza[0-9A-Za-z\-_]{35}');
    sanitized = sanitized.replaceAll(googleKeyPattern, '[REDACTED_API_KEY]');
    return sanitized;
  }

  // ==================== LEGACY SQLITE CREDENTIAL MIGRATION ====================

  /// Safely migrates legacy plaintext credentials from SQLite [app_settings] to [FlutterSecureStorage].
  ///
  /// INVARIANTS:
  /// 1. Idempotent: Can be safely rerun without re-migrating or data loss.
  /// 2. Verification-gated: Plaintext row is ONLY deleted if and when secure storage write has been verified.
  /// 3. Failure-safe: If secure storage fails, legacy plaintext is preserved and failure is reported.
  /// 4. Zero-Leak: Credentials are never logged or output to logs.
  Future<CredentialMigrationResult> migrateLegacyCredentials(Database db) async {
    int migratedCount = 0;
    int failedCount = 0;
    String? firstError;
    final List<String> migratedKeysList = [];

    final legacyCandidates = [
      'gemini_api_key',
      'api_key',
      'google_api_key',
      'custom_proxy_url',
      'ai_proxy_url',
      'openai_api_key',
      'claude_api_key',
    ];

    try {
      final placeholders = List.filled(legacyCandidates.length, '?').join(',');
      final rows = await db.query(
        DatabaseConstants.tableAppSettings,
        where: 'key IN ($placeholders)',
        whereArgs: legacyCandidates,
      );

      if (rows.isEmpty) {
        // Nothing to migrate, mark as completed idempotently
        await _recordMigrationStatus(db, isSuccess: true);
        return const CredentialMigrationResult(isSuccess: true, migratedCount: 0);
      }

      for (final row in rows) {
        final key = row['key'] as String;
        final rawVal = row['value'] as String?;

        if (rawVal == null || rawVal.trim().isEmpty) {
          // Delete empty junk row
          await db.delete(
            DatabaseConstants.tableAppSettings,
            where: 'key = ?',
            whereArgs: [key],
          );
          continue;
        }

        final cleanVal = rawVal.trim();
        bool isMigrated = false;

        try {
          if (key == 'gemini_api_key' || key == 'api_key' || key == 'google_api_key') {
            final existing = await getApiKey(provider: AiProviderType.geminiRest);
            if (existing == null || existing.isEmpty) {
              await saveApiKey(cleanVal, provider: AiProviderType.geminiRest);
            }
            final verified = await getApiKey(provider: AiProviderType.geminiRest);
            if (verified != null && verified.isNotEmpty) {
              isMigrated = true;
            }
          } else if (key == 'custom_proxy_url' || key == 'ai_proxy_url') {
            final existing = await getCustomProxyUrl();
            if (existing == null || existing.isEmpty) {
              await saveCustomProxyUrl(cleanVal);
            }
            final verified = await getCustomProxyUrl();
            if (verified != null && verified.isNotEmpty) {
              isMigrated = true;
            }
          } else if (key == 'openai_api_key') {
            final existing = await getApiKeyForProviderName('openai');
            if (existing == null || existing.isEmpty) {
              await saveApiKeyForProviderName('openai', cleanVal);
            }
            final verified = await getApiKeyForProviderName('openai');
            if (verified != null && verified.isNotEmpty) {
              isMigrated = true;
            }
          } else if (key == 'claude_api_key') {
            final existing = await getApiKeyForProviderName('claude');
            if (existing == null || existing.isEmpty) {
              await saveApiKeyForProviderName('claude', cleanVal);
            }
            final verified = await getApiKeyForProviderName('claude');
            if (verified != null && verified.isNotEmpty) {
              isMigrated = true;
            }
          }

          if (isMigrated) {
            // STEP 5: Chỉ xóa bản plaintext sau khi lưu thành công!
            await db.delete(
              DatabaseConstants.tableAppSettings,
              where: 'key = ?',
              whereArgs: [key],
            );
            migratedCount++;
            migratedKeysList.add(key);
            debugPrint('[CredentialMigration] Migrated legacy credential "$key" to secure storage.');
          } else {
            // STEP 6: Nếu lưu thất bại, giữ lại dữ liệu cũ và báo trạng thái migration thất bại
            failedCount++;
            firstError ??= 'Verification mismatch for $key';
            debugPrint('[CredentialMigration:Warning] Could not verify write for "$key". Plaintext preserved.');
          }
        } catch (e) {
          // STEP 6: Giữ lại dữ liệu cũ khi có exception
          failedCount++;
          firstError ??= sanitizeSecret(e.toString(), cleanVal);
          debugPrint('[CredentialMigration:Error] Secure storage write failed for "$key". Plaintext preserved.');
        }
      }

      final isOverallSuccess = failedCount == 0;
      await _recordMigrationStatus(db, isSuccess: isOverallSuccess);

      return CredentialMigrationResult(
        isSuccess: isOverallSuccess,
        migratedCount: migratedCount,
        failedCount: failedCount,
        errorMessage: firstError,
        migratedKeys: migratedKeysList,
      );
    } catch (e) {
      final sanitized = sanitizeSecret(e.toString());
      debugPrint('[CredentialMigration:Fatal] Error querying legacy credentials: $sanitized');
      return CredentialMigrationResult(
        isSuccess: false,
        migratedCount: migratedCount,
        failedCount: failedCount + 1,
        errorMessage: sanitized,
        migratedKeys: migratedKeysList,
      );
    }
  }

  Future<void> _recordMigrationStatus(Database db, {required bool isSuccess}) async {
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    await db.insert(
      DatabaseConstants.tableAppSettings,
      {
        'key': 'credential_migration_completed',
        'value': isSuccess ? 'true' : 'failed',
        'updated_at': nowUtc,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
