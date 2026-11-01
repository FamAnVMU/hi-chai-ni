/// Model representing a proposed learning evidence event from the AI Tutor.
///
/// Policy: The AI PROPOSES evidence; the repository VALIDATES before writing.
/// - AI never directly writes to [learner_evidence] table.
/// - [LearningEvidenceValidator] checks confidence, event type, and content existence.
library;

/// Represents a teaching/learning event the AI Tutor believes occurred.
class LearningEvidenceProposal {
  /// ID of the vocabulary, grammar item, or session involved.
  final String contentId;

  /// What kind of content: 'vocabulary' | 'grammar' | 'dialogue'.
  final String contentType;

  /// The type of learning event:
  /// - 'taught': AI explicitly taught this item with explanation.
  /// - 'practiced': Learner actively used this item correctly.
  /// - 'recalled': Learner successfully recalled this item when prompted.
  /// - 'error': Learner made an error with this item.
  /// - 'mastered': RESERVED — AI must NOT propose this; computed algorithmically.
  final String eventType;

  /// AI's confidence score (0.0 – 1.0).
  /// Proposals with confidence < 0.3 are rejected by [LearningEvidenceValidator].
  final double confidence;

  /// Source identifier, should always be 'ai_tutor' for proposals from this system.
  final String source;

  /// Chat session this proposal belongs to.
  final String sessionId;

  /// Optional task context (e.g. "restaurant ordering exercise", "grammar drill").
  final String? taskContext;

  /// When this proposal was generated (UTC).
  final DateTime proposedAt;

  const LearningEvidenceProposal({
    required this.contentId,
    required this.contentType,
    required this.eventType,
    required this.confidence,
    required this.source,
    required this.sessionId,
    this.taskContext,
    required this.proposedAt,
  });

  factory LearningEvidenceProposal.fromMap(
    Map<String, dynamic> map, {
    required String sessionId,
  }) {
    return LearningEvidenceProposal(
      contentId: map['content_id'] as String? ?? '',
      contentType: map['content_type'] as String? ?? 'vocabulary',
      eventType: map['event_type'] as String? ?? 'taught',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      source: map['source'] as String? ?? 'ai_tutor',
      sessionId: sessionId,
      taskContext: map['task_context'] as String?,
      proposedAt: DateTime.tryParse(map['proposed_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'content_id': contentId,
      'content_type': contentType,
      'event_type': eventType,
      'confidence': confidence,
      'source': source,
      'session_id': sessionId,
      'task_context': taskContext,
      'proposed_at': proposedAt.toIso8601String(),
    };
  }
}

/// Result of validating a [LearningEvidenceProposal].
class EvidenceValidationResult {
  final bool isValid;
  final String? rejectionReason;

  const EvidenceValidationResult.valid() : isValid = true, rejectionReason = null;
  const EvidenceValidationResult.rejected(this.rejectionReason) : isValid = false;
}

/// Validates [LearningEvidenceProposal]s before any DB write.
///
/// Rules:
/// 1. Rejects if [confidence] < 0.3 (signal too weak).
/// 2. Rejects if [eventType] == 'mastered' (reserved for algorithmic computation).
/// 3. Rejects if [contentId] is empty.
/// 4. Rejects unknown [contentType] values.
class LearningEvidenceValidator {
  static const double _minConfidence = 0.3;
  static const _reservedEventTypes = {'mastered'};
  static const _validContentTypes = {'vocabulary', 'grammar', 'dialogue'};
  static const _validEventTypes = {'taught', 'practiced', 'recalled', 'error'};

  const LearningEvidenceValidator();

  /// Validates a proposal without checking DB (structural validation only).
  EvidenceValidationResult validate(LearningEvidenceProposal proposal) {
    if (proposal.contentId.trim().isEmpty) {
      return const EvidenceValidationResult.rejected('contentId must not be empty');
    }

    if (proposal.confidence < _minConfidence) {
      return EvidenceValidationResult.rejected(
        'confidence ${proposal.confidence} is below minimum threshold $_minConfidence',
      );
    }

    if (_reservedEventTypes.contains(proposal.eventType)) {
      return EvidenceValidationResult.rejected(
        'eventType "${proposal.eventType}" is reserved; AI must not propose it',
      );
    }

    if (!_validEventTypes.contains(proposal.eventType)) {
      return EvidenceValidationResult.rejected(
        'unknown eventType "${proposal.eventType}"',
      );
    }

    if (!_validContentTypes.contains(proposal.contentType)) {
      return EvidenceValidationResult.rejected(
        'unknown contentType "${proposal.contentType}"',
      );
    }

    return const EvidenceValidationResult.valid();
  }

  /// Filters a list of proposals, returning only valid ones.
  /// Logs rejected proposals with their reasons.
  List<LearningEvidenceProposal> filterValid(
    List<LearningEvidenceProposal> proposals, {
    void Function(LearningEvidenceProposal, String)? onRejected,
  }) {
    final valid = <LearningEvidenceProposal>[];
    for (final proposal in proposals) {
      final result = validate(proposal);
      if (result.isValid) {
        valid.add(proposal);
      } else {
        onRejected?.call(proposal, result.rejectionReason ?? 'unknown');
      }
    }
    return valid;
  }
}
