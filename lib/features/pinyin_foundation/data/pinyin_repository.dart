import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_constants.dart';
import '../domain/curriculum/pinyin_curriculum_catalog.dart';
import '../domain/models/pinyin_models.dart';

class PinyinRepository {
  final DatabaseExecutor _db;

  const PinyinRepository(this._db);

  List<PinyinUnit> getUnits() {
    return PinyinCurriculumCatalog.getUnits();
  }

  PinyinLesson? getLessonById(String lessonId) {
    for (final u in getUnits()) {
      for (final l in u.lessons) {
        if (l.id == lessonId) return l;
      }
    }
    return null;
  }

  /// Records a practice attempt on a specific Pinyin item and updates its mastery state.
  Future<void> recordItemAttempt({
    required String itemId,
    required String itemType,
    required bool isCorrect,
    required double score,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();

    final existing = await _db.query(
      DatabaseConstants.tablePinyinProgress,
      where: 'pinyin_item_id = ?',
      whereArgs: [itemId],
      limit: 1,
    );

    int attempts = 1;
    int correct = isCorrect ? 1 : 0;
    double currentScore = score;
    String masteryState = 'learning';

    if (existing.isNotEmpty) {
      final row = existing.first;
      attempts = ((row['attempts_count'] as num?)?.toInt() ?? 0) + 1;
      correct = ((row['correct_count'] as num?)?.toInt() ?? 0) + (isCorrect ? 1 : 0);
      final prevScore = (row['score'] as num?)?.toDouble() ?? 0.0;
      currentScore = (prevScore * 0.4) + (score * 0.6); // Exponential smoothing

      if (correct >= 3 && currentScore >= 0.85) {
        masteryState = 'mastered';
      } else if (correct >= 2 && currentScore >= 0.7) {
        masteryState = 'familiar';
      } else {
        masteryState = 'learning';
      }

      await _db.update(
        DatabaseConstants.tablePinyinProgress,
        {
          'mastery_state': masteryState,
          'attempts_count': attempts,
          'correct_count': correct,
          'score': currentScore,
          'last_practiced_at': now,
          'updated_at': now,
        },
        where: 'pinyin_item_id = ?',
        whereArgs: [itemId],
      );
    } else {
      if (isCorrect && score >= 0.9) {
        masteryState = 'familiar';
      }
      await _db.insert(
        DatabaseConstants.tablePinyinProgress,
        {
          'id': 'pin_prog_$itemId',
          'pinyin_item_id': itemId,
          'item_type': itemType,
          'mastery_state': masteryState,
          'attempts_count': attempts,
          'correct_count': correct,
          'score': currentScore,
          'last_practiced_at': now,
          'created_at': now,
          'updated_at': now,
        },
      );
    }

    // Synchronize to canonical Knowledge Registry
    await _db.insert(
      DatabaseConstants.tableKnowledgeRegistry,
      {
        'id': 'KNOW_PINYIN_$itemId',
        'entity_type': 'pinyin',
        'canonical_id': itemId,
        'hsk_level': 0,
        'title': itemId,
        'is_deprecated': 0,
        'package_id': 'pinyin_foundation',
        'metadata_json': json.encode({'type': itemType, 'score': currentScore}),
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retrieves progress records for all Pinyin items.
  Future<Map<String, PinyinProgressRecord>> getAllProgress() async {
    final rows = await _db.query(DatabaseConstants.tablePinyinProgress);
    final map = <String, PinyinProgressRecord>{};

    for (final r in rows) {
      final itemId = r['pinyin_item_id'] as String;
      map[itemId] = PinyinProgressRecord(
        itemId: itemId,
        itemType: r['item_type'] as String? ?? 'initial',
        masteryState: r['mastery_state'] as String? ?? 'not_started',
        attemptsCount: (r['attempts_count'] as num?)?.toInt() ?? 0,
        correctCount: (r['correct_count'] as num?)?.toInt() ?? 0,
        score: (r['score'] as num?)?.toDouble() ?? 0.0,
        lastPracticedAt: r['last_practiced_at'] as String?,
      );
    }
    return map;
  }

  /// Calculates overall completion percentage of the Pinyin Foundation curriculum.
  Future<double> getOverallCompletionRate() async {
    final progressMap = await getAllProgress();
    int totalItems = 0;
    int completedItems = 0;

    for (final u in getUnits()) {
      for (final l in u.lessons) {
        totalItems += l.items.length;
        for (final item in l.items) {
          final prog = progressMap[item.id];
          if (prog != null && (prog.masteryState == 'mastered' || prog.masteryState == 'familiar')) {
            completedItems++;
          }
        }
      }
    }

    if (totalItems == 0) return 1.0;
    return (completedItems / totalItems).clamp(0.0, 1.0);
  }

  /// Fast-tracks / credits Pinyin Foundation for learners who demonstrated mastery in Placement Test.
  Future<void> creditPinyinMastery({String reason = 'placement_test_bypass'}) async {
    final now = DateTime.now().toUtc().toIso8601String();

    for (final u in getUnits()) {
      for (final l in u.lessons) {
        for (final item in l.items) {
          await _db.insert(
            DatabaseConstants.tablePinyinProgress,
            {
              'id': 'pin_prog_${item.id}',
              'pinyin_item_id': item.id,
              'item_type': item.type.name,
              'mastery_state': 'mastered',
              'attempts_count': 1,
              'correct_count': 1,
              'score': 1.0,
              'last_practiced_at': now,
              'created_at': now,
              'updated_at': now,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }
    }
  }
}
