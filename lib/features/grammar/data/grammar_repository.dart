import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/dao/activity_dao.dart';
import '../../../../core/database/dao/learner_evidence_dao.dart';
import '../../../../core/database/database_constants.dart';
import '../domain/catalog/grammar_catalog.dart';
import '../domain/models/grammar_models.dart';

abstract class GrammarRepository {
  Future<List<GrammarItem>> getGrammarItems({int? hskLevel, String? tag, String? query});
  Future<GrammarItem?> getGrammarItemById(String id);
  Future<GrammarProgress?> getProgress(String grammarId);
  Future<Map<String, GrammarProgress>> getAllProgressMap();
  Future<void> recordStudySession({
    required String grammarId,
    required double score,
    required int durationSeconds,
    required int exercisesCount,
  });
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
  Future<List<GrammarItem>> getGrammarItems({int? hskLevel, String? tag, String? query}) async {
    await _ensureCatalogSeeded();

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (hskLevel != null) {
      whereClauses.add('hsk_level = ?');
      whereArgs.add(hskLevel);
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
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return GrammarItem.fromMap(rows.first);
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
    // Academic honesty check: Only record session when exercises were actually evaluated!
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
      // 1. Update/insert grammar_progress
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

      // 2. Persist learner evidence
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

        // 3. Log activity for daily streak
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
}
