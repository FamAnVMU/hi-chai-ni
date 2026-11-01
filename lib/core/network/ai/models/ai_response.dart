/// Token consumption metadata returned by the provider.
class AiUsageMetadata {
  final int promptTokenCount;
  final int candidatesTokenCount;
  final int totalTokenCount;

  const AiUsageMetadata({
    this.promptTokenCount = 0,
    this.candidatesTokenCount = 0,
    this.totalTokenCount = 0,
  });

  factory AiUsageMetadata.fromJson(Map<String, dynamic> json) {
    return AiUsageMetadata(
      promptTokenCount: (json['promptTokenCount'] as num?)?.toInt() ?? 0,
      candidatesTokenCount: (json['candidatesTokenCount'] as num?)?.toInt() ?? 0,
      totalTokenCount: (json['totalTokenCount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'promptTokenCount': promptTokenCount,
        'candidatesTokenCount': candidatesTokenCount,
        'totalTokenCount': totalTokenCount,
      };

  @override
  String toString() =>
      'AiUsageMetadata(prompt: $promptTokenCount, candidates: $candidatesTokenCount, total: $totalTokenCount)';
}

/// A single incremental chunk in an active streaming response.
class AiStreamChunk {
  final int index;
  final String text;
  final String? finishReason;
  final AiUsageMetadata? usageMetadata;

  const AiStreamChunk({
    required this.index,
    required this.text,
    this.finishReason,
    this.usageMetadata,
  });

  bool get isDone => finishReason != null && finishReason!.isNotEmpty;

  @override
  String toString() => 'AiStreamChunk(#$index, textLen: ${text.length}, finishReason: $finishReason)';
}

/// A complete, aggregated text generation response.
class AiTextResponse {
  final String text;
  final String? finishReason;
  final AiUsageMetadata? usageMetadata;
  final int latencyMs;
  final String modelUsed;

  const AiTextResponse({
    required this.text,
    this.finishReason,
    this.usageMetadata,
    required this.latencyMs,
    required this.modelUsed,
  });

  @override
  String toString() =>
      'AiTextResponse(model: $modelUsed, latency: ${latencyMs}ms, tokens: ${usageMetadata?.totalTokenCount ?? 0}, textLen: ${text.length})';
}
