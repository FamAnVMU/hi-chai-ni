import 'dart:convert';

/// Seven discrete pedagogical activity types reflecting the learner's cognitive engagement.
enum ActivityType {
  /// Mere visual/auditory exposure (e.g. read in dialogue, saw in warmup).
  exposure('exposure'),

  /// Explicit direct instruction (e.g. studied dedicated vocab/grammar card).
  instruction('instruction'),

  /// Passive recognition (e.g. multiple choice, matching pairs).
  recognition('recognition'),

  /// Active cued recall from memory (e.g. flashcard front->back, character writing).
  recall('recall'),

  /// Functional application (e.g. fill-in-the-blank, sentence reconstruction, translation).
  application('application'),

  /// Spaced retention proven over an interval (e.g. successful SM-2 SRS review).
  retention('retention'),

  /// Generic review interaction.
  review('review');

  final String value;
  const ActivityType(this.value);

  static ActivityType fromString(String val) {
    for (final type in ActivityType.values) {
      if (type.value == val.toLowerCase()) return type;
    }
    return ActivityType.exposure;
  }
}

/// Immutable record of a discrete, verifiable learning event.
/// Saved in an append-only log in the SQLite `learner_evidence` table.
class LearningEvidence {
  final String id;
  final String profileId;
  final String? srsItemId;
  final String contentId;
  final String contentType;
  final ActivityType activityType;
  final String sourceModule;
  final double score;
  final bool isSuccess;
  final int durationMs;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  const LearningEvidence({
    required this.id,
    this.profileId = 'default_profile',
    this.srsItemId,
    required this.contentId,
    required this.contentType,
    required this.activityType,
    required this.sourceModule,
    required this.score,
    required this.isSuccess,
    this.durationMs = 0,
    this.metadata = const {},
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    final meta = Map<String, dynamic>.from(metadata);
    meta['activity_type'] = activityType.value;
    meta['is_success'] = isSuccess;
    meta['profile_id'] = profileId;

    return {
      'id': id,
      'srs_item_id': srsItemId,
      'content_id': contentId,
      'content_type': contentType,
      'source': sourceModule,
      'score': score,
      'duration_ms': durationMs,
      'metadata_json': json.encode(meta),
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  factory LearningEvidence.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> meta = {};
    if (map['metadata_json'] != null) {
      try {
        meta = json.decode(map['metadata_json'] as String) as Map<String, dynamic>;
      } catch (_) {}
    }

    final actStr = meta['activity_type'] as String? ?? 'exposure';
    final isSuccess = meta['is_success'] as bool? ?? ((map['score'] as num?)?.toDouble() ?? 0.0) >= 0.7;
    final profileId = meta['profile_id'] as String? ?? 'default_profile';

    return LearningEvidence(
      id: map['id'] as String,
      profileId: profileId,
      srsItemId: map['srs_item_id'] as String?,
      contentId: map['content_id'] as String,
      contentType: map['content_type'] as String? ?? 'vocabulary',
      activityType: ActivityType.fromString(actStr),
      sourceModule: map['source'] as String? ?? 'system',
      score: (map['score'] as num?)?.toDouble() ?? 0.0,
      isSuccess: isSuccess,
      durationMs: (map['duration_ms'] as num?)?.toInt() ?? 0,
      metadata: meta,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
