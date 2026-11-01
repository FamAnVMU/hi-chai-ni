import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/ai_model_config.dart';

/// Secure local credential storage for Bring-Your-Own-Key (BYOK) model.
///
/// SECURITY ARCHITECTURE:
/// - Uses [FlutterSecureStorage] backed by Android KeyStore with AES-GCM encryption.
/// - Protects API keys at rest against unauthorized file-system reads from other apps.
/// - Zero-Log Policy: API keys are NEVER printed in logs, debug output, or analytics.
///   All error messages, diagnostics, and test results pass through [sanitizeSecret].
class AiCredentialStorage {
  static const String _keyGeminiApiKey = 'hi_chinese_gemini_api_key';
  static const String _keyCustomProxyUrl = 'hi_chinese_custom_proxy_url';
  static const String _keyProviderType = 'hi_chinese_ai_provider_type';
  static const String _keySelectedModel = 'hi_chinese_selected_ai_model';

  final FlutterSecureStorage _storage;
  final Map<String, String>? inMemoryStore;

  AiCredentialStorage({
    FlutterSecureStorage? storage,
    this.inMemoryStore,
  })  : _storage = storage ??
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
    return AiCredentialStorage(inMemoryStore: map);
  }

  // ==================== API KEY ====================

  /// Saves the user-supplied Gemini API key securely.
  Future<void> saveApiKey(String apiKey) async {
    final cleanKey = apiKey.trim();
    if (cleanKey.isEmpty) {
      await clearApiKey();
      return;
    }
    final memory = inMemoryStore;
    if (memory != null) {
      memory[_keyGeminiApiKey] = cleanKey;
    } else {
      await _storage.write(key: _keyGeminiApiKey, value: cleanKey);
    }
  }

  /// Retrieves the raw API key. Returns null if not configured.
  Future<String?> getApiKey() async {
    final memory = inMemoryStore;
    if (memory != null) {
      return memory[_keyGeminiApiKey];
    }
    return await _storage.read(key: _keyGeminiApiKey);
  }

  /// Checks if an API key is currently saved.
  Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  /// Deletes the stored API key.
  Future<void> clearApiKey() async {
    final memory = inMemoryStore;
    if (memory != null) {
      memory.remove(_keyGeminiApiKey);
    } else {
      await _storage.delete(key: _keyGeminiApiKey);
    }
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
    final memory = inMemoryStore;
    if (memory != null) {
      return memory[_keyCustomProxyUrl];
    }
    return await _storage.read(key: _keyCustomProxyUrl);
  }

  // ==================== SECURITY & REDACTION ====================

  /// Returns a safe, redacted mask of the key for UI display (e.g. "AIza...4xQ1").
  Future<String?> getMaskedApiKey() async {
    final key = await getApiKey();
    if (key == null || key.isEmpty) return null;
    return maskKey(key);
  }

  /// Helper to safely mask any string before UI display.
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
}
