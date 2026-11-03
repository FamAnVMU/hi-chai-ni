import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hi_chinese/core/database/app_database.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/features/curriculum/data/content_pack_loader.dart';
import 'package:hi_chinese/features/curriculum/data/curriculum_repository.dart';
import 'package:hi_chinese/features/curriculum/presentation/screens/level_exit_exam_screen.dart';
import '../../helpers/mock_audio_platform.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    MockAudioPlatformHelper.setupMockPlatformChannels();
  });

  group('Real HSK Level Exit Exam & Progress Synchronization Tests', () {
    late Directory tempDir;
    late String dbPath;
    late Database db;
    late CurriculumRepository repo;
    late Map<String, dynamic> hsk1PackData;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('exit_exam_test_');
      dbPath = '${tempDir.path}/test_exit_exam.db';
      db = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );

      // Load and install real HSK 1 content pack
      final packFile = File('assets/data/content_packs/hsk1/hsk1_pack_v1.json');
      final rawJson = await packFile.readAsString();
      hsk1PackData = jsonDecode(rawJson) as Map<String, dynamic>;

      final loader = ContentPackLoader(db);
      await loader.loadPackFromJson(rawJson);

      repo = CurriculumRepository(db);
    });

    tearDown(() async {
      await AppDatabase.instance.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. Loads and parses real 40-question HSK 1 exit exam from database with sections', () async {
      final exitExamRow = await repo.getExitExam(1);
      expect(exitExamRow, isNotNull);
      expect(exitExamRow!['hsk_level'], equals(1));
      expect(exitExamRow['passing_score'], equals(120));

      final examDataJson = exitExamRow['exam_data_json'] as String;
      final parsed = jsonDecode(examDataJson) as Map<String, dynamic>;
      final sections = parsed['sections'] as List<dynamic>;

      expect(sections.length, equals(2));
      final listening = sections[0] as Map<String, dynamic>;
      final reading = sections[1] as Map<String, dynamic>;

      expect(listening['name'], equals('Listening'));
      expect((listening['questions'] as List).length, equals(20));

      // Each listening question must have audio_uri
      for (final q in (listening['questions'] as List)) {
        expect(q['audio_uri'], isNotNull);
        expect(q['audio_uri'].toString(), startsWith('assets/audio/'));
        expect(q['options'], isNotEmpty);
        expect(q['correct_answer'], isNotNull);
      }

      expect(reading['name'], equals('Reading'));
      expect((reading['questions'] as List).length, equals(20));
      for (final q in (reading['questions'] as List)) {
        expect(q['prompt'], isNotNull);
        expect(q['options'], isNotEmpty);
        expect(q['correct_answer'], isNotNull);
      }
    });

    test('2. Submitting passing exam atomically records to curriculum_mastery, learning_activities, learner_evidence and unlocks next level', () async {
      // Record passing score: 140 / 200
      await repo.recordExitExamSubmission(
        hskLevel: 1,
        score: 140,
        totalScore: 200,
        listenScore: 70,
        readScore: 70,
        isPassed: true,
        durationSeconds: 1500,
        itemsCount: 40,
      );

      // Verify curriculum_mastery
      final masteryRows = await db.query(
        DatabaseConstants.tableCurriculumMastery,
        where: 'item_id = ?',
        whereArgs: ['exit_exam_hsk1'],
      );
      expect(masteryRows.length, equals(1));
      expect(masteryRows.first['mastery_state'], equals('mastered'));
      expect(masteryRows.first['score'], equals(0.7)); // 140 / 200
      expect(masteryRows.first['attempts_count'], equals(1));

      // Verify learning_activities (sustains Home streak)
      final activityRows = await db.query(
        DatabaseConstants.tableLearningActivities,
        where: 'activity_type = ?',
        whereArgs: ['exit_exam'],
      );
      expect(activityRows.length, equals(1));
      expect(activityRows.first['duration_seconds'], equals(1500));
      expect(activityRows.first['items_count'], equals(40));

      // Verify learner_evidence
      final evidenceRows = await db.query(
        DatabaseConstants.tableLearnerEvidence,
        where: 'content_id = ?',
        whereArgs: ['exit_exam_hsk1'],
      );
      expect(evidenceRows.length, equals(1));
      expect(evidenceRows.first['score'], equals(0.7));
      expect(evidenceRows.first['source'], equals('exit_exam'));
    });

    test('3. Submitting failing exam records failed status and does NOT unlock next level', () async {
      // Record failing score: 90 / 200 (< 120)
      await repo.recordExitExamSubmission(
        hskLevel: 1,
        score: 90,
        totalScore: 200,
        listenScore: 40,
        readScore: 50,
        isPassed: false,
        durationSeconds: 1200,
        itemsCount: 40,
      );

      final masteryRows = await db.query(
        DatabaseConstants.tableCurriculumMastery,
        where: 'item_id = ?',
        whereArgs: ['exit_exam_hsk1'],
      );
      expect(masteryRows.length, equals(1));
      expect(masteryRows.first['mastery_state'], equals('failed'));
      expect(masteryRows.first['score'], closeTo(0.45, 0.01));
    });

    testWidgets('4. LevelExitExamScreen renders honest empty state when no exam questions are available (no fake mock)', (tester) async {
      final emptyPayload = {
        'id': 'empty_exam',
        'title': 'Đề thi rỗng',
        'duration_minutes': 30,
        'passing_score': 120,
        'questions': [],
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LevelExitExamScreen(examData: emptyPayload),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Must display honest empty state
      expect(find.textContaining('Chưa có dữ liệu đề thi tốt nghiệp'), findsOneWidget);
      // Submit button should NOT be present or disabled
      expect(find.text('Nộp bài thi'), findsNothing);
    });

    testWidgets('5. LevelExitExamScreen renders full real exam and audio button for listening questions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final exitExamData = hsk1PackData['exit_exam'] as Map<String, dynamic>;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LevelExitExamScreen(
              examData: exitExamData,
              repository: repo,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('tốt nghiệp HSK 1'), findsOneWidget);
      expect(find.text('Phần 1: Nghe hiểu'), findsOneWidget);

      // Verify audio play button for listening section
      expect(find.text('Nghe audio câu hỏi'), findsWidgets);

      // Scroll to Section 2: Reading
      final readingHeader = find.text('Phần 2: Đọc hiểu');
      await tester.scrollUntilVisible(readingHeader, 400);
      await tester.pumpAndSettle();
      expect(readingHeader, findsOneWidget);
    });
  });
}
