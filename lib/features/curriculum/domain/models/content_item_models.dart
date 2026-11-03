import 'dart:convert';

class ContentItem {
  final String id;
  final String contentId;
  final String curriculumId;
  final int hskLevel;
  final String knowledgeType;
  final String title;
  final String contentJson;
  final List<String> objectives;
  final String? sourceReference;
  final String auditStatus;
  final String contentVersion;
  final Map<String, dynamic> metadata;

  const ContentItem({
    required this.id,
    required this.contentId,
    required this.curriculumId,
    required this.hskLevel,
    required this.knowledgeType,
    required this.title,
    required this.contentJson,
    this.objectives = const [],
    this.sourceReference,
    this.auditStatus = 'verified',
    this.contentVersion = '1.0.0',
    this.metadata = const {},
  });

  factory ContentItem.fromMap(Map<String, dynamic> map) {
    List<String> objs = [];
    if (map['objectives_json'] is String && (map['objectives_json'] as String).isNotEmpty) {
      final raw = map['objectives_json'] as String;
      try {
        final decoded = json.decode(raw);
        if (decoded is List) {
          objs = decoded.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
        }
      } catch (_) {
        objs = raw
            .replaceAll('[', '')
            .replaceAll(']', '')
            .replaceAll('"', '')
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    }

    return ContentItem(
      id: map['id'] as String,
      contentId: map['content_id'] as String,
      curriculumId: map['curriculum_id'] as String,
      hskLevel: (map['hsk_level'] as num).toInt(),
      knowledgeType: map['knowledge_type'] as String,
      title: map['title'] as String,
      contentJson: map['content_json'] as String,
      objectives: objs,
      sourceReference: map['source_reference'] as String?,
      auditStatus: map['audit_status'] as String? ?? 'verified',
      contentVersion: map['content_version'] as String? ?? '1.0.0',
    );
  }
}
