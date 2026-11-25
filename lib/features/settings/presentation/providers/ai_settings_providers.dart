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
    bool clearMaskedApiKey = false,
    bool? hasApiKey,
    String? proxyUrl,
    bool clearProxyUrl = false,
    bool? isTestingConnection,
    ConnectionTestResult? connectionTestResult,
    bool clearConnectionResult = false,
    FirebaseConfigStatus? firebaseStatus,
    bool? isSavingKey,
  }) {
    return AiSettingsState(
      providerType: providerType ?? this.providerType,
      selectedModelId: selectedModelId ?? this.selectedModelId,
      maskedApiKey: clearMaskedApiKey ? null : (maskedApiKey ?? this.maskedApiKey),
      hasApiKey: hasApiKey ?? this.hasApiKey,
      proxyUrl: clearProxyUrl ? null : (proxyUrl ?? this.proxyUrl),
      isTestingConnection: isTestingConnection ?? this.isTestingConnection,
      connectionTestResult: clearConnectionResult
          ? null
          : (connectionTestResult ?? this.connectionTestResult),
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
    var providerType = await _storage.getProviderType();
    if (providerType == AiProviderType.firebaseAiLogic) {
      providerType = AiProviderType.geminiRest;
      await _storage.saveProviderType(providerType);
    }

    final hasKey = await _storage.hasApiKey(provider: providerType);
    final maskedKey = await _storage.getMaskedApiKey(provider: providerType);
    var savedModel = await _storage.getSelectedModel();
    final restIds =
        _modelRegistry.restCompatibleModelSpecs.map((s) => s.modelId).toSet();
    if (!restIds.contains(savedModel)) {
      savedModel = AiModelRegistry.modelGemini35FlashLite;
      await _storage.saveSelectedModel(savedModel);
    }
    final proxyUrl = await _storage.getCustomProxyUrl();

    _modelRegistry.setDefaultModel(savedModel);

    state = state.copyWith(
      providerType: providerType,
      hasApiKey: hasKey,
      maskedApiKey: maskedKey,
      clearMaskedApiKey: !hasKey,
      selectedModelId: savedModel,
      proxyUrl: proxyUrl,
    );
  }

  /// Changes the active AI provider (BYOK or Custom Proxy; Firebase AI Logic is locked until configured).
  Future<void> setProviderType(AiProviderType type) async {
    if (type == AiProviderType.firebaseAiLogic) {
      return;
    }
    await _storage.saveProviderType(type);
    final hasKey = await _storage.hasApiKey(provider: type);
    final maskedKey = await _storage.getMaskedApiKey(provider: type);
    state = state.copyWith(
      providerType: type,
      hasApiKey: hasKey,
      maskedApiKey: maskedKey,
      clearMaskedApiKey: !hasKey,
      clearConnectionResult: true,
    );
  }

  /// Selects a new default model from the central registry.
  Future<void> selectModel(String modelId) async {
    final restIds =
        _modelRegistry.restCompatibleModelSpecs.map((s) => s.modelId).toSet();
    if (!restIds.contains(modelId)) {
      return;
    }
    _modelRegistry.setDefaultModel(modelId);
    await _storage.saveSelectedModel(modelId);
    state = state.copyWith(selectedModelId: modelId);
  }

  /// Securely encrypts and saves a new API key via Android KeyStore for active provider.
  Future<void> saveApiKey(String key) async {
    state = state.copyWith(isSavingKey: true);
    try {
      await _storage.saveApiKey(key, provider: state.providerType);
      final hasKey = await _storage.hasApiKey(provider: state.providerType);
      final maskedKey = await _storage.getMaskedApiKey(provider: state.providerType);

      state = state.copyWith(
        hasApiKey: hasKey,
        maskedApiKey: maskedKey,
        clearMaskedApiKey: !hasKey,
        clearConnectionResult: true,
      );
    } finally {
      state = state.copyWith(isSavingKey: false);
    }
  }

  /// Deletes the stored API key completely from secure storage for active provider.
  Future<void> clearApiKey() async {
    await _storage.clearApiKey(provider: state.providerType);
    state = state.copyWith(
      hasApiKey: false,
      clearMaskedApiKey: true,
      clearConnectionResult: true,
    );
  }

  /// Saves a custom backend proxy URL.
  Future<void> saveCustomProxyUrl(String? url) async {
    await _storage.saveCustomProxyUrl(url);
    final normalized = (url == null || url.trim().isEmpty) ? null : url.trim();
    state = state.copyWith(
      proxyUrl: normalized,
      clearProxyUrl: normalized == null,
      clearConnectionResult: true,
    );
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
