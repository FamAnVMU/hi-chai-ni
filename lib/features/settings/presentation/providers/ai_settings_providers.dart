import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/ai/ai.dart';
import '../../domain/models/firebase_config_status.dart';

/// State representation for AI Configuration screen.
class AiSettingsState {
  final AiProviderType providerType;
  final String selectedModelId;
  final String? maskedApiKey;
  final bool hasApiKey;
  final String? proxyUrl;
  final bool isTestingConnection;
  final ConnectionTestResult? connectionTestResult;
  final FirebaseConfigStatus firebaseStatus;
  final bool isSavingKey;

  const AiSettingsState({
    this.providerType = AiProviderType.geminiRest,
    this.selectedModelId = AiModelRegistry.modelGemini35FlashLite,
    this.maskedApiKey,
    this.hasApiKey = false,
    this.proxyUrl,
    this.isTestingConnection = false,
    this.connectionTestResult,
    this.firebaseStatus = const FirebaseConfigStatus(),
    this.isSavingKey = false,
  });

  AiSettingsState copyWith({
    AiProviderType? providerType,
    String? selectedModelId,
    String? maskedApiKey,
    bool? hasApiKey,
    String? proxyUrl,
    bool? isTestingConnection,
    ConnectionTestResult? connectionTestResult,
    FirebaseConfigStatus? firebaseStatus,
    bool? isSavingKey,
  }) {
    return AiSettingsState(
      providerType: providerType ?? this.providerType,
      selectedModelId: selectedModelId ?? this.selectedModelId,
      maskedApiKey: maskedApiKey ?? this.maskedApiKey,
      hasApiKey: hasApiKey ?? this.hasApiKey,
      proxyUrl: proxyUrl ?? this.proxyUrl,
      isTestingConnection: isTestingConnection ?? this.isTestingConnection,
      connectionTestResult: connectionTestResult ?? this.connectionTestResult,
      firebaseStatus: firebaseStatus ?? this.firebaseStatus,
      isSavingKey: isSavingKey ?? this.isSavingKey,
    );
  }
}

/// Notifier coordinating AI settings persistence, credential encryption,
/// model selection, and real connection testing.
class AiSettingsNotifier extends Notifier<AiSettingsState> {
  late final AiCredentialStorage _storage;
  late final AiModelRegistry _modelRegistry;
  late final AiService _aiService;

  @override
  AiSettingsState build() {
    _storage = ref.watch(aiCredentialStorageProvider);
    _modelRegistry = ref.watch(aiModelRegistryProvider);
    _aiService = ref.watch(aiServiceProvider);

    // Initial asynchronous load
    _loadInitialState();

    return const AiSettingsState();
  }

  Future<void> _loadInitialState() async {
    final providerType = await _storage.getProviderType();
    final hasKey = await _storage.hasApiKey();
    final maskedKey = await _storage.getMaskedApiKey();
    final savedModel = await _storage.getSelectedModel();
    final proxyUrl = await _storage.getCustomProxyUrl();

    _modelRegistry.setDefaultModel(savedModel);

    state = state.copyWith(
      providerType: providerType,
      hasApiKey: hasKey,
      maskedApiKey: maskedKey,
      selectedModelId: savedModel,
      proxyUrl: proxyUrl,
    );
  }

  /// Changes the active AI provider (BYOK, Firebase AI Logic, Custom Proxy).
  Future<void> setProviderType(AiProviderType type) async {
    await _storage.saveProviderType(type);
    state = state.copyWith(providerType: type);
  }

  /// Selects a new default model from the central registry.
  Future<void> selectModel(String modelId) async {
    _modelRegistry.setDefaultModel(modelId);
    await _storage.saveSelectedModel(modelId);
    state = state.copyWith(selectedModelId: modelId);
  }

  /// Securely encrypts and saves a new API key via Android KeyStore.
  Future<void> saveApiKey(String key) async {
    state = state.copyWith(isSavingKey: true);
    await _storage.saveApiKey(key);
    final hasKey = await _storage.hasApiKey();
    final maskedKey = await _storage.getMaskedApiKey();

    state = state.copyWith(
      hasApiKey: hasKey,
      maskedApiKey: maskedKey,
      isSavingKey: false,
    );
  }

  /// Deletes the stored API key completely from secure storage.
  Future<void> clearApiKey() async {
    await _storage.clearApiKey();
    state = state.copyWith(
      hasApiKey: false,
      maskedApiKey: null,
      connectionTestResult: null,
    );
  }

  /// Saves a custom backend proxy URL.
  Future<void> saveCustomProxyUrl(String? url) async {
    await _storage.saveCustomProxyUrl(url);
    state = state.copyWith(proxyUrl: url);
  }

  /// Performs a live connection round-trip test using the selected provider & model.
  Future<ConnectionTestResult> runConnectionTest() async {
    state = state.copyWith(isTestingConnection: true);

    try {
      final result = await _aiService.testConnection(
        modelId: state.selectedModelId,
      );

      state = state.copyWith(
        isTestingConnection: false,
        connectionTestResult: result,
      );
      return result;
    } catch (e) {
      final failResult = ConnectionTestResult.failure(
        providerName: state.providerType.name,
        modelTested: state.selectedModelId,
        latencyMs: 0,
        errorType: ConnectionErrorType.unknown,
        errorMessage: AiCredentialStorage.sanitizeSecret(e.toString()),
      );

      state = state.copyWith(
        isTestingConnection: false,
        connectionTestResult: failResult,
      );
      return failResult;
    }
  }
}

final aiSettingsProvider =
    NotifierProvider<AiSettingsNotifier, AiSettingsState>(AiSettingsNotifier.new);
