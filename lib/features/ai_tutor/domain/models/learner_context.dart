/// Models representing the assembled learner context passed to the AI Tutor.
///
/// Design principles:
/// - [LearnerContext] is read-only: assembled from SQLite, never written back.
/// - [ConfirmedVocabulary]: only words with real evidence of being taught/practiced.
///   Words merely mentioned by the AI do NOT qualify.
/// - [RecurringError]: patterns that appeared ≥ 2 times in learner evidence.
/// - Budget fields allow the context builder to prune before exceeding token limits.
library;

import 'tutor_correction.dart';

/// Learner profile metadata (non-sensitive, from app settings / profile table).
class LearnerProfile {
  final int hskLevel;
  final String learnerName;
  final String? customGoal;
  final DateTime? registeredAt;
  final String learningPathType; // 'comprehensive' | 'focused'
  final String? focusSkill; // e.g. 'reading', 'speaking', 'listening', 'writing'
  final bool hasCompletedLessons;

  const LearnerProfile({
    this.hskLevel = 1,
    this.learnerName = 'Học viên',
    this.customGoal,
    this.registeredAt,
    this.learningPathType = 'comprehensive',
    this.focusSkill,
    this.hasCompletedLessons = false,
  });
}

/// A vocabulary item confirmed as having been explicitly taught or practiced.
///
/// A word is "confirmed" only when [LearnerContextService] finds learner_evidence
/// with source != 'ai_tutor_mention' and score >= 0.5.
class ConfirmedVocabulary {
  final String vocabId;
  final String simplified;
  final String? pinyin;
  final String? meaningVi;
  final int hskLevel;
  final int evidenceCount;
  final DateTime? lastEvidenceAt;

  const ConfirmedVocabulary({
    required this.vocabId,
    required this.simplified,
    this.pinyin,
    this.meaningVi,
    this.hskLevel = 1,
    this.evidenceCount = 1,
    this.lastEvidenceAt,
  });
}

/// A recurring error pattern observed across multiple AI tutor dialogue evaluations.
class RecurringError {
  final TutorErrorCategory errorCategory;
  final List<String> examples; // Max 3 example phrases shown in context
  final int occurrenceCount;
  final DateTime? lastOccurredAt;

  const RecurringError({
    required this.errorCategory,
    required this.examples,
    required this.occurrenceCount,
    this.lastOccurredAt,
  });
}

/// Mastery score for a skill dimension (listening, speaking, reading, writing).
class MasterySkillSnapshot {
  final String skill; // 'listening' | 'reading' | 'speaking' | 'writing'
  final double masteryScore; // 0.0 – 1.0
  final DateTime? lastUpdated;

  const MasterySkillSnapshot({
    required this.skill,
    required this.masteryScore,
    this.lastUpdated,
  });
}

/// A compact summary of a single learner evidence entry.
class RecentEvidenceEntry {
  final String contentId;
  final String contentType;
  final String source;
  final double score;
  final String? eventType;
  final DateTime createdAt;

  const RecentEvidenceEntry({
    required this.contentId,
    required this.contentType,
    required this.source,
    required this.score,
    this.eventType,
    required this.createdAt,
  });
}

/// The fully assembled learner context ready to be injected into a system prompt.
///
/// Populated by [LearnerContextService]; consumed by [TutorSystemPromptBuilder].
class LearnerContext {
  /// Basic profile info for the learner.
  final LearnerProfile profile;

  /// Vocabulary words confirmed as taught/practiced (max [maxVocab] by relevance).
  /// NEVER contains words only mentioned by the AI without explicit teaching.
  final List<ConfirmedVocabulary> confirmedVocabulary;

  /// Recurring error patterns (min 2 occurrences, max [maxErrors]).
  final List<RecurringError> recurringErrors;

  /// Latest mastery scores per skill dimension.
  final Map<String, double> masteryBySkill;

  /// Most recent learner evidence entries for context continuity.
  final List<RecentEvidenceEntry> recentEvidenceSummary;

  /// Optional short summary of the most recent chat session.
  final String? recentChatSummary;

  /// Estimated token cost of this context block (rough: 4 chars ≈ 1 token).
  final int contextBudgetUsed;

  /// Warning flags for conflicting or unreliable data.
  /// E.g. "vocab '你好' appears in both confirmed and recurring errors — check evidence".
  final List<String> warningFlags;

  const LearnerContext({
    required this.profile,
    this.confirmedVocabulary = const [],
    this.recurringErrors = const [],
    this.masteryBySkill = const {},
    this.recentEvidenceSummary = const [],
    this.recentChatSummary,
    this.contextBudgetUsed = 0,
    this.warningFlags = const [],
  });

  /// Returns a safe empty context for new learners or when DB is unavailable.
  factory LearnerContext.empty({
    int hskLevel = 1,
    String learnerName = 'Học viên',
    String learningPathType = 'comprehensive',
    String? focusSkill,
    bool hasCompletedLessons = false,
  }) {
    return LearnerContext(
      profile: LearnerProfile(
        hskLevel: hskLevel,
        learnerName: learnerName,
        learningPathType: learningPathType,
        focusSkill: focusSkill,
        hasCompletedLessons: hasCompletedLessons,
      ),
    );
  }

  bool get hasConfirmedVocabulary => confirmedVocabulary.isNotEmpty;
  bool get hasRecurringErrors => recurringErrors.isNotEmpty;
  bool get hasMasteryData => masteryBySkill.isNotEmpty;
  bool get hasWarnings => warningFlags.isNotEmpty;
}
