import 'learning_evidence_proposal.dart';
import 'tutor_correction.dart';

/// Full structured AI Tutor response turn.
class TutorResponse {
  /// The conversational reply in Simplified Chinese.
  final String replyZh;

  /// Pinyin for the Chinese reply with tone marks.
  final String replyPinyin;

  /// Vietnamese translation of the reply.
  final String replyVi;

  /// Evaluation of the user's preceding turn (null if this is an opening turn).
  final TutorEvaluation? evaluation;

  /// 2 to 3 suggested student replies to keep the conversation flowing smoothly.
  final List<String> followUpSuggestions;

  /// Target vocabulary words introduced or reinforced in this turn.
  final List<String> targetVocabulary;

  /// Evidence proposals from the AI (must be validated before writing to DB).
  final List<LearningEvidenceProposal> evidenceProposals;

  /// Token usage metadata if available.
  final int tokensUsed;

  const TutorResponse({
    required this.replyZh,
    required this.replyPinyin,
    required this.replyVi,
    this.evaluation,
    this.followUpSuggestions = const [],
    this.targetVocabulary = const [],
    this.evidenceProposals = const [],
    this.tokensUsed = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'reply_zh': replyZh,
      'reply_pinyin': replyPinyin,
      'reply_vi': replyVi,
      'evaluation': evaluation?.toMap(),
      'follow_up_suggestions': followUpSuggestions,
      'target_vocabulary': targetVocabulary,
      'evidence_proposals': evidenceProposals.map((e) => e.toMap()).toList(),
      'tokens_used': tokensUsed,
    };
  }

  factory TutorResponse.fromMap(Map<String, dynamic> map) {
    return TutorResponse(
      replyZh: map['reply_zh'] as String? ?? '',
      replyPinyin: map['reply_pinyin'] as String? ?? '',
      replyVi: map['reply_vi'] as String? ?? '',
      evaluation: map['evaluation'] != null
          ? TutorEvaluation.fromMap(map['evaluation'] as Map<String, dynamic>)
          : null,
      followUpSuggestions: (map['follow_up_suggestions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      targetVocabulary: (map['target_vocabulary'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      evidenceProposals: (map['evidence_proposals'] as List<dynamic>?)
              ?.whereType<Map<String, dynamic>>()
              .map((m) => LearningEvidenceProposal.fromMap(
                    m,
                    sessionId: map['session_id'] as String? ?? '',
                  ))
              .toList() ??
          const [],
      tokensUsed: (map['tokens_used'] as num?)?.toInt() ?? 0,
    );
  }
}
