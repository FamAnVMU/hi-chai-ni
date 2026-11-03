import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/dao/activity_dao.dart';
import '../../../../core/database/dao/learner_evidence_dao.dart';
import '../../../../core/database/database_constants.dart';
import '../domain/catalog/grammar_catalog.dart';
import '../domain/models/grammar_models.dart';

abstract class GrammarRepository {
  Future<List<GrammarTopic>> getGrammarTopics();
  Future<List<GrammarItem>> getGrammarItems({
    int? hskLevel,
    String? topicCategory,
    String? tag,
    String? query,
  });
  Future<GrammarItem?> getGrammarItemById(String id);
  Future<List<GrammarExample>> getExamplesForGrammar(String grammarId);
  Future<GrammarProgress?> getProgress(String grammarId);
  Future<Map<String, GrammarProgress>> getAllProgressMap();
  Future<void> recordStudySession({
    required String grammarId,
    required double score,
    required int durationSeconds,
    required int exercisesCount,
  });
  Future<void> importGrammarDataset(List<Map<String, dynamic>> rawItems);
}

class DefaultGrammarRepository implements GrammarRepository {
  final DatabaseExecutor _db;
  late final LearnerEvidenceDao _evidenceDao;
  late final ActivityDao _activityDao;

  DefaultGrammarRepository(this._db) {
    final db = _db;
    if (db is Database) {
      _evidenceDao = LearnerEvidenceDao(db);
      _activityDao = ActivityDao(db);
    }
  }

  /// Ensure curated catalog items exist in SQLite
  Future<void> _ensureCatalogSeeded() async {
    final count = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableGrammarItems}'),
    );

    if (count == null || count == 0) {
      try {
        final jsonStr = await rootBundle.loadString('assets/data/hsk_grammar_all.json');
        final decoded = json.decode(jsonStr) as List<dynamic>;
        final items = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        await importGrammarDataset(items);
        return;
      } catch (_) {
        // Fallback for tests or environments where rootBundle is unavailable
      }

      for (final item in GrammarCatalog.items) {
        await _db.insert(
          DatabaseConstants.tableGrammarItems,
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }

  @override
  Future<List<GrammarTopic>> getGrammarTopics() async {
    await _ensureCatalogSeeded();
    try {
      final rows = await _db.query(
        DatabaseConstants.tableGrammarTopics,
        orderBy: 'display_order ASC',
      );
      return rows.map((r) => GrammarTopic.fromMap(r)).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<GrammarItem>> getGrammarItems({
    int? hskLevel,
    String? topicCategory,
    String? tag,
    String? query,
  }) async {
    await _ensureCatalogSeeded();

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (hskLevel != null) {
      whereClauses.add('(hsk_level = ? OR hsk_level_mapped = ?)');
      whereArgs.add(hskLevel);
      whereArgs.add(hskLevel);
    }

    if (topicCategory != null && topicCategory.isNotEmpty && topicCategory != 'all') {
      whereClauses.add('topic_category = ?');
      whereArgs.add(topicCategory);
    }

    final rows = await _db.query(
      DatabaseConstants.tableGrammarItems,
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'hsk_level ASC, code ASC',
    );

    var items = rows.map((r) => GrammarItem.fromMap(r)).toList();

    // In-memory filter for tags & query search
    if (tag != null && tag.isNotEmpty) {
      items = items.where((it) => it.tags.contains(tag)).toList();
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      items = items.where((it) {
        return it.title.toLowerCase().contains(q) ||
            it.structure.toLowerCase().contains(q) ||
            it.meaningVi.toLowerCase().contains(q) ||
            it.explanationVi.toLowerCase().contains(q) ||
            it.usageConditionsVi.toLowerCase().contains(q) ||
            it.categoryChinese.toLowerCase().contains(q) ||
            it.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }

    return items;
  }

  @override
  Future<GrammarItem?> getGrammarItemById(String id) async {
    await _ensureCatalogSeeded();

    final rows = await _db.query(
      DatabaseConstants.tableGrammarItems,
      where: 'id = ? OR grammar_id = ? OR code = ?',
      whereArgs: [id, id, id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    final item = GrammarItem.fromMap(rows.first);

    // If relational examples exist, enrich with them
    final relationalExamples = await getExamplesForGrammar(item.id);
    if (relationalExamples.isNotEmpty) {
      return GrammarItem(
        id: item.id,
        hskLevel: item.hskLevel,
        code: item.code,
        title: item.title,
        structure: item.structure,
        meaningVi: item.meaningVi,
        usageConditionsVi: item.usageConditionsVi,
        sentencePositionVi: item.sentencePositionVi,
        explanationVi: item.explanationVi,
        source: item.source,
        grammarId: item.grammarId,
        topicCategory: item.topicCategory,
        topicNameVi: item.topicNameVi,
        categoryChinese: item.categoryChinese,
        categoryEnglish: item.categoryEnglish,
        originalLevel: item.originalLevel,
        hskLevelMapped: item.hskLevelMapped,
        mappingBasis: item.mappingBasis,
        isReferenceOnly: item.isReferenceOnly,
        verificationStatus: item.verificationStatus,
        license: item.license,
        attribution: item.attribution,
        wikiLink: item.wikiLink,
        tags: item.tags,
        relatedVocabIds: item.relatedVocabIds,
        relatedGrammarIds: item.relatedGrammarIds,
        prerequisiteGrammarIds: item.prerequisiteGrammarIds,
        examples: relationalExamples,
        contrastiveExamples: item.contrastiveExamples,
        exercises: item.exercises,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      );
    }

    return item;
  }

  @override
  Future<List<GrammarExample>> getExamplesForGrammar(String grammarId) async {
    try {
      final rows = await _db.query(
        DatabaseConstants.tableGrammarExamples,
        where: 'grammar_id = ?',
        whereArgs: [grammarId],
        orderBy: 'order_index ASC',
      );
      return rows.map((r) => GrammarExample.fromMap(r)).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<GrammarProgress?> getProgress(String grammarId) async {
    final rows = await _db.query(
      DatabaseConstants.tableGrammarProgress,
      where: 'grammar_id = ?',
      whereArgs: [grammarId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return GrammarProgress.fromMap(rows.first);
  }

  @override
  Future<Map<String, GrammarProgress>> getAllProgressMap() async {
    final rows = await _db.query(DatabaseConstants.tableGrammarProgress);
    final map = <String, GrammarProgress>{};
    for (final r in rows) {
      final progress = GrammarProgress.fromMap(r);
      map[progress.grammarId] = progress;
    }
    return map;
  }

  @override
  Future<void> recordStudySession({
    required String grammarId,
    required double score,
    required int durationSeconds,
    required int exercisesCount,
  }) async {
    if (exercisesCount <= 0) return;

    final item = await getGrammarItemById(grammarId);
    if (item == null) return;

    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final clampedScore = score.clamp(0.0, 1.0);
    final newStatus = clampedScore >= 0.8
        ? GrammarProgressStatus.mastered
        : GrammarProgressStatus.learning;

    final existingProgress = await getProgress(grammarId);
    final totalExercises = (existingProgress?.exercisesCompleted ?? 0) + exercisesCount;

    Future<void> executeWithDb(dynamic executor) async {
      await executor.insert(
        DatabaseConstants.tableGrammarProgress,
        {
          'id': existingProgress?.id ?? 'gp_${grammarId}_${DateTime.now().millisecondsSinceEpoch}',
          'grammar_id': grammarId,
          'hsk_level': item.hskLevel,
          'status': newStatus.name,
          'mastery_score': clampedScore,
          'exercises_completed': totalExercises,
          'last_studied_at': nowUtc,
          'created_at': existingProgress?.createdAt.toUtc().toIso8601String() ?? nowUtc,
          'updated_at': nowUtc,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final evidenceId = 'ev_grm_${DateTime.now().microsecondsSinceEpoch}';
      if (_db is Database) {
        await _evidenceDao.appendEvidence(
          {
            'id': evidenceId,
            'content_id': grammarId,
            'content_type': 'grammar',
            'source': 'grammar_practice',
            'score': clampedScore,
            'duration_ms': durationSeconds * 1000,
            'metadata_json': json.encode({
              'grammar_title': item.title,
              'hsk_level': item.hskLevel,
              'exercises_evaluated': exercisesCount,
            }),
            'created_at': nowUtc,
          },
          txn: executor is Transaction ? executor : null,
        );

        final activityId = 'act_grm_${DateTime.now().microsecondsSinceEpoch}';
        await _activityDao.logActivity(
          {
            'id': activityId,
            'activity_type': 'grammar',
            'duration_seconds': durationSeconds,
            'items_count': exercisesCount,
            'activity_date': nowUtc.substring(0, 10),
            'created_at': nowUtc,
          },
          txn: executor is Transaction ? executor : null,
        );
      }
    }

    final db = _db;
    if (db is Database) {
      await db.transaction((txn) async {
        await executeWithDb(txn);
      });
    } else {
      await executeWithDb(_db);
    }
  }

  @override
  Future<void> importGrammarDataset(List<Map<String, dynamic>> rawItems) async {
    final nowUtc = DateTime.now().toUtc().toIso8601String();

    Future<void> performImport(dynamic executor) async {
      for (final raw in rawItems) {
        final item = GrammarItem.fromMap(raw);
        await executor.insert(
          DatabaseConstants.tableGrammarItems,
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Also normalize examples into tableGrammarExamples
        if (item.examples.isNotEmpty) {
          int order = 0;
          for (final ex in item.examples) {
            await executor.insert(
              DatabaseConstants.tableGrammarExamples,
              {
                'grammar_id': item.id,
                'chinese': ex.hanzi,
                'chinese_segmented': ex.chineseSegmented,
                'pinyin': ex.pinyin,
                'translation_en': ex.translationEn,
                'translation_vi': ex.translationVi,
                'sound_ref': ex.audioUri,
                'source': ex.source ?? item.source,
                'order_index': order++,
                'created_at': nowUtc,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }
    }

    final db = _db;
    if (db is Database) {
      await db.transaction((txn) async {
        await performImport(txn);
      });
    } else {
      await performImport(_db);
    }
  }
}
