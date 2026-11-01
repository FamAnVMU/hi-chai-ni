import '../../../../core/network/ai/models/ai_request.dart';
import '../models/learner_context.dart';
import '../models/tutor_persona.dart';
import '../models/tutor_scenario.dart';
import '../prompts/tutor_system_prompt_builder.dart';

/// Context Builder for AI Tutor chat turns.
/// Assembles system prompts, persona settings, active recall SRS vocabulary,
/// and applies a bounded sliding window to SQLite chat history.
///
/// Accepts an optional pre-fetched [LearnerContext] from [LearnerContextService]
/// to inject confirmed vocabulary, recurring errors, and skill mastery into the prompt.
class TutorContextBuilder {
  final int maxHistoryTurns;

  const TutorContextBuilder({
    this.maxHistoryTurns = 10,
  });

  /// Builds a ready-to-dispatch [AiPromptRequest] from raw SQLite history and current turn.
  AiPromptRequest buildRequest({
    required String userInput,
    required List<Map<String, dynamic>> rawDbHistory,
    TutorPersona persona = TutorPersonas.qiaoqiao,
    TutorScenario scenario = TutorScenarios.freeChat,
    int learnerHskLevel = 1,
    String learnerName = 'Học viên',
    List<String> weakSrsWords = const [],
    String? customLearningGoal,

    /// Optional learner context pre-fetched by the repository.
    /// When provided, overrides [learnerHskLevel] and [learnerName] from profile
    /// and enriches the system prompt with pedagogical history.
    LearnerContext? learnerContext,
  }) {
    // 1. Build the pedagogical system prompt with anti-hypercorrection and anti-injection guardrails
    final systemPrompt = TutorSystemPromptBuilder.build(
      TutorPromptOptions(
        persona: persona,
        scenario: scenario,
        learnerHskLevel: learnerHskLevel,
        learnerName: learnerName,
        weakSrsWords: weakSrsWords,
        customLearningGoal: customLearningGoal,
        learnerContext: learnerContext,
      ),
    );

    // 2. Extract and prune historical messages using a sliding window
    final contents = <AiContent>[];

    // Take the most recent messages up to maxHistoryTurns
    final historyToInclude = rawDbHistory.length > maxHistoryTurns
        ? rawDbHistory.sublist(rawDbHistory.length - maxHistoryTurns)
        : rawDbHistory;

    for (final row in historyToInclude) {
      final role = row['role'] as String? ?? 'user';
      final content = row['content'] as String? ?? '';
      if (content.trim().isEmpty) continue;

      // Gemini roles: 'user' or 'model'
      final geminiRole = (role == 'assistant' || role == 'model') ? 'model' : 'user';

      contents.add(
        AiContent(
          role: geminiRole,
          parts: [AiPart.text(content)],
        ),
      );
    }

    // 3. Ensure historical turns are valid (Gemini requires first content to be 'user')
    while (contents.isNotEmpty && contents.first.role != 'user') {
      contents.removeAt(0);
    }

    // 4. Append current user input turn
    contents.add(
      AiContent(
        role: 'user',
        parts: [AiPart.text(userInput.trim())],
      ),
    );

    return AiPromptRequest(
      systemInstruction: systemPrompt,
      contents: contents,
      taskId: 'ai_tutor_chat',
      temperature: 0.7,
      maxOutputTokens: 2048,
    );
  }
}
