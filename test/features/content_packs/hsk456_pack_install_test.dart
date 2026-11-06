import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hi_chinese/core/database/database.dart';
import 'package:hi_chinese/features/content_packs/data/content_pack_manager.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Content Pack Installation & Zero Loss Audit Tests (HSK 4-6)', () {
    late Directory tempDir;
    late String dbPath;
    late Database db;
    late ContentPackManager manager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hsk456_install_test_');
      dbPath = '${tempDir.path}/hsk456_test.db';
      db = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );
      manager = ContentPackManager(db);
    });

    tearDown(() async {
      if (AppDatabase.instance.isOpen) {
        await AppDatabase.instance.close();
      }
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. computeChecksum ignores whitespace and manifest sha256 to ensure consistent hash', () async {
      for (final lvl in ['hsk4', 'hsk5', 'hsk6']) {
        final packFile = File('assets/data/content_packs/$lvl/${lvl}_pack_v1.json');
        expect(await packFile.exists(), isTrue);

        final rawJson = await packFile.readAsString();
        final decoded = json.decode(rawJson) as Map<String, dynamic>;
        final manifest = decoded['manifest'] as Map<String, dynamic>;
        final declaredSha = manifest['sha256'] as String? ?? '';

        final computedOriginal = ContentPackManager.computeChecksum(rawJson);
        expect(computedOriginal.toLowerCase(), equals(declaredSha.toLowerCase()));

        final copy = Map<String, dynamic>.from(decoded);
        final copyManifest = Map<String, dynamic>.from(manifest);
        copyManifest['sha256'] = 'arbitrary_fake_sha_for_testing';
        copy['manifest'] = copyManifest;
        final rawJsonAlteredSha = json.encode(copy);

        final computedAltered = ContentPackManager.computeChecksum(rawJsonAlteredSha);
        expect(computedAltered, equals(computedOriginal));
      }
    });

    test('2. Successfully installs HSK 4, HSK 5, and HSK 6 packs into SQLite relational schema', () async {
      final hsk4File = File('assets/data/content_packs/hsk4/hsk4_pack_v1.json');
      final hsk4Raw = await hsk4File.readAsString();
      final hsk4Result = await manager.installOrUpdatePack(hsk4Raw);
      expect(hsk4Result.isSuccess, isTrue);

      final packRow = await db.query(
        DatabaseConstants.tableContentPacks,
        where: 'id = ?',
        whereArgs: ['hsk4_pack_v1'],
      );
      expect(packRow.length, 1);
      expect(packRow.first['hsk_level'], 4);

      final units = await db.query(
        DatabaseConstants.tableCurriculumUnits,
        where: 'curriculum_id = ?',
        whereArgs: ['curr_hsk4'],
      );
      expect(units.length, 5);

      final lessons = await db.query(
        DatabaseConstants.tableCurriculumLessons,
        where: 'unit_id IN (SELECT id FROM ${DatabaseConstants.tableCurriculumUnits} WHERE curriculum_id = ?)',
        whereArgs: ['curr_hsk4'],
      );
      expect(lessons.length, 30);

      final segments = await db.query(
        DatabaseConstants.tableLessonSegments,
        where: 'lesson_id IN (SELECT id FROM ${DatabaseConstants.tableCurriculumLessons} WHERE unit_id IN (SELECT id FROM ${DatabaseConstants.tableCurriculumUnits} WHERE curriculum_id = ?))',
        whereArgs: ['curr_hsk4'],
      );
      expect(segments.length, 180);

      final contentItems = await db.query(
        DatabaseConstants.tableContentItems,
        where: 'curriculum_id = ?',
        whereArgs: ['curr_hsk4'],
      );
      expect(contentItems.length, 180);

      final hsk4VocabRegistry = await db.query(
        DatabaseConstants.tableKnowledgeRegistry,
        where: 'package_id = ? AND entity_type = ?',
        whereArgs: ['curr_hsk4', 'vocabulary'],
      );
      expect(hsk4VocabRegistry.length, 597);

      final hsk5File = File('assets/data/content_packs/hsk5/hsk5_pack_v1.json');
      final hsk5Raw = await hsk5File.readAsString();
      final hsk5Result = await manager.installOrUpdatePack(hsk5Raw);
      expect(hsk5Result.isSuccess, isTrue);

      final hsk5Units = await db.query(
        DatabaseConstants.tableCurriculumUnits,
        where: 'curriculum_id = ?',
        whereArgs: ['curr_hsk5'],
      );
      expect(hsk5Units.length, 6);

      final hsk5Lessons = await db.query(
        DatabaseConstants.tableCurriculumLessons,
        where: 'unit_id IN (SELECT id FROM ${DatabaseConstants.tableCurriculumUnits} WHERE curriculum_id = ?)',
        whereArgs: ['curr_hsk5'],
      );
      expect(hsk5Lessons.length, 36);

      final hsk5VocabRegistry = await db.query(
        DatabaseConstants.tableKnowledgeRegistry,
        where: 'package_id = ? AND entity_type = ?',
        whereArgs: ['curr_hsk5', 'vocabulary'],
      );
      expect(hsk5VocabRegistry.length, 1296);

      final hsk6File = File('assets/data/content_packs/hsk6/hsk6_pack_v1.json');
      final hsk6Raw = await hsk6File.readAsString();
      final hsk6Result = await manager.installOrUpdatePack(hsk6Raw);
      expect(hsk6Result.isSuccess, isTrue);

      final hsk6Units = await db.query(
        DatabaseConstants.tableCurriculumUnits,
        where: 'curriculum_id = ?',
        whereArgs: ['curr_hsk6'],
      );
      expect(hsk6Units.length, 10);

      final hsk6Lessons = await db.query(
        DatabaseConstants.tableCurriculumLessons,
        where: 'unit_id IN (SELECT id FROM ${DatabaseConstants.tableCurriculumUnits} WHERE curriculum_id = ?)',
        whereArgs: ['curr_hsk6'],
      );
      expect(hsk6Lessons.length, 50);

      final hsk6VocabRegistry = await db.query(
        DatabaseConstants.tableKnowledgeRegistry,
        where: 'package_id = ? AND entity_type = ?',
        whereArgs: ['curr_hsk6', 'vocabulary'],
      );
      expect(hsk6VocabRegistry.length, 2500);
    });

    test('3. Zero Loss Progress Audit: Updating pack preserves 100% of user lesson progress, mastery, and SRS state', () async {
      final hsk4File = File('assets/data/content_packs/hsk4/hsk4_pack_v1.json');
      final hsk4Raw = await hsk4File.readAsString();
      await manager.installOrUpdatePack(hsk4Raw);

      final firstLesson = (await db.query(
        DatabaseConstants.tableCurriculumLessons,
        where: 'unit_id IN (SELECT id FROM ${DatabaseConstants.tableCurriculumUnits} WHERE curriculum_id = ?)',
        whereArgs: ['curr_hsk4'],
        orderBy: 'order_index ASC',
        limit: 1,
      )).first;
      final targetLessonId = firstLesson['id'] as String;
      final targetUnitId = firstLesson['unit_id'] as String;

      final now = DateTime.now().toUtc().toIso8601String();

      await db.insert(DatabaseConstants.tableLessonProgress, {
        'id': 'prog_$targetLessonId',
        'lesson_id': targetLessonId,
        'unit_id': targetUnitId,
        'hsk_level': 4,
        'status': 'completed',
        'completion_score': 1.0,
        'evidence_count': 6,
        'started_at': now,
        'completed_at': now,
        'last_studied_at': now,
        'source': 'curriculum_lesson',
        'created_at': now,
        'updated_at': now,
      });

      await db.update(
        DatabaseConstants.tableCurriculumLessons,
        {
          'status': 'completed',
          'is_locked': 0,
          'completed_at': now,
        },
        where: 'id = ?',
        whereArgs: [targetLessonId],
      );

      final sampleVocabRow = (await db.query(
        DatabaseConstants.tableKnowledgeRegistry,
        where: 'package_id = ? AND entity_type = ?',
        whereArgs: ['curr_hsk4', 'vocabulary'],
        limit: 1,
      )).first;
      final sampleKnowId = sampleVocabRow['id'] as String;

      await db.insert(DatabaseConstants.tableCurriculumMastery, {
        'id': 'mast_$sampleKnowId',
        'item_id': sampleKnowId,
        'item_type': 'vocabulary',
        'mastery_state': 'mastered',
        'score': 0.98,
        'attempts_count': 7,
        'last_attempt_at': now,
        'created_at': now,
        'updated_at': now,
      });

      await db.insert(DatabaseConstants.tableSrsItems, {
        'id': 'srs_$sampleKnowId',
        'content_id': sampleKnowId,
        'content_type': 'vocabulary',
        'state': 'review',
        'interval_days': 21,
        'ease_factor': 2.5,
        'repetitions': 6,
        'lapses': 0,
        'due_at': '2026-11-27T00:00:00Z',
        'last_reviewed_at': now,
        'created_at': now,
        'updated_at': now,
      });

      await db.insert(DatabaseConstants.tableLearnerEvidence, {
        'id': 'ev_test_1',
        'srs_item_id': 'srs_$sampleKnowId',
        'content_id': sampleKnowId,
        'content_type': 'vocabulary',
        'source': 'quiz',
        'score': 1.0,
        'duration_ms': 1200,
        'metadata_json': json.encode({'answer': 'correct'}),
        'created_at': now,
      });

      final hsk4Decoded = json.decode(hsk4Raw) as Map<String, dynamic>;
      final manifestMap = Map<String, dynamic>.from(hsk4Decoded['manifest'] as Map<String, dynamic>);
      manifestMap['version'] = '1.1.0';
      manifestMap['title'] = 'Giáo trình chuẩn HSK 4 (Bản Cập Nhật v1.1.0)';
      manifestMap['sha256'] = '';

      final v11Pack = Map<String, dynamic>.from(hsk4Decoded);
      v11Pack['manifest'] = manifestMap;

      final v11Raw = json.encode(v11Pack);
      final updateResult = await manager.installOrUpdatePack(v11Raw);
      expect(updateResult.isSuccess, isTrue);

      final lessonProgressRows = await db.query(
        DatabaseConstants.tableLessonProgress,
        where: 'lesson_id = ?',
        whereArgs: [targetLessonId],
      );
      expect(lessonProgressRows.length, 1);
      final progRow = lessonProgressRows.first;
      expect(progRow['status'], equals('completed'));
      expect(progRow['completion_score'], equals(1.0));
      expect(progRow['evidence_count'], equals(6));

      final lessonRow = (await db.query(
        DatabaseConstants.tableCurriculumLessons,
        where: 'id = ?',
        whereArgs: [targetLessonId],
      )).first;
      expect(lessonRow['status'], equals('completed'));
      expect(lessonRow['is_locked'], equals(0));
      expect(lessonRow['completed_at'], isNotNull);

      final masteryRows = await db.query(
        DatabaseConstants.tableCurriculumMastery,
        where: 'item_id = ?',
        whereArgs: [sampleKnowId],
      );
      expect(masteryRows.length, 1);
      expect(masteryRows.first['mastery_state'], equals('mastered'));
      expect(masteryRows.first['score'], equals(0.98));
      expect(masteryRows.first['attempts_count'], equals(7));

      final srsRows = await db.query(
        DatabaseConstants.tableSrsItems,
        where: 'content_id = ?',
        whereArgs: [sampleKnowId],
      );
      expect(srsRows.length, 1);
      expect(srsRows.first['interval_days'], equals(21));
      expect(srsRows.first['repetitions'], equals(6));

      final evidenceRows = await db.query(
        DatabaseConstants.tableLearnerEvidence,
        where: 'id = ?',
        whereArgs: ['ev_test_1'],
      );
      expect(evidenceRows.length, 1);
      expect(evidenceRows.first['score'], equals(1.0));

      final packInfo = (await db.query(
        DatabaseConstants.tableContentPacks,
        where: 'id = ?',
        whereArgs: ['hsk4_pack_v1'],
      )).first;
      expect(packInfo['version'], equals('1.1.0'));
      expect(packInfo['title'], equals('Giáo trình chuẩn HSK 4 (Bản Cập Nhật v1.1.0)'));
    });

    test('4. Idempotent installation skips duplicate re-parsing when pack and curriculum exist', () async {
      final hsk4File = File('assets/data/content_packs/hsk4/hsk4_pack_v1.json');
      final hsk4Raw = await hsk4File.readAsString();

      final firstInstall = await manager.installOrUpdatePack(hsk4Raw);
      expect(firstInstall.isSuccess, isTrue);

      final secondInstall = await manager.installOrUpdatePack(hsk4Raw);
      expect(secondInstall.isSuccess, isTrue);
      expect(secondInstall.installedLessonsCount, equals(30));
      expect(secondInstall.installedContentItemsCount, equals(180));
    });
  });
}
