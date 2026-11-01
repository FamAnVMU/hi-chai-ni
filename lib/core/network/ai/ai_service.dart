import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'interfaces/ai_provider.dart';
import 'models/ai_model_config.dart';
import 'models/ai_request.dart';
import 'models/ai_response.dart';
import 'models/cancel_token.dart';
import 'models/connection_test_result.dart';
import 'providers/gemini_rest_ai_provider.dart';
import 'security/ai_credential_storage.dart';

/// Central AI service orchestrating model routing, credential verification,
/// text generation, and incremental streaming.
class AiService {
  final AiProvider provider;
  final AiModelRegistry modelRegistry;
  final AiCredentialStorage credentialStorage;

  AiService({
    required this.provider,
    required this.credentialStorage,
    AiModelRegistry? modelRegistry,
  }) : modelRegistry = modelRegistry ?? AiModelRegistry();


  /// Single-turn text generation with task-specific model routing.
  Future<AiTextResponse> generateText(
    AiPromptRequest request, {
    AiTaskType taskType = AiTaskType.generalText,
    Duration timeout = const Duration(seconds: 30),
    CancelToken? cancelToken,
  }) async {
    final taskConfig = modelRegistry.getConfigForTask(taskType);
    return await provider.generateText(
      request,
      config: taskConfig,
      timeout: timeout,
      cancelToken: cancelToken,
    );
  }

  /// Incremental token streaming with task-specific model routing.
  Stream<AiStreamChunk> streamText(
    AiPromptRequest request, {
    AiTaskType taskType = AiTaskType.generalText,
    Duration timeout = const Duration(seconds: 45),
    CancelToken? cancelToken,
  }) {
    final taskConfig = modelRegistry.getConfigForTask(taskType);
    return provider.streamText(
      request,
      config: taskConfig,
      timeout: timeout,
      cancelToken: cancelToken,
    );
  }

  /// Verifies whether the current API key is valid.
  Future<bool> verifyCredentials() async {
    return await provider.verifyCredentials();
  }

  /// Performs a live connection test to verify provider availability, latency, and credentials.
  Future<ConnectionTestResult> testConnection({String? modelId}) async {
    final effectiveModel = modelId ?? modelRegistry.activeDefaultModelId;
    return await provider.testConnection(modelId: effectiveModel);
  }

  /// Disposes underlying provider resources and client connections.
  void dispose() {
    provider.dispose();
  }
}

// ==================== RIVERPOD PROVIDERS ====================

final aiCredentialStorageProvider = Provider<AiCredentialStorage>((ref) {
  return AiCredentialStorage();
});

final aiModelRegistryProvider = Provider<AiModelRegistry>((ref) {
  return AiModelRegistry();
});

final aiProviderInstanceProvider = Provider<AiProvider>((ref) {
  final storage = ref.watch(aiCredentialStorageProvider);
  return GeminiRestAiProvider(credentialStorage: storage);
});

final aiServiceProvider = Provider<AiService>((ref) {
  final provider = ref.watch(aiProviderInstanceProvider);
  final registry = ref.watch(aiModelRegistryProvider);
  final storage = ref.watch(aiCredentialStorageProvider);

  return AiService(
    provider: provider,
    modelRegistry: registry,
    credentialStorage: storage,
  );
});
