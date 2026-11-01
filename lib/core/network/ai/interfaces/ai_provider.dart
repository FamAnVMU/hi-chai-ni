import '../models/ai_model_config.dart';
import '../models/ai_request.dart';
import '../models/ai_response.dart';
import '../models/cancel_token.dart';
import '../models/connection_test_result.dart';

/// Provider-independent contract for text generation, streaming, and connection diagnostics.
/// Shields presentation and domain features from concrete SDKs (REST, Firebase, Genkit).
abstract class AiProvider {
  /// Name of the provider (e.g. 'gemini_rest', 'mock', 'firebase_ai').
  String get providerName;

  /// Single-turn or aggregated text generation.
  Future<AiTextResponse> generateText(
    AiPromptRequest request, {
    AiModelConfig? config,
    Duration timeout = const Duration(seconds: 30),
    CancelToken? cancelToken,
  });

  /// Incremental token streaming via Server-Sent Events or WebSocket.
  Stream<AiStreamChunk> streamText(
    AiPromptRequest request, {
    AiModelConfig? config,
    Duration timeout = const Duration(seconds: 45),
    CancelToken? cancelToken,
  });

  /// Verifies current API key / credentials reachability without charging excessive tokens.
  Future<bool> verifyCredentials();

  /// Performs a live connection test round-trip with real latency measurement and error categorization.
  Future<ConnectionTestResult> testConnection({String? modelId});
}
