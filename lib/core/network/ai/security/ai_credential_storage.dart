import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure local credential storage for Bring-Your-Own-Key (BYOK) model.
///
/// SECURITY ARCHITECTURE NOTE:
/// - Uses [FlutterSecureStorage] backed by Android KeyStore with AES-GCM encryption.
/// - Protects API keys at rest against unauthorized file-system reads from other apps.
/// - Limitation: Mobile memory (RAM) is not completely tamper-proof if the host OS
///   is rooted or compromised. For enterprise distribution with pre-funded keys,
///   a backend proxy with Firebase App Check is recommended.
/// - Zero-Log Policy: API keys are NEVER printed in logs or analytics.
class AiCredentialStorage {
  static const String _keyGeminiApiKey = 'hi_chinese_gemini_api_key';
  static const String _keyCustomProxyUrl = 'hi_chinese_custom_proxy_url';

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
  factory AiCredentialStorage.inMemory({String? initialApiKey, String? initialProxyUrl}) {
    final map = <String, String>{};
    if (initialApiKey != null) map[_keyGeminiApiKey] = initialApiKey;
    if (initialProxyUrl != null) map[_keyCustomProxyUrl] = initialProxyUrl;
    return AiCredentialStorage(inMemoryStore: map);
  }

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

  /// Retrieves the API key. Returns null if not configured.
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

  /// Returns a safe, redacted mask of the key for UI display (e.g. "AIzaSy...4xQ1").
  Future<String?> getMaskedApiKey() async {
    final key = await getApiKey();
    if (key == null || key.isEmpty) return null;
    return maskKey(key);
  }

  /// Helper to safely mask any string before logging.
  static String maskKey(String? key) {
    if (key == null || key.isEmpty) return '<EMPTY>';
    if (key.length <= 8) return '********';
    return '${key.substring(0, 4)}...${key.substring(key.length - 4)}';
  }
}
