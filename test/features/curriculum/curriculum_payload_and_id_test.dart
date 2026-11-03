import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/dao/curriculum_dao.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/features/curriculum/data/curriculum_repository.dart';
import 'package:hi_chinese/features/curriculum/domain/models/curriculum_models.dart';
import 'package:hi_chinese/features/curriculum/presentation/screens/curriculum_syllabus_screen.dart';
import 'package:hi_chinese/features/curriculum/presentation/screens/lesson_study_screen.dart';
import 'package:hi_chinese/features/curriculum/presentation/widgets/lesson_content_empty_state.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;
  late CurriculumDao curriculumDao;
  late CurriculumRepository curriculumRepo;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath);

    // Setup minimal schema for curriculum and content items
    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableCurriculums} (
        id TEXT PRIMARY KEY,
        pack_id TEXT,
        code TEXT,
        standard_name TEXT,
        hsk_level INTEGER,
        total_units INTEGER DEFAULT 0,
        total_lessons INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableCurriculumUnits} (
        id TEXT PRIMARY KEY,
        curriculum_id TEXT,
        order_index INTEGER,
        title_vi TEXT,
        title_zh TEXT,
        description_vi TEXT,
        icon_name TEXT,
        is_locked INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableCurriculumLessons} (
        id TEXT PRIMARY KEY,
        unit_id TEXT,
        order_index INTEGER,
        title_vi TEXT,
        title_zh TEXT,
        pinyin TEXT,
        estimated_minutes INTEGER DEFAULT 15,
        is_locked INTEGER DEFAULT 0,
        unlock_score_threshold REAL DEFAULT 0.8,
        prerequisites_json TEXT,
        status TEXT DEFAULT 'not_started',
        completed_at TEXT,
        credited_reason TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableLessonSegments} (
        id TEXT PRIMARY KEY,
        lesson_id TEXT,
        step_order INTEGER,
        segment_type TEXT,
        title TEXT,
        content_ref_id TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseConstants.tableContentItems} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        content_id TEXT UNIQUE,
        curriculum_id TEXT,
        hsk_level INTEGER,
        knowledge_type TEXT,
        title TEXT,
        content_json TEXT,
        objectives_json TEXT,
        source_reference TEXT,
        audit_status TEXT,
        content_version TEXT,
        metadata_json TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    curriculumDao = CurriculumDao(db);
    curriculumRepo = CurriculumRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('P0_02 Curriculum Content Payload & ID Tests', () {
    test('1. CurriculumDao.getSegmentsByLessonId returns segment with content_payload via LEFT JOIN', () async {
      // Insert sample segment and matching content item
      await db.insert(DatabaseConstants.tableLessonSegments, {
        'id': 'seg_1_1',
        'lesson_id': 'lesson_1_1',
        'step_order': 1,
        'segment_type': 'warmup',
        'title': 'Khởi động',
        'content_ref_id': 'WARMUP_L1',
      });

      final warmupContent = {
        'objective': 'Làm quen với chào hỏi',
        'starter_question': 'Bạn đã biết cách chào chưa?',
      };

      await db.insert(DatabaseConstants.tableContentItems, {
        'content_id': 'WARMUP_L1',
        'curriculum_id': CurriculumConstants.currHsk1,
        'hsk_level': 1,
        'knowledge_type': 'warmup',
        'title': 'Dẫn nhập bài 1',
        'content_json': json.encode(warmupContent),
      });

      final segments = await curriculumDao.getSegmentsByLessonId('lesson_1_1');
      expect(segments.length, equals(1));
      expect(segments.first['content_ref_id'], equals('WARMUP_L1'));
      expect(segments.first['content_payload'], isNotNull);

      final segmentModel = LessonSegment.fromMap(segments.first);
      expect(segmentModel.contentPayload, isNotNull);
      expect(segmentModel.contentPayload!['objective'], equals('Làm quen với chào hỏi'));
    });

    test('2. CurriculumDao.getSegmentsByLessonId safely handles missing content_items (LEFT JOIN NULL)', () async {
      // Segment with ref ID that does not exist in content_items
      await db.insert(DatabaseConstants.tableLessonSegments, {
        'id': 'seg_1_6',
        'lesson_id': 'lesson_1_1',
        'step_order': 6,
        'segment_type': 'mastery_check',
        'title': 'Kiểm tra hoàn thành',
        'content_ref_id': 'MASTERY_L1_ORPHAN',
      });

      final segments = await curriculumDao.getSegmentsByLessonId('lesson_1_1');
      expect(segments.length, equals(1));
      expect(segments.first['content_payload'], isNull);

      final segmentModel = LessonSegment.fromMap(segments.first);
      expect(segmentModel.contentPayload, isNull);
      expect(segmentModel.segmentType, equals('mastery_check'));
    });

    test('3. LessonSegment.fromMap handles both String JSON and decoded Map payloads', () {
      final mapWithStringPayload = {
        'id': 'seg_1',
        'lesson_id': 'l1',
        'step_order': 1,
        'segment_type': 'vocabulary',
        'title': 'Từ vựng',
        'content_payload': json.encode({'words': [{'hanzi': '你'}]}),
      };

      final segmentFromString = LessonSegment.fromMap(mapWithStringPayload);
      expect(segmentFromString.contentPayload, isNotNull);
      expect(segmentFromString.contentPayload!['words'], isA<List>());

      final mapWithMapPayload = {
        'id': 'seg_2',
        'lesson_id': 'l1',
        'step_order': 2,
        'segment_type': 'vocabulary',
        'title': 'Từ vựng',
        'content_payload': {'words': [{'hanzi': '好'}]},
      };

      final segmentFromMap = LessonSegment.fromMap(mapWithMapPayload);
      expect(segmentFromMap.contentPayload, isNotNull);
      expect(segmentFromMap.contentPayload!['words'], isA<List>());
    });

    test('4. CurriculumConstants verifies canonical IDs and level conversions', () {
      expect(CurriculumConstants.currHsk1, equals('curr_hsk1'));
      expect(CurriculumConstants.currHsk2, equals('curr_hsk2'));
      expect(CurriculumConstants.curriculumIdForLevel(1), equals('curr_hsk1'));
      expect(CurriculumConstants.curriculumIdForLevel(6), equals('curr_hsk6'));
      expect(CurriculumConstants.levelFromCurriculumId('curr_hsk1'), equals(1));
      expect(CurriculumConstants.levelFromCurriculumId('curr_hsk2'), equals(2));
      expect(CurriculumConstants.levelFromCurriculumId('invalid_id'), isNull);
    });

    test('5. CurriculumRepository.getUnits with non-existent curriculum ID returns empty list gracefully', () async {
      final units = await curriculumRepo.getUnits('non_existent_curriculum_id');
      expect(units, isEmpty);
    });

    testWidgets('6. CurriculumSyllabusScreen defaults to curr_hsk1 and renders provided units', (tester) async {
      const defaultScreen = CurriculumSyllabusScreen();
      expect(defaultScreen.curriculumId, equals('curr_hsk1'));

      final unit = CurriculumUnit(
        id: 'u1',
        curriculumId: CurriculumConstants.currHsk1,
        orderIndex: 1,
        titleVi: 'Phần 1: Chào hỏi',
        titleZh: '第一部分',
        lessons: [
          const CurriculumLesson(
            id: 'l1',
            unitId: 'u1',
            orderIndex: 1,
            titleVi: 'Xin chào',
            titleZh: '你好',
            pinyin: 'nǐ hǎo',
            isLocked: false,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: CurriculumSyllabusScreen(
              units: [unit],
            ),
          ),
        ),
      );

      expect(find.text('Phần 1: Chào hỏi'), findsOneWidget);
      expect(find.text('Bài 1: Xin chào'), findsOneWidget);
    });

    testWidgets('7. LessonStudyScreen displays graceful empty state when contentPayload is missing', (tester) async {
      // Lesson where segment has no contentPayload (e.g. orphan segment)
      const emptySegment = LessonSegment(
        id: 'seg_vocab_empty',
        lessonId: 'l_empty',
        stepOrder: 2,
        segmentType: 'vocabulary',
        title: 'Từ vựng mới',
        contentPayload: null,
      );

      final lesson = CurriculumLesson(
        id: 'l_empty',
        unitId: 'u1',
        orderIndex: 1,
        titleVi: 'Bài học kiểm thử',
        titleZh: '测试课',
        pinyin: 'cèshì kè',
        isLocked: false,
        segments: [
          const LessonSegment(
            id: 'seg_warmup',
            lessonId: 'l_empty',
            stepOrder: 1,
            segmentType: 'warmup',
            title: 'Khởi động',
          ),
          emptySegment,
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LessonStudyScreen(lesson: lesson),
          ),
        ),
      );

      // Initially on Step 1 (Khởi động)
      expect(find.text('Khởi Động Bài Học'), findsOneWidget);

      // Tap "Tiếp theo" in bottom navigation to move to Step 2 (Từ vựng)
      await tester.tap(find.text('Tiếp theo'));
      await tester.pumpAndSettle();

      // Step 2 should display LessonContentEmptyState rather than crashing or showing a blank screen
      expect(find.byType(LessonContentEmptyState), findsOneWidget);
      expect(find.text('Nội dung từ vựng đang được chuẩn bị'), findsOneWidget);
      expect(find.text('Tiếp tục bài học'), findsOneWidget);
    });

    testWidgets('8. LessonStudyScreen allows user to proceed through empty state without being stuck', (tester) async {
      const emptyVocab = LessonSegment(
        id: 'seg_vocab',
        lessonId: 'l_flow',
        stepOrder: 2,
        segmentType: 'vocabulary',
        title: 'Từ vựng mới',
      );

      final lesson = CurriculumLesson(
        id: 'l_flow',
        unitId: 'u1',
        orderIndex: 1,
        titleVi: 'Bài học kiểm thử luồng',
        titleZh: '测试课',
        pinyin: 'cèshì kè',
        isLocked: false,
        segments: [
          const LessonSegment(
            id: 'seg_warmup',
            lessonId: 'l_flow',
            stepOrder: 1,
            segmentType: 'warmup',
            title: 'Khởi động',
          ),
          emptyVocab,
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: LessonStudyScreen(lesson: lesson),
          ),
        ),
      );

      // Advance to step 2
      await tester.tap(find.text('Tiếp theo'));
      await tester.pumpAndSettle();

      expect(find.text('Nội dung từ vựng đang được chuẩn bị'), findsOneWidget);

      // Advance past the empty state using bottom navigation
      await tester.tap(find.text('Tiếp theo'));
      await tester.pumpAndSettle();

      // User has successfully progressed past the empty state to step 3 (Ngữ pháp)
      expect(find.text('Nội dung ngữ pháp đang được chuẩn bị'), findsOneWidget);
    });

    testWidgets('9. LessonContentEmptyState triggers onAction callback when button is tapped', (tester) async {
      bool actionCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: LessonContentEmptyState(
              title: 'Nội dung đang chuẩn bị',
              message: 'Vui lòng quay lại sau.',
              buttonText: 'Hành động tiếp tục',
              onAction: () {
                actionCalled = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Nội dung đang chuẩn bị'), findsOneWidget);
      expect(find.text('Hành động tiếp tục'), findsOneWidget);

      final button = find.widgetWithText(HiButton, 'Hành động tiếp tục');
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(actionCalled, isTrue);
    });
  });
}
