import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'migration.dart';

/// Migration v10: Normalizes learning content, establishes canonical Knowledge Registry,
/// links lessons to knowledge units relationally, and enhances content packs schema.
class MigrationV10 implements Migration {
  const MigrationV10();

  @override
  int get version => 10;

  @override
  String get description =>
      'Normalize learning content, add knowledge registry, lesson knowledge mapping, and content versioning';

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. Canonical Knowledge Registry Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableKnowledgeRegistry} (
        id TEXT PRIMARY KEY,
        entity_type TEXT NOT NULL,
        canonical_id TEXT NOT NULL,
        hsk_level INTEGER NOT NULL,
        title TEXT NOT NULL,
        is_deprecated INTEGER NOT NULL DEFAULT 0,
        replaced_by_id TEXT,
        package_id TEXT,
        metadata_json TEXT NOT NULL DEFAULT '{}',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_knowledge_type_canonical 
      ON ${DatabaseConstants.tableKnowledgeRegistry} (entity_type, canonical_id);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_knowledge_hsk_level 
      ON ${DatabaseConstants.tableKnowledgeRegistry} (hsk_level);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_knowledge_package_id 
      ON ${DatabaseConstants.tableKnowledgeRegistry} (package_id);
    ''');

    // 2. Lesson Knowledge Items Relational Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableLessonKnowledgeItems} (
        id TEXT PRIMARY KEY,
        lesson_id TEXT NOT NULL,
        knowledge_item_id TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'instruction',
        sequence_order INTEGER NOT NULL DEFAULT 1,
        is_mandatory INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (lesson_id) REFERENCES ${DatabaseConstants.tableCurriculumLessons} (id) ON DELETE CASCADE,
        FOREIGN KEY (knowledge_item_id) REFERENCES ${DatabaseConstants.tableKnowledgeRegistry} (id) ON DELETE CASCADE
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_lesson_knowledge_lesson 
      ON ${DatabaseConstants.tableLessonKnowledgeItems} (lesson_id, sequence_order);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_lesson_knowledge_item 
      ON ${DatabaseConstants.tableLessonKnowledgeItems} (knowledge_item_id);
    ''');

    // 3. Content ID Mappings Table (Preserves user progress across deprecations/refactors)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableContentIdMappings} (
        id TEXT PRIMARY KEY,
        old_id TEXT NOT NULL,
        new_id TEXT NOT NULL,
        mapping_type TEXT NOT NULL,
        package_id TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_content_mappings_old 
      ON ${DatabaseConstants.tableContentIdMappings} (old_id);
    ''');

    // 4. Alter content_packs to add versioning and dependency tracking columns
    final packColumnsToAdd = <String, String>{
      'curriculum_version': "TEXT DEFAULT '1.0.0'",
      'minimum_app_version': "TEXT DEFAULT '1.0.0'",
      'schema_version': 'INTEGER DEFAULT 1',
      'dependencies_json': "TEXT DEFAULT '[]'",
      'release_date': 'TEXT',
      'release_status': "TEXT DEFAULT 'stable'",
      'source_info': 'TEXT',
    };

    final packTableInfo = await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableContentPacks})');
    final existingPackCols = packTableInfo.map((row) => row['name'] as String).toSet();

    for (final entry in packColumnsToAdd.entries) {
      if (!existingPackCols.contains(entry.key)) {
        await db.execute(
          'ALTER TABLE ${DatabaseConstants.tableContentPacks} ADD COLUMN ${entry.key} ${entry.value};',
        );
      }
    }

    // 5. Backfill & Normalize existing data from content_items
    await _backfillContentItems(db);
  }

  Future<void> _backfillContentItems(DatabaseExecutor db) async {
    try {
      // Check if content_items table exists
      final tableCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='${DatabaseConstants.tableContentItems}'",
      );
      if (tableCheck.isEmpty) return;

      // Map lesson_segments: content_ref_id -> List<lesson_id>
      final segmentsCheck = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='${DatabaseConstants.tableLessonSegments}'",
      );
      final refToLessons = <String, List<String>>{};
      if (segmentsCheck.isNotEmpty) {
        final segments = await db.query(
          DatabaseConstants.tableLessonSegments,
          columns: ['lesson_id', 'content_ref_id'],
          where: 'content_ref_id IS NOT NULL',
        );
        for (final seg in segments) {
          final refId = seg['content_ref_id'] as String?;
          final lessonId = seg['lesson_id'] as String?;
          if (refId != null && lessonId != null) {
            refToLessons.putIfAbsent(refId, () => []).add(lessonId);
          }
        }
      }

      final contentItems = await db.query(DatabaseConstants.tableContentItems);
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      for (final item in contentItems) {
        final contentId = item['content_id'] as String? ?? '';
        final knowledgeType = item['knowledge_type'] as String? ?? '';
        final hskLevel = (item['hsk_level'] as num?)?.toInt() ?? 1;
        final rawJson = item['content_json'] as String? ?? '{}';
        final currId = item['curriculum_id'] as String? ?? 'curr_hsk$hskLevel';
        final linkedLessons = refToLessons[contentId] ?? [];

        Map<String, dynamic> parsed;
        try {
          parsed = json.decode(rawJson) as Map<String, dynamic>;
        } catch (_) {
          continue;
        }

        if (knowledgeType == 'vocabulary' && parsed['words'] is List) {
          final words = parsed['words'] as List<dynamic>;
          int order = 1;
          for (final w in words) {
            if (w is! Map<String, dynamic>) continue;
            final simplified = w['simplified'] as String? ?? '';
            if (simplified.isEmpty) continue;
            final pinyin = w['pinyin'] as String? ?? '';
            final meaningVi = w['meaning_vi'] as String? ?? '';
            final pos = w['part_of_speech'] as String? ?? '';
            final example = w['example_sentence'] as String? ?? '';
            final audioUri = w['audio_uri'] as String? ?? '';

            final vocabId = 'vocab_$simplified';
            final senseId = 'sense_${simplified}_1';
            final knowId = 'KNOW_VOCAB_$simplified';

            // Insert into vocabularies
            await db.insert(
              DatabaseConstants.tableVocabularies,
              {
                'id': vocabId,
                'simplified': simplified,
                'traditional': simplified,
                'pinyin': pinyin,
                'hsk_level': hskLevel,
                'audio_uri': audioUri,
                'created_at': nowUtc,
                'updated_at': nowUtc,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );

            // Insert into vocabulary_senses
            await db.insert(
              DatabaseConstants.tableVocabularySenses,
              {
                'id': senseId,
                'vocabulary_id': vocabId,
                'part_of_speech': pos,
                'meaning_vi': meaningVi,
                'example_cn': example,
                'example_pinyin': '',
                'example_vi': '',
                'created_at': nowUtc,
                'updated_at': nowUtc,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );

            // Register in knowledge_registry
            await db.insert(
              DatabaseConstants.tableKnowledgeRegistry,
              {
                'id': knowId,
                'entity_type': 'vocabulary',
                'canonical_id': simplified,
                'hsk_level': hskLevel,
                'title': simplified,
                'is_deprecated': 0,
                'replaced_by_id': null,
                'package_id': currId,
                'metadata_json': json.encode({'pinyin': pinyin, 'meaning_vi': meaningVi}),
                'created_at': nowUtc,
                'updated_at': nowUtc,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            // Link to lessons
            for (final lessonId in linkedLessons) {
              await db.insert(
                DatabaseConstants.tableLessonKnowledgeItems,
                {
                  'id': 'lki_${lessonId}_$knowId',
                  'lesson_id': lessonId,
                  'knowledge_item_id': knowId,
                  'role': 'instruction',
                  'sequence_order': order,
                  'is_mandatory': 1,
                  'created_at': nowUtc,
                },
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
            }
            order++;
          }
        } else if (knowledgeType == 'grammar' && parsed['points'] is List) {
          final points = parsed['points'] as List<dynamic>;
          int order = 1;
          for (final p in points) {
            if (p is! Map<String, dynamic>) continue;
            final title = p['title'] as String? ?? 'Điểm ngữ pháp $order';
            final structure = p['structure'] as String? ?? '';
            final explanation = p['explanation'] as String? ?? '';
            final posEx = p['positive_example'] as String? ?? '';
            final conEx = p['contrastive_example'] as String? ?? '';

            final gramCode = 'GRAM_${contentId}_$order';
            final gramId = 'gram_${contentId}_$order';
            final knowId = 'KNOW_GRAMMAR_${contentId}_$order';

            // Insert into grammar_items
            await db.insert(
              DatabaseConstants.tableGrammarItems,
              {
                'id': gramId,
                'hsk_level': hskLevel,
                'code': gramCode,
                'pattern': structure,
                'title_vi': title,
                'explanation_vi': explanation,
                'examples_json': json.encode(posEx.isNotEmpty ? [posEx] : []),
                'title': title,
                'structure': structure,
                'meaning_vi': explanation,
                'contrastive_examples_json': json.encode(conEx.isNotEmpty ? [conEx] : []),
                'created_at': nowUtc,
                'updated_at': nowUtc,
              },
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );

            // Register in knowledge_registry
            await db.insert(
              DatabaseConstants.tableKnowledgeRegistry,
              {
                'id': knowId,
                'entity_type': 'grammar',
                'canonical_id': gramCode,
                'hsk_level': hskLevel,
                'title': title,
                'is_deprecated': 0,
                'replaced_by_id': null,
                'package_id': currId,
                'metadata_json': json.encode({'structure': structure, 'explanation': explanation}),
                'created_at': nowUtc,
                'updated_at': nowUtc,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            // Link to lessons
            for (final lessonId in linkedLessons) {
              await db.insert(
                DatabaseConstants.tableLessonKnowledgeItems,
                {
                  'id': 'lki_${lessonId}_$knowId',
                  'lesson_id': lessonId,
                  'knowledge_item_id': knowId,
                  'role': 'instruction',
                  'sequence_order': order,
                  'is_mandatory': 1,
                  'created_at': nowUtc,
                },
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
            }
            order++;
          }
        }
      }
    } catch (e, stackTrace) {
      debugPrint('[MigrationV10] Content backfill non-fatal warning: $e\n$stackTrace');
    }
  }
}
