import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/core/knowledge/knowledge.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Master Data Integration & Unified Knowledge System Tests', () {
    late Database db;
    late DefaultUnifiedKnowledgeService knowledgeService;

    setUp(() async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath);

      // Run full migration suite up to v15
      final engine = MigrationEngine();
      await engine.executeMigrations(db, 0, 15);

      knowledgeService = DefaultUnifiedKnowledgeService(db);

      final now = DateTime.now().toUtc().toIso8601String();

      // Seed Vocabularies
      await db.insert(DatabaseConstants.tableVocabularies, {
        'id': 'voc_hsk1_001',
        'simplified': '学习',
        'traditional': '學習',
        'pinyin': 'xué xí',
        'pinyin_clean': 'xuexi',
        'pinyin_numeric': 'xue2xi2',
        'hanviet': 'học tập',
        'hsk_level': 1,
        'stroke_count': 11,
        'source': 'clem109;CVDICT',
        'license': 'MIT',
        'created_at': now,
        'updated_at': now,
      });

      await db.insert(DatabaseConstants.tableVocabularySenses, {
        'id': 'sns_voc_hsk1_001_1',
        'vocabulary_id': 'voc_hsk1_001',
        'part_of_speech': 'verb',
        'meaning_vi': 'học, học tập',
        'meaning_en': 'to study, to learn',
        'source': 'CC-CEDICT',
        'order_index': 1,
        'created_at': now,
        'updated_at': now,
      });

      // Seed Hanzi Characters with SVG stroke data
      await db.insert(DatabaseConstants.tableHanziCharacters, {
        'id': 'char_5b66',
        'character': '学',
        'stroke_count': 8,
        'hsk_level': 1,
        'pinyin': 'xué',
        'hanviet': 'học',
        'meaning_vi': 'học',
        'definition_en': 'learning, science',
        'radical': '子',
        'decomposition': '⿱⺌子',
        'strokes_json': jsonEncode([
          'M 400 200 L 450 250',
          'M 500 180 L 520 230',
          'M 300 350 L 700 350',
          'M 500 350 L 500 800',
        ]),
        'medians_json': jsonEncode([
          [[400, 200], [450, 250]],
          [[500, 180], [520, 230]],
          [[300, 350], [700, 350]],
          [[500, 350], [500, 800]],
        ]),
        'source': 'Make Me a Hanzi',
        'license': 'Arphic Public License / OFL',
        'created_at': now,
        'updated_at': now,
      });

      await db.insert(DatabaseConstants.tableHanziCharacters, {
        'id': 'char_4e60',
        'character': '习',
        'stroke_count': 3,
        'hsk_level': 1,
        'pinyin': 'xí',
        'hanviet': 'tập',
        'meaning_vi': 'tập, thực hành',
        'strokes_json': jsonEncode(['M 200 200 L 500 200', 'M 350 200 L 350 700', 'M 200 700 L 500 700']),
        'medians_json': jsonEncode([
          [[200, 200], [500, 200]],
          [[350, 200], [350, 700]],
          [[200, 700], [500, 700]],
        ]),
        'source': 'Make Me a Hanzi',
        'license': 'Arphic Public License / OFL',
        'created_at': now,
        'updated_at': now,
      });

      // Seed Grammar Item
      await db.insert(DatabaseConstants.tableGrammarItems, {
        'id': 'gram_as_a1_001',
        'grammar_id': 'as_a1_001',
        'code': 'as_a1_001',
        'title': 'Cấu trúc câu với 在 biểu thị hành động đang diễn ra',
        'title_vi': 'Cấu trúc câu với 在 biểu thị hành động đang diễn ra',
        'pattern': 'Subj. + 在 + Verb + Obj.',
        'structure': 'Subj. + 在 + Verb + Obj.',
        'explanation_vi': 'Dùng 在 trước động từ để biểu thị hành động đang diễn ra.',
        'examples_json': '[]',
        'topic_category': 'aspect',
        'hsk_level': 1,
        'hsk_level_mapped': 1,
        'original_level': 'A1',
        'verification_status': 'verified_open_source',
        'license': 'CC BY-NC-SA 3.0',
        'attribution': 'AllSet Learning',
        'created_at': now,
        'updated_at': now,
      });

      await db.insert(DatabaseConstants.tableGrammarExamples, {
        'grammar_id': 'gram_as_a1_001',
        'chinese': '我在学习汉语。',
        'pinyin': 'wǒ zài xué xí hàn yǔ',
        'translation_vi': 'Tôi đang học tiếng Trung.',
        'translation_en': 'I am studying Chinese.',
        'source': 'AllSet Learning',
        'order_index': 1,
        'created_at': now,
      });

      // Seed Sentence & Audio
      await db.insert(DatabaseConstants.tableSentences, {
        'id': 'tat_1001',
        'chinese': '我在学习汉语。',
        'pinyin': 'wǒ zài xué xí hàn yǔ',
        'translation_vi': 'Tôi đang học tiếng Trung.',
        'translation_en': 'I am studying Chinese.',
        'hsk_level': 1,
        'tokens_json': jsonEncode([
          {'word': '我', 'pinyin': 'wǒ', 'meaningVi': 'tôi', 'hskLevel': 1},
          {'word': '在', 'pinyin': 'zài', 'meaningVi': 'đang', 'hskLevel': 1},
          {'word': '学习', 'pinyin': 'xué xí', 'meaningVi': 'học tập', 'hskLevel': 1},
          {'word': '汉语', 'pinyin': 'hàn yǔ', 'meaningVi': 'tiếng Trung', 'hskLevel': 1},
        ]),
        'matched_vocab_ids_json': jsonEncode(['voc_hsk1_001']),
        'grammar_tags_json': jsonEncode(['在 (ongoing action)']),
        'has_human_audio': 1,
        'source': 'Tatoeba Project',
        'license': 'CC BY 2.0 FR',
        'created_at': now,
        'updated_at': now,
      });

      await db.insert(DatabaseConstants.tableSentenceAudio, {
        'id': 'aud_tat_1001',
        'sentence_id': 'tat_1001',
        'audio_type': 'humanRecording',
        'speaker_name': 'fucongcong',
        'license': 'CC BY-NC 4.0',
        'url_remote': 'https://tatoeba.org/audio/download/1001',
        'status': 'local',
        'local_path': '/storage/audio/1001.mp3',
        'created_at': now,
      });
    });

    tearDown(() async {
      await db.close();
    });

    test('Test A: Vocabulary Details links constituent Hanzi strokes and sentences with audio', () async {
      final details = await knowledgeService.getVocabularyDetails('学习');
      expect(details, isNotNull);
      expect(details!.entry.simplified, '学习');
      expect(details.entry.hanviet, 'học tập');

      // Check constituent Hanzi characters linkage
      expect(details.constituentCharacters.length, 2);
      expect(details.constituentCharacters[0].character, '学');
      expect(details.constituentCharacters[0].strokeCount, 8);
      expect(details.constituentCharacters[0].strokes.length, 4);
      expect(details.constituentCharacters[1].character, '习');
      expect(details.constituentCharacters[1].strokeCount, 3);
      expect(details.hasStrokesData, isTrue);

      // Check example sentences containing this word
      expect(details.exampleSentences.length, 1);
      expect(details.exampleSentences[0].chinese, '我在学习汉语。');
      expect(details.exampleSentences[0].hasHumanAudio, isTrue);
      expect(details.hasAudioExamples, isTrue);
    });

    test('Test B: Grammar Details links explanation, examples, and corpus sentences', () async {
      final details = await knowledgeService.getGrammarDetails('gram_as_a1_001');
      expect(details, isNotNull);
      expect(details!.item.structure, 'Subj. + 在 + Verb + Obj.');
      expect(details.item.hskLevelMapped, 1);
      expect(details.item.attribution, 'AllSet Learning');
      expect(details.item.examples.length, 1);
      expect(details.item.examples[0].hanzi, '我在学习汉语。');
    });

    test('Test C: Hanzi Character Details links vector stroke order and parent vocabulary', () async {
      final details = await knowledgeService.getHanziDetails('学');
      expect(details, isNotNull);
      expect(details!.character.character, '学');
      expect(details.character.radical, '子');
      expect(details.character.decomposition, '⿱⺌子');
      expect(details.character.strokes.isNotEmpty, isTrue);
      expect(details.character.medians.isNotEmpty, isTrue);

      // Check linked vocabulary containing this character
      expect(details.vocabularyWords.any((v) => v.simplified == '学习'), isTrue);

      // Check linked sentence containing this character
      expect(details.exampleSentences.any((s) => s.chinese.contains('学')), isTrue);
    });

    test('Test D: Sentence Details links tokens, Hanzi characters, and audio recordings', () async {
      final details = await knowledgeService.getSentenceDetails('tat_1001');
      expect(details, isNotNull);
      expect(details!.sentence.chinese, '我在学习汉语。');
      expect(details.sentence.translationVi, 'Tôi đang học tiếng Trung.');
      expect(details.sentence.hasHumanAudio, isTrue);

      // Token word check
      expect(details.constituentWords.any((w) => w.simplified == '学习'), isTrue);

      // Constituent characters check
      expect(details.constituentCharacters.any((c) => c.character == '学'), isTrue);
      expect(details.constituentCharacters.any((c) => c.character == '习'), isTrue);
    });

    test('Test E: Knowledge Registry Synchronization registers all 4 domains idempotently', () async {
      final report = await knowledgeService.syncAllEntitiesToKnowledgeRegistry();
      expect(report.vocabulariesRegistered, 1);
      expect(report.grammarRegistered, 1);
      expect(report.hanziRegistered, 2);
      expect(report.sentencesRegistered, 1);
      expect(report.totalRegistered, 5);

      // Verify records in knowledge_registry table
      final rows = await db.query(DatabaseConstants.tableKnowledgeRegistry);
      expect(rows.length, 5);
      final types = rows.map((r) => r['entity_type'] as String).toSet();
      expect(types, containsAll(['vocabulary', 'grammar', 'hanzi', 'sentence']));

      // Re-running sync must be idempotent (zero duplication)
      final report2 = await knowledgeService.syncAllEntitiesToKnowledgeRegistry();
      expect(report2.totalRegistered, 5);
      final rowsAfter = await db.query(DatabaseConstants.tableKnowledgeRegistry);
      expect(rowsAfter.length, 5);
    });

    test('Test F: Practice Evidence & Mastery preservation across content updates', () async {
      await knowledgeService.syncAllEntitiesToKnowledgeRegistry();

      // Learner completes a writing/shadowing practice session
      await knowledgeService.recordPracticeEvidence(
        knowledgeId: 'KNOW_VOCAB_学习_xuexi',
        activityType: 'shadowing',
        score: 0.95,
        durationMs: 4200,
      );

      // 1. Verify append-only learner evidence
      final evidence = await db.query(
        DatabaseConstants.tableLearnerEvidence,
        where: 'content_id = ?',
        whereArgs: ['KNOW_VOCAB_学习_xuexi'],
      );
      expect(evidence.length, 1);
      expect((evidence[0]['score'] as num).toDouble(), 0.95);

      // 2. Verify mastery in curriculum_mastery
      final mastery = await db.query(
        DatabaseConstants.tableCurriculumMastery,
        where: 'item_id = ?',
        whereArgs: ['KNOW_VOCAB_学习_xuexi'],
      );
      expect(mastery.length, 1);
      expect(mastery[0]['mastery_state'], 'completed');

      // 3. Verify SRS scheduling in srs_items
      final srs = await db.query(
        DatabaseConstants.tableSrsItems,
        where: 'content_id = ?',
        whereArgs: ['KNOW_VOCAB_学习_xuexi'],
      );
      expect(srs.length, 1);
      expect(srs[0]['interval_days'], 3);

      // Simulate a Content Pack update (update vocabulary definition)
      await db.update(
        DatabaseConstants.tableVocabularySenses,
        {'meaning_vi': 'học, học tập và rèn luyện'},
        where: 'id = ?',
        whereArgs: ['sns_voc_hsk1_001_1'],
      );

      // Re-sync knowledge registry
      await knowledgeService.syncAllEntitiesToKnowledgeRegistry();

      // Verify that learner evidence, mastery state, and SRS items are PRESERVED!
      final preservedEvidence = await db.query(DatabaseConstants.tableLearnerEvidence);
      expect(preservedEvidence.length, 1);
      final preservedMastery = await db.query(DatabaseConstants.tableCurriculumMastery);
      expect(preservedMastery[0]['mastery_state'], 'completed');
      final preservedSrs = await db.query(DatabaseConstants.tableSrsItems);
      expect(preservedSrs[0]['interval_days'], 3);
    });
  });
}
