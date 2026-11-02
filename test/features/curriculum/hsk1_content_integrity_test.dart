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

  group('Official HSK 1 Content Pack Integrity Tests', () {
    late File packFile;
    late Map<String, dynamic> packData;

    setUpAll(() async {
      packFile = File('assets/data/content_packs/hsk1/hsk1_pack_v1.json');
      expect(await packFile.exists(), isTrue, reason: 'hsk1_pack_v1.json must exist in assets');
      final raw = await packFile.readAsString();
      packData = json.decode(raw) as Map<String, dynamic>;
    });

    test('1. Manifest is valid for HSK 1 bundled pack', () {
      final manifest = packData['manifest'] as Map<String, dynamic>?;
      expect(manifest, isNotNull);
      expect(manifest!['pack_id'], 'hsk1_pack_v1');
      expect(manifest['hsk_level'], 1);
      expect(manifest['is_bundled'], isTrue);
      expect(manifest['version'], '1.0.0');
    });

    test('2. Curriculum syllabus has exactly 15 sequential lessons and 6 segments each', () {
      final curriculum = packData['curriculum'] as Map<String, dynamic>?;
      expect(curriculum, isNotNull);
      expect(curriculum!['hsk_level'], 1);

      final units = curriculum['units'] as List<dynamic>?;
      expect(units, isNotNull);
      expect(units!.isNotEmpty, isTrue);

      final allLessons = <Map<String, dynamic>>[];
      for (final u in units) {
        final lessons = (u as Map<String, dynamic>)['lessons'] as List<dynamic>? ?? [];
        for (final l in lessons) {
          allLessons.add(l as Map<String, dynamic>);
        }
      }

      // Exactly 15 official HSK 1 lessons
      expect(allLessons.length, 15);

      for (int i = 0; i < allLessons.length; i++) {
        final lesson = allLessons[i];
        expect(lesson['order_index'], i + 1);
        expect((lesson['title_vi'] as String).isNotEmpty, isTrue);
        expect((lesson['title_zh'] as String).isNotEmpty, isTrue);
        expect((lesson['pinyin'] as String).isNotEmpty, isTrue);

        final segments = lesson['segments'] as List<dynamic>? ?? [];
        expect(segments.length, 6, reason: 'Lesson ${i + 1} must have 6 pedagogical segments');
        final segmentTypes = segments.map((s) => s['segment_type']).toList();
        expect(segmentTypes, [
          'warmup',
          'vocabulary',
          'grammar',
          'dialogue',
          'practice',
          'mastery_check',
        ]);
      }
    });

    test('3. Content catalog contains 150 vocabulary words with Pinyin and Vietnamese meanings', () {
      final contentItems = packData['content_items'] as List<dynamic>? ?? [];
      final vocabItems = contentItems.where((i) => i['knowledge_type'] == 'vocabulary').toList();

      int totalWords = 0;
      final seenWords = <String>{};

      for (final item in vocabItems) {
        final content = json.decode(item['content_json'] as String) as Map<String, dynamic>;
        final words = content['words'] as List<dynamic>? ?? [];
        for (final w in words) {
          final word = w as Map<String, dynamic>;
          final simplified = word['simplified'] as String;
          expect(simplified.isNotEmpty, isTrue);
          expect((word['pinyin'] as String).isNotEmpty, isTrue);
          expect((word['meaning_vi'] as String).isNotEmpty, isTrue);
          seenWords.add(simplified);
          totalWords++;
        }
      }

      // Exactly 150 official HSK 1 vocabulary words
      expect(totalWords, 150);
      expect(seenWords.length, 150, reason: 'All 150 HSK 1 vocabulary items must be unique');
    });

    test('4. Exercise bank contains exactly 150 deterministic questions with official answer keys', () {
      final contentItems = packData['content_items'] as List<dynamic>? ?? [];
      final exerciseItems = contentItems.where((i) => i['knowledge_type'] == 'exercise').toList();

      expect(exerciseItems.length, 15, reason: '1 exercise item per lesson');
      int totalQuestions = 0;

      for (final item in exerciseItems) {
        final content = json.decode(item['content_json'] as String) as Map<String, dynamic>;
        final exercises = content['exercises'] as List<dynamic>? ?? [];
        expect(exercises.length, 10, reason: 'Each lesson must have exactly 10 deterministic exercises');

        for (final ex in exercises) {
          final e = ex as Map<String, dynamic>;
          expect((e['id'] as String).isNotEmpty, isTrue);
          expect((e['type'] as String).isNotEmpty, isTrue);
          expect((e['prompt'] as String).isNotEmpty, isTrue);
          expect(e['correct_answer'], isNotNull, reason: 'Question ${e['id']} must have a deterministic answer');
          expect((e['explanation'] as String).isNotEmpty, isTrue);
          totalQuestions++;
        }
      }

      expect(totalQuestions, 150);
    });

    test('5. Exit Exam has official HSK 1 structure (Listening 20 + Reading 20)', () {
      final exitExam = packData['exit_exam'] as Map<String, dynamic>?;
      expect(exitExam, isNotNull);
      expect(exitExam!['passing_score'], 120); // 120/200 standard HSK 1
      expect(exitExam['duration_minutes'], 35);

      final examData = json.decode(exitExam['exam_data_json'] as String) as Map<String, dynamic>;
      final sections = examData['sections'] as List<dynamic>?;
      expect(sections, isNotNull);
      expect(sections!.length, 2);

      final listening = sections[0] as Map<String, dynamic>;
      final reading = sections[1] as Map<String, dynamic>;

      expect(listening['name'], 'Listening');
      expect((listening['questions'] as List).length, 20);

      expect(reading['name'], 'Reading');
      expect((reading['questions'] as List).length, 20);
    });

    test('6. Complete database installation of official HSK 1 content pack', () async {
      final tempDir = await Directory.systemTemp.createTemp('hsk1_pack_db_');
      final dbPath = '${tempDir.path}/hsk1_real.db';
      final db = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );

      final loader = ContentPackLoader(db);
      final repo = CurriculumRepository(db);

      final rawJson = await packFile.readAsString();
      final installResult = await loader.loadPackFromJson(rawJson);

      expect(installResult.isSuccess, isTrue);
      expect(installResult.installedLessonsCount, 15);

      final curr = await repo.getCurriculumByLevel(1);
      expect(curr, isNotNull);

      final allLessons = await repo.getAllLessons(curr!.id);
      expect(allLessons.length, 15);
      expect(allLessons.first.segments.length, 6);

      await AppDatabase.instance.close();
      await tempDir.delete(recursive: true);
    });
  });
}
