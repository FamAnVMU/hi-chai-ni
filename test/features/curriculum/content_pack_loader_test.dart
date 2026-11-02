import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hi_chinese/core/database/app_database.dart';
import 'package:hi_chinese/features/curriculum/data/content_pack_loader.dart';
import 'package:hi_chinese/features/curriculum/data/curriculum_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('ContentPackLoader & CurriculumRepository Offline Tests', () {
    late Directory tempDir;
    late String dbPath;
    late Database db;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('pack_loader_test_');
      dbPath = '${tempDir.path}/test_pack.db';
      db = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );
    });

    tearDown(() async {
      await AppDatabase.instance.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    final mockPackJson = json.encode({
      'manifest': {
        'pack_id': 'pack_hsk1_v1',
        'hsk_level': 1,
        'version': '1.0.0',
        'title': 'Giáo trình chuẩn HSK 1',
        'description': '15 bài học sơ cấp tiếng Trung',
        'is_bundled': true,
        'size_bytes': 10240,
        'sha256': '',
      },
      'curriculum': {
        'id': 'curr_hsk1',
        'code': 'HSK_2012_L1',
        'standard_name': 'HSK 2.0 Level 1',
        'hsk_level': 1,
        'units': [
          {
            'id': 'unit_1',
            'order_index': 1,
            'title_vi': 'Chào hỏi',
            'title_zh': '问候',
            'description_vi': 'Lời chào và giới thiệu',
            'is_locked': false,
            'lessons': [
              {
                'id': 'lesson_1',
                'order_index': 1,
                'title_vi': 'Xin chào',
                'title_zh': '你好',
                'pinyin': 'Nǐ hǎo',
                'estimated_minutes': 15,
                'is_locked': false,
                'unlock_score_threshold': 0.8,
                'prerequisites': [],
                'segments': [
                  {
                    'id': 'seg_1_1',
                    'step_order': 1,
                    'segment_type': 'warmup',
                    'title': 'Khởi động',
                    'content_ref_id': 'WARMUP_L1',
                  },
                  {
                    'id': 'seg_1_2',
                    'step_order': 2,
                    'segment_type': 'vocabulary',
                    'title': 'Từ vựng',
                    'content_ref_id': 'VOCAB_L1',
                  },
                  {
                    'id': 'seg_1_3',
                    'step_order': 3,
                    'segment_type': 'grammar',
                    'title': 'Ngữ pháp',
                    'content_ref_id': 'GRAMMAR_L1',
                  },
                  {
                    'id': 'seg_1_4',
                    'step_order': 4,
                    'segment_type': 'dialogue',
                    'title': 'Hội thoại',
                    'content_ref_id': 'DIALOGUE_L1',
                  },
                  {
                    'id': 'seg_1_5',
                    'step_order': 5,
                    'segment_type': 'practice',
                    'title': 'Luyện tập',
                    'content_ref_id': 'PRACTICE_L1',
                  },
                  {
                    'id': 'seg_1_6',
                    'step_order': 6,
                    'segment_type': 'mastery_check',
                    'title': 'Kiểm tra hoàn thành',
                    'content_ref_id': 'MASTERY_L1',
                  },
                ],
              },
            ],
          },
        ],
      },
      'content_items': [
        {
          'content_id': 'VOCAB_L1',
          'curriculum_id': 'curr_hsk1',
          'hsk_level': 1,
          'knowledge_type': 'vocabulary',
          'title': 'Từ vựng Bài 1',
          'content_json': '{"words":[{"simplified":"你","pinyin":"nǐ","meaning_vi":"bạn"},{"simplified":"好","pinyin":"hǎo","meaning_vi":"tốt"}]}',
          'objectives': ['Nhớ cách phát âm và nghĩa của 你 và 好'],
          'source_reference': 'HSK 2.0 Standard Course',
        },
        {
          'content_id': 'PRACTICE_L1',
          'curriculum_id': 'curr_hsk1',
          'hsk_level': 1,
          'knowledge_type': 'exercise',
          'title': 'Bài tập Bài 1',
          'content_json': '{"exercises":[{"id":"ex1","type":"multiple_choice","prompt":"你好 nghĩa là gì?","options":["Xin chào","Tạm biệt"],"correct_answer":"Xin chào"}]}',
          'objectives': ['Luyện tập phản xạ chào hỏi'],
          'source_reference': 'HSK 2.0 Standard Course',
        },
      ],
      'exit_exam': {
        'id': 'exit_exam_hsk1',
        'curriculum_id': 'curr_hsk1',
        'hsk_level': 1,
        'title': 'Đề thi tổng kết cấp HSK 1',
        'passing_score': 120,
        'duration_minutes': 35,
        'exam_data_json': '{"sections":[{"name":"Listening","questions":20},{"name":"Reading","questions":20}]}',
      },
    });

    test('1. ContentPackLoader validates and installs content pack into database via Isolate', () async {
      final loader = ContentPackLoader(db);
      final repo = CurriculumRepository(db);

      // Compute actual SHA-256 for testing checksum verification
      final calculatedHash = ContentPackLoader.computeChecksum(mockPackJson);
      expect(calculatedHash.isNotEmpty, isTrue);

      final result = await loader.loadPackFromJson(mockPackJson);
      expect(result.isSuccess, isTrue);
      expect(result.packId, 'pack_hsk1_v1');
      expect(result.installedLessonsCount, 1);
      expect(result.installedContentItemsCount, 2);

      // Query through CurriculumRepository
      final curriculum = await repo.getCurriculumByLevel(1);
      expect(curriculum, isNotNull);
      expect(curriculum!.code, 'HSK_2012_L1');

      final units = await repo.getUnits(curriculum.id);
      expect(units.length, 1);
      expect(units.first.titleZh, '问候');

      final lessons = await repo.getLessons(units.first.id);
      expect(lessons.length, 1);
      expect(lessons.first.titleZh, '你好');
      expect(lessons.first.segments.length, 6);

      // Verify exit exam
      final exitExam = await repo.getExitExam(1);
      expect(exitExam, isNotNull);
      expect(exitExam!['passing_score'], 120);
    });

    test('2. ContentPackLoader is idempotent: re-installing updates rather than duplicates', () async {
      final loader = ContentPackLoader(db);
      final repo = CurriculumRepository(db);

      final r1 = await loader.loadPackFromJson(mockPackJson);
      expect(r1.isSuccess, isTrue);

      // Second install
      final r2 = await loader.loadPackFromJson(mockPackJson);
      expect(r2.isSuccess, isTrue);

      final curriculum = await repo.getCurriculumByLevel(1);
      final units = await repo.getUnits(curriculum!.id);
      expect(units.length, 1); // Exactly 1 unit, not duplicated!
    });
  });
}
