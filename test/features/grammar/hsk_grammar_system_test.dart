import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/features/grammar/domain/engine/grammar_exercise_generator.dart';
import 'package:hi_chinese/features/grammar/grammar.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late Directory tempDir;
  late DefaultGrammarRepository repository;
  const evaluationEngine = GrammarEvaluationEngine();
  final exerciseGenerator = GrammarExerciseGenerator();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hsk_grammar_test_');
    final dbPath = '${tempDir.path}/test_hsk_grammar.db';
    db = await databaseFactory.openDatabase(dbPath);

    final engine = MigrationEngine();
    await engine.executeMigrations(db, 0, DatabaseConstants.currentDatabaseVersion);

    repository = DefaultGrammarRepository(db);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('HSK Grammar System & Schema v13 Tests', () {
    test('1. Migration v13 creates grammar_examples and grammar_topics tables with correct schema', () async {
      // Check grammar_items table info
      final itemsInfo = await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableGrammarItems})');
      final colNames = itemsInfo.map((r) => r['name'] as String).toSet();

      expect(colNames.contains('grammar_id'), isTrue);
      expect(colNames.contains('topic_category'), isTrue);
      expect(colNames.contains('hsk_level_mapped'), isTrue);
      expect(colNames.contains('mapping_basis'), isTrue);
      expect(colNames.contains('source'), isTrue);
      expect(colNames.contains('license'), isTrue);
      expect(colNames.contains('attribution'), isTrue);

      // Check grammar_examples table info
      final exInfo = await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableGrammarExamples})');
      final exCols = exInfo.map((r) => r['name'] as String).toSet();
      expect(exCols.contains('chinese'), isTrue);
      expect(exCols.contains('pinyin'), isTrue);
      expect(exCols.contains('translation_en'), isTrue);
      expect(exCols.contains('translation_vi'), isTrue);

      // Check grammar_topics table info and initial seed
      final topics = await repository.getGrammarTopics();
      expect(topics, isNotEmpty);
      expect(topics.any((t) => t.code == 'particle'), isTrue);
      expect(topics.any((t) => t.code == 'preposition'), isTrue);
      expect(topics.any((t) => t.code == 'comparison'), isTrue);
      expect(topics.any((t) => t.code == 'ba_sentence'), isTrue);
    });

    test('2. Ingests and queries normalized HSK grammar items and examples without data loss', () async {
      final sampleItems = [
        {
          'id': 'GUSHI_HSK1_001',
          'grammar_id': 'GUSHI_HSK1_001',
          'hsk_level': 1,
          'code': 'HSK3_1_001',
          'title': '前缀“第-”',
          'structure': '第＋数词',
          'explanation_vi': 'Tiền tố 第- đứng trước số từ tạo thành số thứ tự.',
          'topic_category': 'word_part',
          'topic_name_vi': 'Ngữ tố (语素)',
          'source': 'Gushi App / HSK 3.0 Syllabus (GF0025-2021)',
          'license': 'CC BY-SA 4.0',
          'attribution': 'HSK 3.0 syllabus data by Gushi, CC BY-SA 4.0',
          'examples': [
            {
              'chinese': '今天是我上班的第一天。',
              'chinese_segmented': '今天 是 我 上班 的 第一 天 。',
              'pinyin': 'jīntiān shì wǒ shàngbān de dì-yī tiān .',
              'translation_en': 'Today is my first day at work.',
              'translation_vi': 'Hôm nay là ngày đầu tiên tôi đi làm.',
            }
          ]
        },
        {
          'id': 'CGW_ASG846EA',
          'grammar_id': 'CGW_ASG846EA',
          'hsk_level': 1,
          'code': 'CGW_ASG846EA',
          'title': 'Expressing actions in progress with "zai"',
          'structure': '(正)在 + Verb',
          'explanation_vi': 'Diễn tả hành động đang diễn ra trong hiện tại.',
          'topic_category': 'particle',
          'topic_name_vi': 'Trợ từ (助词)',
          'source': 'AllSet Learning Chinese Grammar Wiki',
          'license': 'CC BY-SA 3.0',
          'attribution': 'Chinese Grammar Wiki by AllSet Learning, CC BY-SA 3.0',
          'examples': [
            {
              'chinese': '她在看书。',
              'chinese_segmented': '她 在 看 书 。',
              'pinyin': 'tā zài kàn shū .',
              'translation_en': 'She is reading.',
              'translation_vi': 'Cô ấy đang đọc sách.',
            }
          ]
        }
      ];

      await repository.importGrammarDataset(sampleItems);

      // Verify item retrieval
      final gushiItem = await repository.getGrammarItemById('GUSHI_HSK1_001');
      expect(gushiItem, isNotNull);
      expect(gushiItem!.title, '前缀“第-”');
      expect(gushiItem.structure, '第＋数词');
      expect(gushiItem.topicCategory, 'word_part');
      expect(gushiItem.source, contains('Gushi'));
      expect(gushiItem.license, 'CC BY-SA 4.0');
      expect(gushiItem.examples, hasLength(1));
      expect(gushiItem.examples.first.hanzi, '今天是我上班的第一天。');

      // Verify relational examples querying
      final relationalExamples = await repository.getExamplesForGrammar('CGW_ASG846EA');
      expect(relationalExamples, hasLength(1));
      expect(relationalExamples.first.pinyin, 'tā zài kàn shū .');
      expect(relationalExamples.first.translationVi, 'Cô ấy đang đọc sách.');

      // Verify topic filtering
      final particleItems = await repository.getGrammarItems(topicCategory: 'particle');
      expect(particleItems.any((i) => i.id == 'CGW_ASG846EA'), isTrue);

      final wordPartItems = await repository.getGrammarItems(topicCategory: 'word_part');
      expect(wordPartItems.any((i) => i.id == 'GUSHI_HSK1_001'), isTrue);
    });

    test('3. GrammarExerciseGenerator produces verifiable pedagogical exercises', () async {
      final sampleItem = GrammarItem(
        id: 'TEST_GRM_ZAI',
        hskLevel: 1,
        code: 'TEST_ZAI',
        title: 'Expressing actions in progress with "zai"',
        structure: 'Subj. + 在 + Verb + Obj.',
        meaningVi: 'Diễn đạt hành động đang tiếp diễn',
        usageConditionsVi: 'Đứng trước động từ',
        sentencePositionVi: 'Trước vị ngữ',
        explanationVi: 'Đặt 在 trước động từ để biểu thị hành động đang diễn ra.',
        topicCategory: 'particle',
        topicNameVi: 'Trợ từ',
        examples: const [
          GrammarExample(
            hanzi: '他在看书。',
            chineseSegmented: '他 在 看 书 。',
            pinyin: 'tā zài kàn shū .',
            translationVi: 'Anh ấy đang đọc sách.',
            translationEn: 'He is reading a book.',
          )
        ],
        createdAt: DateTime.now().toUtc(),
        updatedAt: DateTime.now().toUtc(),
      );

      final exercises = exerciseGenerator.generateExercises(sampleItem);
      expect(exercises, isNotEmpty);
      expect(exercises.length, greaterThanOrEqualTo(3));

      // 1. Structure selection exercise
      final structEx = exercises.firstWhere((e) => e.type == GrammarExerciseType.multipleChoice);
      expect(structEx.options, contains('Subj. + 在 + Verb + Obj.'));
      expect(structEx.correctAnswerIndex, isNotNull);
      final evalChoice = evaluationEngine.evaluate(
        exercise: structEx,
        selectedOptionIndex: structEx.correctAnswerIndex,
      );
      expect(evalChoice.isCorrect, isTrue);
      expect(evalChoice.score, 1.0);

      // 2. Fill in the blank exercise
      final fillEx = exercises.firstWhere((e) => e.type == GrammarExerciseType.fillInBlank);
      expect(fillEx.sentenceWithBlank, contains(' ( ___ ) '));
      expect(fillEx.options, contains('在'));
      final evalFill = evaluationEngine.evaluate(
        exercise: fillEx,
        selectedOptionIndex: fillEx.correctAnswerIndex,
      );
      expect(evalFill.isCorrect, isTrue);

      // 3. Reorder words exercise
      final reorderEx = exercises.firstWhere((e) => e.type == GrammarExerciseType.reorderWords);
      expect(reorderEx.shuffledTokens, isNotEmpty);
      final evalReorder = evaluationEngine.evaluate(
        exercise: reorderEx,
        orderedTokens: ['他', '在', '看', '书'],
      );
      expect(evalReorder.isCorrect, isTrue);
      expect(evalReorder.score, 1.0);
    });

    test('4. Preserves user learning progress decoupled from content pack updates', () async {
      const grmId = 'GUSHI_HSK1_001';

      // 0. Ensure item exists
      await repository.importGrammarDataset([
        {
          'id': grmId,
          'grammar_id': grmId,
          'hsk_level': 1,
          'code': 'HSK3_1_001',
          'title': '前缀“第-”',
          'structure': '第＋数词',
          'explanation_vi': 'Tiền tố 第- đứng trước số từ tạo thành số thứ tự.',
          'topic_category': 'word_part',
          'topic_name_vi': 'Ngữ tố (语素)',
          'source': 'Gushi App / HSK 3.0 Syllabus',
          'license': 'CC BY-SA 4.0',
          'attribution': 'HSK 3.0 syllabus data by Gushi',
          'examples': []
        }
      ]);

      // 1. Record study progress
      await repository.recordStudySession(
        grammarId: grmId,
        score: 0.95,
        durationSeconds: 150,
        exercisesCount: 4,
      );

      final beforeProgress = await repository.getProgress(grmId);
      expect(beforeProgress, isNotNull);
      expect(beforeProgress!.status, GrammarProgressStatus.mastered);
      expect(beforeProgress.exercisesCompleted, 4);

      // 2. Re-import/update content pack for that grammar point
      await repository.importGrammarDataset([
        {
          'id': grmId,
          'grammar_id': grmId,
          'hsk_level': 1,
          'code': 'HSK3_1_001',
          'title': '前缀“第-” (Updated Version)',
          'structure': '第＋数词',
          'explanation_vi': 'Bản cập nhật giải thích chi tiết hơn.',
          'topic_category': 'word_part',
          'topic_name_vi': 'Ngữ tố (语素)',
          'source': 'Gushi App / HSK 3.0 Syllabus',
          'license': 'CC BY-SA 4.0',
          'attribution': 'HSK 3.0 syllabus data by Gushi',
          'examples': []
        }
      ]);

      // 3. Verify user progress was NOT wiped or affected!
      final afterProgress = await repository.getProgress(grmId);
      expect(afterProgress, isNotNull);
      expect(afterProgress!.status, GrammarProgressStatus.mastered);
      expect(afterProgress.exercisesCompleted, 4);
      expect(afterProgress.masteryScore, 0.95);

      // Content item itself was updated
      final updatedItem = await repository.getGrammarItemById(grmId);
      expect(updatedItem!.title, '前缀“第-” (Updated Version)');
    });
  });
}
