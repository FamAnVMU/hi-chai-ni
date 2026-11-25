import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/features/grammar/grammar.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Wave 2 Grammar: Batch Import, SQLite Filtering & 320dp Overflow Guard', () {
    late Directory tempDir;
    late Database db;
    late DefaultGrammarRepository repo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('wave2_grammar_test_');
      db = await databaseFactory.openDatabase('${tempDir.path}/grammar.db');
      await MigrationEngine().executeMigrations(db, 0, DatabaseConstants.currentDatabaseVersion);
      repo = DefaultGrammarRepository(db);
    });

    tearDown(() async {
      await db.close();
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('PERF-03 & RISK-02: batch import is idempotent, skips heavy JSON on list queries, and loads examples on detail',
        () async {
      final rawItems = [
        {
          'id': 'G_BATCH_1',
          'grammar_id': 'G_BATCH_1',
          'hsk_level': 1,
          'code': 'GB1',
          'title': 'Cấu trúc 是...的',
          'structure': '是 + thành phần nhấn mạnh + 的',
          'meaning_vi': 'Nhấn mạnh thời gian, địa điểm hoặc cách thức',
          'topic_category': 'special_sentence',
          'tags': ['nhấn_mạnh'],
          'examples': [
            {
              'chinese': '我是昨天来的。',
              'pinyin': 'Wǒ shì zuótiān lái de.',
              'translation_vi': 'Tôi đến vào hôm qua.',
            }
          ],
          'exercises_json': [
            {
              'id': 'ex1',
              'type': 'multipleChoice',
              'prompt': 'Chọn đáp án đúng',
              'options': ['是', '有'],
              'correct_answer_index': 0,
              'target_sentence': '我是昨天来的。',
              'explanation_vi': 'Dùng 是.',
            }
          ],
        },
        {
          'id': 'G_BATCH_2',
          'grammar_id': 'G_BATCH_2',
          'hsk_level': 3,
          'code': 'GB2',
          'title': 'Câu chữ 把 cơ bản',
          'structure': 'Chủ ngữ + 把 + Tân ngữ + Động từ + Bổ ngữ',
          'meaning_vi': 'Xử lý tác động lên đối tượng xác định',
          'topic_category': 'ba_sentence',
          'tags': ['bả'],
        },
      ];

      await repo.importGrammarDataset(rawItems);
      await repo.importGrammarDataset(rawItems); // Re-import must not duplicate examples

      final exampleRows = await db.query(
        DatabaseConstants.tableGrammarExamples,
        where: 'grammar_id = ?',
        whereArgs: ['G_BATCH_1'],
      );
      expect(exampleRows, hasLength(1));

      // Lightweight list search uses SQLite filter + omits heavy JSON payloads
      final summaryResults = await repo.getGrammarItems(query: 'Câu chữ 把 cơ bản');
      expect(summaryResults, hasLength(1));
      expect(summaryResults.first.id, equals('G_BATCH_2'));
      expect(summaryResults.first.examples, isEmpty);

      final hanziSearchResults = await repo.getGrammarItems(query: '把');
      expect(hanziSearchResults.any((item) => item.id == 'G_BATCH_2'), isTrue);
      expect(hanziSearchResults.every((item) => item.examples.isEmpty), isTrue);

      final summaryForItem1 = await repo.getGrammarItems(hskLevel: 1, tag: 'nhấn_mạnh');
      expect(summaryForItem1, hasLength(1));
      expect(summaryForItem1.first.examples, isEmpty);
      expect(summaryForItem1.first.exercises, isEmpty);

      // Detail query still decodes relational examples and full JSON
      final detail = await repo.getGrammarItemById('G_BATCH_1');
      expect(detail, isNotNull);
      expect(detail!.examples, hasLength(1));
      expect(detail.exercises, hasLength(1));
    });

    testWidgets('AUD-048: GrammarExerciseWidget renders long options cleanly without overflow at 320dp',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const exercise = GrammarExercise(
        id: 'ex_overflow',
        type: GrammarExerciseType.multipleChoice,
        prompt: 'Chọn câu diễn đạt đúng ngữ pháp HSK 3:',
        options: [
          '他把昨天买的苹果放在桌子上面了，现在看起来非常新鲜。',
          '他放在桌子上面了把昨天买的苹果。',
        ],
        correctAnswerIndex: 0,
        targetSentence: '他把昨天买的苹果放在桌子上面了。',
        explanationVi: '把 đứng trước tân ngữ xác định.',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: GrammarExerciseWidget(
                exercise: exercise,
                exerciseIndex: 0,
                onEvaluated: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
