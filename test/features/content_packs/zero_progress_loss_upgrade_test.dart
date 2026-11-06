import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hi_chinese/core/database/database.dart';
import 'package:hi_chinese/features/content_packs/data/content_pack_manager.dart';
import 'package:hi_chinese/features/home/domain/models/learning_streak.dart';

/// Thread 5 – Prompt 5.1: Upgrade scenario & Zero Progress Loss.
///
/// Simulates an existing learner on HSK 1–3 (50 SRS cards in review, 10 completed
/// lessons, an active goal, a profile, a 7-day streak, mastery records) and then
/// installs the HSK 4, 5, 6 content packs. Every piece of learner state must be
/// byte-for-byte identical afterwards.
void main() {
  setUpAll(sqfliteFfiInit);

  // Words that exist in HSK 1–3 packs AND are re-listed in the HSK 4 pack.
  // They are deliberately included in the SRS deck to catch level drift.
  const crossLevelWords = ['往', '等', '对', '过', '爱情'];

  late Directory tempDir;
  late Database db;
  late ContentPackManager manager;

  Future<String> readPack(int lvl) =>
      File('assets/data/content_packs/hsk$lvl/hsk${lvl}_pack_v1.json').readAsString();

  Future<List<Map<String, Object?>>> snapshot(String table, {String orderBy = 'id'}) async =>
      (await db.query(table, orderBy: orderBy)).map((r) => Map<String, Object?>.from(r)).toList();

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('zero_loss_upgrade_');
    db = await AppDatabase.instance.open(
      customPath: '${tempDir.path}/zero_loss.db',
      customFactory: databaseFactoryFfi,
    );
    manager = ContentPackManager(db);
  });

  tearDown(() async {
    if (AppDatabase.instance.isOpen) await AppDatabase.instance.close();
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  /// Seeds a realistic HSK 1–3 learner. Returns the SRS vocabulary ids.
  Future<List<String>> seedExistingLearner() async {
    for (final lvl in [1, 2, 3]) {
      final r = await manager.installOrUpdatePack(await readPack(lvl));
      expect(r.isSuccess, isTrue, reason: 'HSK $lvl pack must install: ${r.errorMessage}');
    }

    final now = DateTime.utc(2026, 11, 6, 3);
    final iso = now.toIso8601String();

    // --- 10 completed HSK 1–3 lessons -------------------------------------------------
    final lessons = await db.rawQuery('''
      SELECT l.id, l.unit_id, c.hsk_level FROM ${DatabaseConstants.tableCurriculumLessons} l
      JOIN ${DatabaseConstants.tableCurriculumUnits} u ON u.id = l.unit_id
      JOIN ${DatabaseConstants.tableCurriculums} c ON c.id = u.curriculum_id
      WHERE c.hsk_level BETWEEN 1 AND 3
      ORDER BY c.hsk_level, u.order_index, l.order_index
    ''');
    expect(lessons.length, greaterThanOrEqualTo(10));
    final picked = [...lessons.take(4), ...lessons.skip(15).take(3), ...lessons.skip(30).take(3)];
    expect(picked.length, 10);
    for (final l in picked) {
      final id = l['id'] as String;
      await db.insert(DatabaseConstants.tableLessonProgress, {
        'id': 'prog_$id',
        'lesson_id': id,
        'unit_id': l['unit_id'],
        'hsk_level': l['hsk_level'],
        'status': 'completed',
        'completion_score': 0.92,
        'evidence_count': 6,
        'started_at': iso,
        'completed_at': iso,
        'last_studied_at': iso,
        'source': 'curriculum_lesson',
        'created_at': iso,
        'updated_at': iso,
      });
      await db.update(
        DatabaseConstants.tableCurriculumLessons,
        {'status': 'completed', 'is_locked': 0, 'completed_at': iso, 'credited_reason': 'lesson_flow'},
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    // --- 50 SRS cards in review (5 cross-level words + 45 others) ---------------------
    final vocabRows = await db.query(
      DatabaseConstants.tableVocabularies,
      columns: ['id', 'simplified'],
      where: 'hsk_level BETWEEN 1 AND 3',
      orderBy: 'id',
    );
    final cross = vocabRows.where((r) => crossLevelWords.contains(r['simplified'])).toList();
    expect(cross.length, crossLevelWords.length, reason: 'cross-level words must exist in HSK 1–3 packs');
    final others = vocabRows.where((r) => !crossLevelWords.contains(r['simplified'])).take(45);
    final srsVocab = [...cross, ...others].map((r) => r['id'] as String).toList();
    expect(srsVocab.length, 50);

    for (var i = 0; i < srsVocab.length; i++) {
      final vid = srsVocab[i];
      await db.insert(DatabaseConstants.tableSrsItems, {
        'id': 'srs_$vid',
        'content_id': vid,
        'content_type': 'vocabulary',
        'state': 'review',
        'interval_days': 3 + i,
        'ease_factor': 2.3 + (i % 5) * 0.1,
        'repetitions': 2 + i % 7,
        'lapses': i % 3,
        'due_at': now.add(Duration(days: i % 10)).toIso8601String(),
        'last_reviewed_at': iso,
        'created_at': iso,
        'updated_at': iso,
      });
      await db.insert(DatabaseConstants.tableLearnerEvidence, {
        'id': 'ev_$vid',
        'srs_item_id': 'srs_$vid',
        'content_id': vid,
        'content_type': 'vocabulary',
        'source': 'srs_review',
        'score': 1.0,
        'duration_ms': 1500,
        'metadata_json': '{}',
        'created_at': iso,
      });
    }

    // --- Goal, profile, settings ------------------------------------------------------
    await db.insert(DatabaseConstants.tableLearnerGoals, {
      'id': 'goal_active',
      'target_hsk_level': 4,
      'purpose': 'exam_preparation',
      'timeframe': 'standard',
      'daily_minutes': 45,
      'is_active': 1,
      'created_at': iso,
      'updated_at': iso,
    });
    await db.insert(DatabaseConstants.tableUserProfiles, {
      'id': 'local_user',
      'display_name': 'Learner',
      'current_hsk_level': 3,
      'target_hsk_level': 4,
      'purpose': 'exam_preparation',
      'timeframe': 'standard',
      'daily_minutes': 45,
      'start_date': '2026-09-01',
      'interests_json': '["travel"]',
      'avatar_style': 'panda',
      'created_at': iso,
      'updated_at': iso,
    });

    // --- 7-day streak -----------------------------------------------------------------
    for (var d = 0; d < 7; d++) {
      final t = now.subtract(Duration(days: d));
      await db.insert(DatabaseConstants.tableLearningActivities, {
        'id': 'act_$d',
        'activity_type': 'srs_review',
        'duration_seconds': 900,
        'items_count': 20,
        'activity_date': StreakCalculator.toDateString(t),
        'created_at': t.toIso8601String(),
        'timezone_offset_minutes': 0,
      });
    }

    // --- Mastery on the SRS words -----------------------------------------------------
    for (final vid in srsVocab.take(20)) {
      await db.insert(DatabaseConstants.tableCurriculumMastery, {
        'id': 'mast_$vid',
        'item_id': vid,
        'item_type': 'vocabulary',
        'mastery_state': 'mastered',
        'score': 0.95,
        'attempts_count': 5,
        'last_attempt_at': iso,
        'created_at': iso,
        'updated_at': iso,
      });
    }
    return srsVocab;
  }

  LearningStreak streakOf(List<Map<String, Object?>> activities) => const StreakCalculator().calculate(
        meaningfulEventTimesUtc: activities.map((a) => DateTime.parse(a['created_at'] as String)),
        referenceTimeUtc: DateTime.utc(2026, 11, 6, 3),
        timeZoneOffset: Duration.zero,
      );

  test('Installing HSK 4, 5, 6 packs preserves 100% of an HSK 1–3 learner\'s state', () async {
    final srsVocab = await seedExistingLearner();

    final protectedTables = [
      DatabaseConstants.tableSrsItems,
      DatabaseConstants.tableLearnerEvidence,
      DatabaseConstants.tableLessonProgress,
      DatabaseConstants.tableLearnerGoals,
      DatabaseConstants.tableUserProfiles,
      DatabaseConstants.tableLearningActivities,
      DatabaseConstants.tableCurriculumMastery,
    ];
    final before = {for (final t in protectedTables) t: await snapshot(t)};
    final lessonsBefore = await db.rawQuery(
      "SELECT id, status, is_locked, completed_at, credited_reason FROM ${DatabaseConstants.tableCurriculumLessons} "
      "WHERE status = 'completed' ORDER BY id",
    );
    final streakBefore = streakOf(before[DatabaseConstants.tableLearningActivities]!);
    expect(streakBefore.currentStreak, 7);

    // --- Upgrade: install HSK 4, 5, 6 -------------------------------------------------
    for (final lvl in [4, 5, 6]) {
      final r = await manager.installOrUpdatePack(await readPack(lvl));
      expect(r.isSuccess, isTrue, reason: 'HSK $lvl pack must install: ${r.errorMessage}');
    }

    // 1. Learner tables byte-for-byte identical.
    for (final t in protectedTables) {
      expect(await snapshot(t), equals(before[t]), reason: 'Table "$t" changed after upgrade');
    }
    expect(before[DatabaseConstants.tableSrsItems]!.length, 50);
    expect(before[DatabaseConstants.tableLessonProgress]!.length, 10);

    // 2. Completed lessons still completed & unlocked.
    final lessonsAfter = await db.rawQuery(
      "SELECT id, status, is_locked, completed_at, credited_reason FROM ${DatabaseConstants.tableCurriculumLessons} "
      "WHERE id IN (${lessonsBefore.map((_) => '?').join(',')}) ORDER BY id",
      lessonsBefore.map((r) => r['id']).toList(),
    );
    expect(lessonsAfter, equals(lessonsBefore));

    // 3. Streak unchanged.
    expect(streakOf(await snapshot(DatabaseConstants.tableLearningActivities)), equals(streakBefore));

    // 4. Every SRS card still joins to its vocabulary row (review deck intact).
    final joined = await db.rawQuery('''
      SELECT COUNT(*) AS c FROM ${DatabaseConstants.tableSrsItems} s
      JOIN ${DatabaseConstants.tableVocabularies} v ON v.id = s.content_id
      WHERE s.deleted_at IS NULL
    ''');
    expect(joined.first['c'], 50);

    // 5. HSK 4–6 curricula really installed alongside 1–3.
    final curr = await db.query(DatabaseConstants.tableCurriculums, columns: ['hsk_level'], orderBy: 'hsk_level');
    expect(curr.map((r) => r['hsk_level']), [1, 2, 3, 4, 5, 6]);
    expect(srsVocab, hasLength(50));
  });

  test('Cross-level words learned at HSK 1–3 keep their original level and meaning after HSK 4 install', () async {
    await seedExistingLearner();
    final before = {
      for (final w in crossLevelWords)
        w: (await db.rawQuery('''
          SELECT v.hsk_level, v.pinyin, s.meaning_vi FROM ${DatabaseConstants.tableVocabularies} v
          LEFT JOIN ${DatabaseConstants.tableVocabularySenses} s ON s.vocabulary_id = v.id
          WHERE v.id = ? ORDER BY s.id LIMIT 1
        ''', ['vocab_$w'])).first,
    };
    for (final b in before.values) {
      expect(b['hsk_level'], lessThanOrEqualTo(3));
    }

    final r = await manager.installOrUpdatePack(await readPack(4));
    expect(r.isSuccess, isTrue);

    for (final w in crossLevelWords) {
      final after = (await db.rawQuery('''
        SELECT v.hsk_level, v.pinyin, s.meaning_vi FROM ${DatabaseConstants.tableVocabularies} v
        LEFT JOIN ${DatabaseConstants.tableVocabularySenses} s ON s.vocabulary_id = v.id
        WHERE v.id = ? ORDER BY s.id LIMIT 1
      ''', ['vocab_$w'])).first;
      expect(after, equals(before[w]), reason: '"$w" drifted from HSK ${before[w]!['hsk_level']} after HSK 4 install');
    }

    // The HSK 4 lesson must still link to the shared knowledge item.
    final links = await db.rawQuery('''
      SELECT COUNT(*) AS c FROM ${DatabaseConstants.tableLessonKnowledgeItems} lki
      JOIN ${DatabaseConstants.tableKnowledgeRegistry} k ON k.id = lki.knowledge_item_id
      WHERE lki.lesson_id = 'lesson_4_1' AND k.canonical_id = '爱情'
    ''');
    expect(links.first['c'], 1);
  });

  test('Referential integrity after installing all six packs: no dangling segments or links', () async {
    for (final lvl in [1, 2, 3, 4, 5, 6]) {
      final r = await manager.installOrUpdatePack(await readPack(lvl));
      expect(r.isSuccess, isTrue, reason: 'HSK $lvl: ${r.errorMessage}');
    }
    final danglingSegments = await db.rawQuery('''
      SELECT s.id, s.content_ref_id FROM ${DatabaseConstants.tableLessonSegments} s
      LEFT JOIN ${DatabaseConstants.tableContentItems} c ON c.content_id = s.content_ref_id
      WHERE s.content_ref_id IS NOT NULL AND c.content_id IS NULL
    ''');
    expect(danglingSegments, isEmpty);

    final danglingLinks = await db.rawQuery('''
      SELECT lki.id FROM ${DatabaseConstants.tableLessonKnowledgeItems} lki
      LEFT JOIN ${DatabaseConstants.tableKnowledgeRegistry} k ON k.id = lki.knowledge_item_id
      LEFT JOIN ${DatabaseConstants.tableCurriculumLessons} l ON l.id = lki.lesson_id
      WHERE k.id IS NULL OR l.id IS NULL
    ''');
    expect(danglingLinks, isEmpty);

    final vocabMissing = await db.rawQuery('''
      SELECT v.id FROM ${DatabaseConstants.tableVocabularies} v
      WHERE TRIM(COALESCE(v.pinyin, '')) = ''
         OR NOT EXISTS (
           SELECT 1 FROM ${DatabaseConstants.tableVocabularySenses} s
           WHERE s.vocabulary_id = v.id AND TRIM(COALESCE(s.meaning_vi, '')) <> ''
         )
    ''');
    expect(vocabMissing, isEmpty, reason: 'Vocabulary without pinyin or Vietnamese meaning: $vocabMissing');

    final fk = await db.rawQuery('PRAGMA foreign_key_check');
    expect(fk, isEmpty);
    for (final lvl in [1, 2, 3, 4, 5, 6]) {
      final packId = 'hsk${lvl}_pack_v1';
      expect(await manager.verifyIntegrity(packId), isTrue, reason: '$packId integrity');
    }
  });
}
