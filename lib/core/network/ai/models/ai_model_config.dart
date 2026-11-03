/// Supported AI provider backends for HI Chinese.
enum AiProviderType {
  /// Direct Google AI Studio REST API using user-provided API key (BYOK).
  geminiRest,

  /// Firebase AI Logic using Firebase App Check and Vertex AI / Gemini backend.
  firebaseAiLogic,

  /// Custom self-hosted enterprise or reverse proxy backend.
  customProxy,
}

/// Explicit model capabilities.
///
/// Design Principle: Capabilities are NEVER inferred from model name strings;
/// they must be explicitly declared and verified per model spec.
class AiModelCapability {
  final bool supportsText;
  final bool supportsStreaming;
  final bool supportsAudioInput;
  final bool supportsTts;
  final bool supportsLiveApi;
  final bool supportsVision;

  const AiModelCapability({
    this.supportsText = true,
    this.supportsStreaming = true,
    this.supportsAudioInput = false,
    this.supportsTts = false,
    this.supportsLiveApi = false,
    this.supportsVision = false,
  });

  Map<String, bool> toMap() {
    return {
      'supports_text': supportsText,
      'supports_streaming': supportsStreaming,
      'supports_audio_input': supportsAudioInput,
      'supports_tts': supportsTts,
      'supports_live_api': supportsLiveApi,
      'supports_vision': supportsVision,
    };
  }
}

/// Full specification and metadata for an AI model available in HI Chinese.
class AiModelSpec {
  final String modelId;
  final String displayName;
  final String description;
  final AiModelCapability capabilities;
  final String recommendedFor;
  final bool isDefault;

  const AiModelSpec({
    required this.modelId,
    required this.displayName,
    required this.description,
    required this.capabilities,
    required this.recommendedFor,
    this.isDefault = false,
  });
}

/// Task categories for AI generation across HI Chinese features.
enum AiTaskType {
  chatTutor,
  dictionaryExplanation,
  grammarCorrection,
  pronunciationEvaluation,
  readingComprehension,
  generalText,
}

/// Central configuration for a model generation profile.
class AiModelConfig {
  final String modelId;
  final double temperature;
  final double topP;
  final int maxOutputTokens;
  final bool supportsStreaming;
  final bool supportsMultimodal;

  const AiModelConfig({
    required this.modelId,
    this.temperature = 0.7,
    this.topP = 0.95,
    this.maxOutputTokens = 2048,
    this.supportsStreaming = true,
    this.supportsMultimodal = true,
  });

  AiModelConfig copyWith({
    String? modelId,
    double? temperature,
    double? topP,
    int? maxOutputTokens,
    bool? supportsStreaming,
    bool? supportsMultimodal,
  }) {
    return AiModelConfig(
      modelId: modelId ?? this.modelId,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      supportsStreaming: supportsStreaming ?? this.supportsStreaming,
      supportsMultimodal: supportsMultimodal ?? this.supportsMultimodal,
    );
  }
}

/// Central registry managing supported models, capability verification, and task routing.
///
/// Design:
/// - Single source of truth for all Model IDs.
/// - Never hard-code model IDs in individual features.
/// - Allows changing active model without modifying UI code in multiple places.
/// - Verifies capabilities via [AiModelCapability] struct, never by regex matching names.
class AiModelRegistry {
  /// Official Gemini 3.5 Flash-Lite: Ultra-fast, cost-effective multimodal chat & tutor.
  static const String modelGemini35FlashLite = 'gemini-3.5-flash-lite';

  /// Official Gemini 3.8 Flash (GA): Premier production multimodal model for grammar & reading.
  static const String modelGemini38Flash = 'gemini-3.8-flash';

  /// Official Gemini 3.1 Pro Preview: Deep reasoning for linguistics and syntax analysis.
  static const String modelGemini31ProPreview = 'gemini-3.1-pro-preview';

  /// Official Gemini 3.8 Live: Real-time bidirectional audio streaming & live voice dialogue.
  static const String modelGemini38Live = 'gemini-3.8-live';

  /// Stable fallback generation (Gemini 2.5 series)
  static const String modelGemini25Flash = 'gemini-2.5-flash';
  static const String modelGemini25FlashLite = 'gemini-2.5-flash-lite';
  static const String modelGemini25Pro = 'gemini-2.5-pro';

  /// Master catalog of supported models with explicit capabilities.
  static final Map<String, AiModelSpec> _catalog = {
    modelGemini35FlashLite: const AiModelSpec(
      modelId: modelGemini35FlashLite,
      displayName: 'Gemini 3.5 Flash Lite',
      description: 'Mô hình siêu nhanh, tối ưu hóa chi phí và độ trễ cho gia sư AI di động.',
      capabilities: AiModelCapability(
        supportsText: true,
        supportsStreaming: true,
        supportsAudioInput: true,
        supportsTts: false,
        supportsLiveApi: false,
        supportsVision: true,
      ),
      recommendedFor: 'Gia sư đàm thoại, tra cứu từ điển nhanh, giải thích từ ngữ.',
      isDefault: true,
    ),
    modelGemini38Flash: const AiModelSpec(
      modelId: modelGemini38Flash,
      displayName: 'Gemini 3.8 Flash',
      description: 'Mô hình đa phương thức thế hệ mới cân bằng hoàn hảo giữa tốc độ và tư duy.',
      capabilities: AiModelCapability(
        supportsText: true,
        supportsStreaming: true,
        supportsAudioInput: true,
        supportsTts: false,
        supportsLiveApi: false,
        supportsVision: true,
      ),
      recommendedFor: 'Phân tích ngữ pháp nâng cao, đọc hiểu đoạn văn, sửa lỗi câu phức tạp.',
      isDefault: false,
    ),
    modelGemini31ProPreview: const AiModelSpec(
      modelId: modelGemini31ProPreview,
      displayName: 'Gemini 3.1 Pro Preview',
      description: 'Mô hình tư duy chuyên sâu cho các bài phân tích ngôn ngữ học và dịch thuật chuyên biệt.',
      capabilities: AiModelCapability(
        supportsText: true,
        supportsStreaming: true,
        supportsAudioInput: false,
        supportsTts: false,
        supportsLiveApi: false,
        supportsVision: true,
      ),
      recommendedFor: 'Phân tích chuyên sâu cấu trúc ngữ pháp cổ ngữ/thành ngữ.',
      isDefault: false,
    ),
    modelGemini38Live: const AiModelSpec(
      modelId: modelGemini38Live,
      displayName: 'Gemini 3.8 Live (Audio/Voice)',
      description: 'Mô hình giao tiếp giọng nói thời gian thực hai chiều (Bidirectional Audio Streaming).',
      capabilities: AiModelCapability(
        supportsText: true,
        supportsStreaming: true,
        supportsAudioInput: true,
        supportsTts: true,
        supportsLiveApi: true,
        supportsVision: false,
      ),
      recommendedFor: 'Luyện nói phản xạ song ngữ thời gian thực (Live Voice Chat).',
      isDefault: false,
    ),
    modelGemini25Flash: const AiModelSpec(
      modelId: modelGemini25Flash,
      displayName: 'Gemini 2.5 Flash',
      description: 'Mô hình dự phòng ổn định thế hệ 2.5 cho đa phương thức.',
      capabilities: AiModelCapability(
        supportsText: true,
        supportsStreaming: true,
        supportsAudioInput: true,
        supportsTts: false,
        supportsLiveApi: false,
        supportsVision: true,
      ),
      recommendedFor: 'Dự phòng ổn định cho phân tích ngữ pháp và đoạn văn.',
      isDefault: false,
    ),
    modelGemini25FlashLite: const AiModelSpec(
      modelId: modelGemini25FlashLite,
      displayName: 'Gemini 2.5 Flash Lite',
      description: 'Mô hình dự phòng siêu nhanh thế hệ 2.5.',
      capabilities: AiModelCapability(
        supportsText: true,
        supportsStreaming: true,
        supportsAudioInput: true,
        supportsTts: false,
        supportsLiveApi: false,
        supportsVision: true,
      ),
      recommendedFor: 'Dự phòng tác vụ tra cứu nhanh và gia sư nhẹ.',
      isDefault: false,
    ),
    modelGemini25Pro: const AiModelSpec(
      modelId: modelGemini25Pro,
      displayName: 'Gemini 2.5 Pro',
      description: 'Mô hình tư duy chuyên sâu dự phòng thế hệ 2.5.',
      capabilities: AiModelCapability(
        supportsText: true,
        supportsStreaming: true,
        supportsAudioInput: false,
        supportsTts: false,
        supportsLiveApi: false,
        supportsVision: true,
      ),
      recommendedFor: 'Dự phòng phân tích ngôn ngữ học nâng cao.',
      isDefault: false,
    ),
  };

  final Map<AiTaskType, AiModelConfig> _taskRouteConfigs;
  String _activeDefaultModelId;

  AiModelRegistry({
    Map<AiTaskType, AiModelConfig>? customRoutes,
    String? defaultModelId,
  })  : _activeDefaultModelId = defaultModelId ?? modelGemini25Flash,
        _taskRouteConfigs = customRoutes ??
            {
              AiTaskType.chatTutor: const AiModelConfig(
                modelId: modelGemini25FlashLite,
                temperature: 0.7,
                maxOutputTokens: 2048,
              ),
              AiTaskType.dictionaryExplanation: const AiModelConfig(
                modelId: modelGemini25FlashLite,
                temperature: 0.2, // Low temperature for deterministic definitions
                maxOutputTokens: 1024,
              ),
              AiTaskType.grammarCorrection: const AiModelConfig(
                modelId: modelGemini25Flash,
                temperature: 0.3,
                maxOutputTokens: 1536,
              ),
              AiTaskType.pronunciationEvaluation: const AiModelConfig(
                modelId: modelGemini25FlashLite,
                temperature: 0.2,
                maxOutputTokens: 512,
              ),
              AiTaskType.readingComprehension: const AiModelConfig(
                modelId: modelGemini25Flash,
                temperature: 0.5,
                maxOutputTokens: 2048,
              ),
              AiTaskType.generalText: const AiModelConfig(
                modelId: modelGemini25Flash,
                temperature: 0.7,
                maxOutputTokens: 2048,
              ),
            };

  /// The active default model ID configured by the user in Settings.
  String get activeDefaultModelId => _activeDefaultModelId;

  /// Sets the active default model and updates general/chat routes accordingly.
  void setDefaultModel(String modelId) {
    if (_catalog.containsKey(modelId)) {
      _activeDefaultModelId = modelId;
      _taskRouteConfigs[AiTaskType.chatTutor] =
          _taskRouteConfigs[AiTaskType.chatTutor]!.copyWith(modelId: modelId);
      _taskRouteConfigs[AiTaskType.generalText] =
          _taskRouteConfigs[AiTaskType.generalText]!.copyWith(modelId: modelId);
    }
  }

  /// List of all supported model specifications.
  List<AiModelSpec> get availableModelSpecs => _catalog.values.toList();

  /// List of all available model ID strings.
  List<String> get availableModels => _catalog.keys.toList();

  /// Retrieves spec for a given model ID.
  AiModelSpec? getModelSpec(String modelId) => _catalog[modelId];

  /// Explicitly verifies whether a model supports a required capability.
  ///
  /// NEVER relies on string guessing or sub-string heuristics.
  bool hasCapability(
    String modelId, {
    bool requiresText = false,
    bool requiresStreaming = false,
    bool requiresAudioInput = false,
    bool requiresTts = false,
    bool requiresLiveApi = false,
    bool requiresVision = false,
  }) {
    final spec = _catalog[modelId];
    if (spec == null) return false;

    final caps = spec.capabilities;
    if (requiresText && !caps.supportsText) return false;
    if (requiresStreaming && !caps.supportsStreaming) return false;
    if (requiresAudioInput && !caps.supportsAudioInput) return false;
    if (requiresTts && !caps.supportsTts) return false;
    if (requiresLiveApi && !caps.supportsLiveApi) return false;
    if (requiresVision && !caps.supportsVision) return false;

    return true;
  }

  /// Returns configuration for a specific learning task.
  AiModelConfig getConfigForTask(AiTaskType task) {
    return _taskRouteConfigs[task] ??
        AiModelConfig(
          modelId: _activeDefaultModelId,
          temperature: 0.7,
          maxOutputTokens: 2048,
        );
  }

  /// Updates the configuration profile for a specific task.
  void updateRoute(AiTaskType task, AiModelConfig config) {
    _taskRouteConfigs[task] = config;
  }
}
