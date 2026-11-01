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

/// Central registry managing supported models and capability routing.
/// Verified against official Google Gemini API docs (Q1 2026).
class AiModelRegistry {
  /// Standard cost-effective, high-speed flash model recommended for new projects.
  static const String modelGemini35FlashLite = 'gemini-3.5-flash-lite';

  /// Premier production flash model for multimodal understanding and dialogue.
  static const String modelGemini38Flash = 'gemini-3.8-flash';

  /// Advanced reasoning model for pedagogical analysis and complex grammar breakdown.
  static const String modelGemini31ProPreview = 'gemini-3.1-pro-preview';

  final Map<AiTaskType, AiModelConfig> _taskRouteConfigs;

  AiModelRegistry({Map<AiTaskType, AiModelConfig>? customRoutes})
      : _taskRouteConfigs = customRoutes ??
            {
              AiTaskType.chatTutor: const AiModelConfig(
                modelId: modelGemini35FlashLite,
                temperature: 0.7,
                maxOutputTokens: 2048,
              ),
              AiTaskType.dictionaryExplanation: const AiModelConfig(
                modelId: modelGemini35FlashLite,
                temperature: 0.2, // Low temperature for deterministic, factual definitions
                maxOutputTokens: 1024,
              ),
              AiTaskType.grammarCorrection: const AiModelConfig(
                modelId: modelGemini38Flash,
                temperature: 0.3,
                maxOutputTokens: 1536,
              ),
              AiTaskType.pronunciationEvaluation: const AiModelConfig(
                modelId: modelGemini35FlashLite,
                temperature: 0.2,
                maxOutputTokens: 512,
              ),
              AiTaskType.readingComprehension: const AiModelConfig(
                modelId: modelGemini38Flash,
                temperature: 0.5,
                maxOutputTokens: 2048,
              ),
              AiTaskType.generalText: const AiModelConfig(
                modelId: modelGemini35FlashLite,
                temperature: 0.7,
                maxOutputTokens: 2048,
              ),
            };

  AiModelConfig getConfigForTask(AiTaskType task) {
    return _taskRouteConfigs[task] ??
        const AiModelConfig(
          modelId: modelGemini35FlashLite,
          temperature: 0.7,
          maxOutputTokens: 2048,
        );
  }

  void updateRoute(AiTaskType task, AiModelConfig config) {
    _taskRouteConfigs[task] = config;
  }

  List<String> get availableModels => [
        modelGemini35FlashLite,
        modelGemini38Flash,
        modelGemini31ProPreview,
      ];
}
