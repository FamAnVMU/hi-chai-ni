import 'dart:convert';

/// Domain entity representing a normalized, canonically registered knowledge unit.
class KnowledgeRegistryItem {
  final String id;
  final String entityType; // vocabulary, vocabulary_sense, grammar, character, pinyin, reading, concept
  final String canonicalId;
  final int hskLevel;
  final String title;
  final bool isDeprecated;
  final String? replacedById;
  final String? packageId;
  final Map<String, dynamic> metadata;
  final String createdAt;
  final String updatedAt;

  const KnowledgeRegistryItem({
    required this.id,
    required this.entityType,
    required this.canonicalId,
    required this.hskLevel,
    required this.title,
    this.isDeprecated = false,
    this.replacedById,
    this.packageId,
    this.metadata = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  factory KnowledgeRegistryItem.fromMap(Map<String, dynamic> map) {
    Map<String, dynamic> meta = {};
    if (map['metadata_json'] is String && (map['metadata_json'] as String).isNotEmpty) {
      try {
        meta = json.decode(map['metadata_json'] as String) as Map<String, dynamic>;
      } catch (_) {}
    }
    return KnowledgeRegistryItem(
      id: map['id'] as String,
      entityType: map['entity_type'] as String,
      canonicalId: map['canonical_id'] as String,
      hskLevel: (map['hsk_level'] as num?)?.toInt() ?? 1,
      title: map['title'] as String? ?? '',
      isDeprecated: map['is_deprecated'] == 1 || map['is_deprecated'] == true,
      replacedById: map['replaced_by_id'] as String?,
      packageId: map['package_id'] as String?,
      metadata: meta,
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'entity_type': entityType,
      'canonical_id': canonicalId,
      'hsk_level': hskLevel,
      'title': title,
      'is_deprecated': isDeprecated ? 1 : 0,
      'replaced_by_id': replacedById,
      'package_id': packageId,
      'metadata_json': json.encode(metadata),
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

/// Relational link between a curriculum lesson and a registered knowledge item.
class LessonKnowledgeItem {
  final String id;
  final String lessonId;
  final String knowledgeItemId;
  final String role; // primary, instruction, supporting, review, warmup
  final int sequenceOrder;
  final bool isMandatory;
  final String createdAt;

  const LessonKnowledgeItem({
    required this.id,
    required this.lessonId,
    required this.knowledgeItemId,
    this.role = 'instruction',
    this.sequenceOrder = 1,
    this.isMandatory = true,
    required this.createdAt,
  });

  factory LessonKnowledgeItem.fromMap(Map<String, dynamic> map) {
    return LessonKnowledgeItem(
      id: map['id'] as String,
      lessonId: map['lesson_id'] as String,
      knowledgeItemId: map['knowledge_item_id'] as String,
      role: map['role'] as String? ?? 'instruction',
      sequenceOrder: (map['sequence_order'] as num?)?.toInt() ?? 1,
      isMandatory: map['is_mandatory'] == 1 || map['is_mandatory'] == true,
      createdAt: map['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'lesson_id': lessonId,
      'knowledge_item_id': knowledgeItemId,
      'role': role,
      'sequence_order': sequenceOrder,
      'is_mandatory': isMandatory ? 1 : 0,
      'created_at': createdAt,
    };
  }
}

/// Content ID mapping entry to safely preserve learner history across refactors and splits.
class ContentIdMapping {
  final String id;
  final String oldId;
  final String newId;
  final String mappingType; // replaced_by, merged_into, split_into
  final String? packageId;
  final String? notes;
  final String createdAt;

  const ContentIdMapping({
    required this.id,
    required this.oldId,
    required this.newId,
    required this.mappingType,
    this.packageId,
    this.notes,
    required this.createdAt,
  });

  factory ContentIdMapping.fromMap(Map<String, dynamic> map) {
    return ContentIdMapping(
      id: map['id'] as String,
      oldId: map['old_id'] as String,
      newId: map['new_id'] as String,
      mappingType: map['mapping_type'] as String? ?? 'replaced_by',
      packageId: map['package_id'] as String?,
      notes: map['notes'] as String?,
      createdAt: map['created_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'old_id': oldId,
      'new_id': newId,
      'mapping_type': mappingType,
      'package_id': packageId,
      'notes': notes,
      'created_at': createdAt,
    };
  }
}
