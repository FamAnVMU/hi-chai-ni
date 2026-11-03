import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/core/knowledge/knowledge.dart';
import 'package:hi_chinese/features/hanzi/data/hanzi_dao.dart';
import 'package:hi_chinese/features/hanzi/domain/models/hanzi_models.dart';
import 'package:hi_chinese/features/hanzi_writing/domain/engine/hanzi_stroke_bank.dart';
import 'package:hi_chinese/features/hanzi_writing/domain/models/stroke_models.dart';
import 'package:hi_chinese/features/roadmap/data/roadmap_repository.dart';
import 'package:hi_chinese/features/roadmap/domain/catalog/curriculum_catalog.dart';
import 'package:hi_chinese/features/vocabulary_srs/vocabulary_srs.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late Directory tempDir;
  late KnowledgeIdentityRegistry identityRegistry;
  late SrsRepository srsRepository;
  late HanziDao hanziDao;
  late HanziStrokeBank strokeBank;
  late DefaultRoadmapRepository roadmapRepository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('knowledge_identity_test_');
    final dbPath = '${tempDir.path}/test_knowledge.db';
    db = await databaseFactory.openDatabase(dbPath);

    final engine = MigrationEngine();
    await engine.executeMigrations(db, 0, DatabaseConstants.currentDatabaseVersion);

    identityRegistry = KnowledgeIdentityRegistry(db);
    srsRepository = SrsRepository(db, identityRegistry: identityRegistry, debounceCooldownMs: 50);
    hanziDao = HanziDao(db);
    strokeBank = HanziStrokeBank(hanziDao);
    roadmapRepository = DefaultRoadmapRepository(db, identityRegistry: identityRegistry);

    // Seed test vocabulary
    await db.insert(DatabaseConstants.tableVocabularies, {
      'id': 'voc_hsk1_001',
      'simplified': '你好',
      'traditional': '你好',
      'pinyin': 'nǐ hǎo',
      'pinyin_clean': 'nihao',
      'hsk_level': 1,
      'stroke_count': 6,
      'radicals': '亻',
      'frequency_rank': 1,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    await db.insert(DatabaseConstants.tableVocabularies, {
      'id': 'voc_hsk1_002',
      'simplified': '谢谢',
      'traditional': '謝謝',
      'pinyin': 'xiè xie',
      'pinyin_clean': 'xiexie',
      'hsk_level': 1,
      'stroke_count': 12,
      'radicals': '讠',
      'frequency_rank': 2,
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  });

  tearDown(() async {
    await db.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('Nhiệm vụ A – Canonical Knowledge Identity Registry Tests', () {
    test('1. Resolves well-known Roadmap & Curriculum aliases to canonical lesson ID', () async {
      expect(await identityRegistry.toCanonicalLessonId('lesson_hsk1_u1_l1'), 'lesson_1_1');
      expect(await identityRegistry.toCanonicalLessonId('c_hsk1_l1'), 'lesson_1_1');
      expect(await identityRegistry.toCanonicalLessonId('LES_HSK1_01_TONES'), 'lesson_1_1');
    });

    test('2. Pattern-based fallback converts lesson_hskX_uY_lZ to lesson_X_Z', () async {
      expect(await identityRegistry.toCanonicalLessonId('lesson_hsk3_u2_l8'), 'lesson_3_8');
      expect(await identityRegistry.toCanonicalLessonId('c_hsk4_l12'), 'lesson_4_12');
    });

    test('3. Bidirectional alias resolution via content_id_mappings table', () async {
      await identityRegistry.registerAlias(
        oldId: 'legacy_les_intro',
        newId: 'lesson_1_1',
        mappingType: 'lesson_migration',
      );

      final canonical = await identityRegistry.toCanonicalLessonId('legacy_les_intro');
      expect(canonical, 'lesson_1_1');

      final aliases = await identityRegistry.getAliasesFor('lesson_1_1');
      expect(aliases, contains('legacy_les_intro'));
      expect(aliases, contains('lesson_hsk1_u1_l1'));
      expect(aliases, contains('c_hsk1_l1'));
    });

    test('4. CurriculumCatalog resolves both canonical IDs and LES_* IDs', () {
      final lessonByCanonical = CurriculumCatalog.findLessonById('lesson_1_1');
      expect(lessonByCanonical, isNotNull);
      expect(lessonByCanonical!.id, 'LES_HSK1_01_TONES');

      final lessonByRoadmapAlias = CurriculumCatalog.findLessonById('lesson_hsk1_u1_l1');
      expect(lessonByRoadmapAlias, isNotNull);
      expect(lessonByRoadmapAlias!.id, 'LES_HSK1_01_TONES');
    });

    test('5. RoadmapRepository indexes lesson progress under both canonical and alias IDs', () async {
      await roadmapRepository.completeLesson(lessonId: 'LES_HSK1_01_TONES', score: 0.95);

      final progressMap = await roadmapRepository.getLessonProgressMap();
      expect(progressMap.containsKey('lesson_1_1'), isTrue, reason: 'Must index under canonical ID');
      expect(progressMap.containsKey('lesson_hsk1_u1_l1'), isTrue, reason: 'Must index under roadmap ID');
      expect(progressMap.containsKey('c_hsk1_l1'), isTrue, reason: 'Must index under curriculum ID');
      expect(progressMap.containsKey('LES_HSK1_01_TONES'), isTrue, reason: 'Must index under original ID');

      final progress = progressMap['lesson_1_1']!;
      expect(progress.isCompleted, isTrue);
      expect(progress.completionScore, 0.95);
    });
  });

  group('Nhiệm vụ B – Hanzi & Hanzi Writing Integration Tests', () {
    test('1. Curated verified characters load immediately from static bank', () {
      final data = strokeBank.getStrokeData('十');
      expect(data, isNotNull);
      expect(data!.character, '十');
      expect(data.totalStrokes, 2);
      expect(data.strokes[0].type, StrokeType.heng);
      expect(data.strokes[1].type, StrokeType.shu);
      expect(data.isVerified, isTrue);
    });

    test('2. Shared Hanzi database character dynamically converts medians into StandardStrokes', () async {
      // Seed character '你' with medians into hanzi_characters
      final mediansNi = [
        [const Point2D(317, 812), const Point2D(249, 577), const Point2D(68, 367)], // 撇 (pie)
        [const Point2D(248, 513), const Point2D(243, 245), const Point2D(241, 102)], // 竖 (shu)
      ];

      await hanziDao.insertCharactersBatch([
        HanziCharacter(
          id: 'char_4f60',
          character: '你',
          strokeCount: 2,
          hskLevel: 1,
          pinyin: 'nǐ',
          meaningVi: 'Bạn, anh, chị',
          strokes: ['M 317 812 ...', 'M 248 513 ...'],
          medians: mediansNi,
        ),
      ]);

      final strokeData = await strokeBank.getStrokeDataAsync('你');
      expect(strokeData, isNotNull);
      expect(strokeData!.character, '你');
      expect(strokeData.isVerified, isTrue);
      expect(strokeData.strokes.length, 2);

      // Verify coordinate normalization [0, 1]
      final stroke1 = strokeData.strokes[0];
      expect(stroke1.normalizedStart.dx, closeTo(317 / 1024.0, 0.01));
      expect(stroke1.normalizedStart.dy, closeTo((900.0 - 812) / 1024.0, 0.01));
      expect(stroke1.type, StrokeType.pie, reason: 'First stroke of 你 is Phẩy (撇)');

      final stroke2 = strokeData.strokes[1];
      expect(stroke2.type, StrokeType.shu, reason: 'Second stroke of 你 is Sổ (竖)');
    });

    test('3. Characters without verified vector strokes are strictly marked unverified', () async {
      await hanziDao.insertCharactersBatch([
        const HanziCharacter(
          id: 'char_unsupported',
          character: '𪚥',
          strokeCount: 64,
          hskLevel: 6,
          pinyin: 'zhé',
          meaningVi: 'Nói nhiều',
          strokes: [],
          medians: [],
        ),
      ]);

      final strokeData = await strokeBank.getStrokeDataAsync('𪚥');
      expect(strokeData, isNotNull);
      expect(strokeData!.isVerified, isFalse, reason: 'Must NOT generate fake AI strokes');
      expect(strokeData.strokes, isEmpty);
    });
  });

  group('Nhiệm vụ C – SRS Vocabulary ID Standardization & Deduplication Tests', () {
    test('1. Resolves all 4 vocabulary ID conventions to canonical voc_hsk... PK', () async {
      // Convention 1: Direct PK
      expect(await identityRegistry.toCanonicalVocabularyId('voc_hsk1_001'), 'voc_hsk1_001');

      // Convention 2: Canonical Knowledge Registry ID
      expect(await identityRegistry.toCanonicalVocabularyId('KNOW_VOCAB_你好_nihao'), 'voc_hsk1_001');

      // Convention 3: Raw Simplified Character
      expect(await identityRegistry.toCanonicalVocabularyId('你好'), 'voc_hsk1_001');
      expect(await identityRegistry.toCanonicalVocabularyId('谢谢'), 'voc_hsk1_002');

      // Convention 4: Legacy curriculum code
      expect(await identityRegistry.toCanonicalVocabularyId('VOCAB_001_NIHAO'), 'voc_hsk1_001');

      // Accidental SRS prefix
      expect(await identityRegistry.toCanonicalVocabularyId('SRS_VOCABULARY_voc_hsk1_001'), 'voc_hsk1_001');
    });

    test('2. getOrCreateCardState automatically standardizes raw Hanzi to canonical PK', () async {
      final card = await srsRepository.getOrCreateCardState(contentId: '你好');
      expect(card.contentId, 'voc_hsk1_001', reason: 'Must store canonical PK in content_id');
      expect(card.id, 'SRS_VOCABULARY_voc_hsk1_001');

      // Querying with legacy code also hits the exact same card
      final cardFromLegacy = await srsRepository.getOrCreateCardState(contentId: 'VOCAB_001_NIHAO');
      expect(cardFromLegacy.id, card.id);
    });

    test('3. migrateSrsItemsToCanonical deduplicates cards and preserves learning metrics', () async {
      final nowUtc = DateTime.now().toUtc();

      // Simulate a legacy database state where user had two cards for '你好':
      // Card A: created with raw word '你好', reviewed 5 times, interval 21 days
      await db.insert(DatabaseConstants.tableSrsItems, {
        'id': 'SRS_VOCABULARY_你好',
        'content_id': '你好',
        'content_type': 'vocabulary',
        'state': 'review',
        'interval_days': 21,
        'ease_factor': 2.6,
        'repetitions': 5,
        'lapses': 0,
        'due_at': nowUtc.add(const Duration(days: 21)).toIso8601String(),
        'created_at': nowUtc.subtract(const Duration(days: 30)).toIso8601String(),
        'updated_at': nowUtc.toIso8601String(),
      });

      // Card B: created with canonical ID, but lower progress (repetitions 1, interval 1 day)
      await db.insert(DatabaseConstants.tableSrsItems, {
        'id': 'SRS_VOCABULARY_voc_hsk1_001',
        'content_id': 'voc_hsk1_001',
        'content_type': 'vocabulary',
        'state': 'learning',
        'interval_days': 1,
        'ease_factor': 2.5,
        'repetitions': 1,
        'lapses': 0,
        'due_at': nowUtc.add(const Duration(days: 1)).toIso8601String(),
        'created_at': nowUtc.subtract(const Duration(days: 2)).toIso8601String(),
        'updated_at': nowUtc.toIso8601String(),
      });

      // Add evidence under Card A
      await db.insert(DatabaseConstants.tableLearnerEvidence, {
        'id': 'EVI_TEST_OLD_CARD',
        'srs_item_id': 'SRS_VOCABULARY_你好',
        'content_id': '你好',
        'content_type': 'vocabulary',
        'source': 'srs_flashcard',
        'score': 1.0,
        'duration_ms': 1200,
        'created_at': nowUtc.toIso8601String(),
      });

      // Run migration
      final result = await srsRepository.migrateSrsItemsToCanonical();
      expect(result.mergedCount, 1);

      // Verify canonical card now holds merged max metrics
      final canonicalRows = await db.query(
        DatabaseConstants.tableSrsItems,
        where: 'id = ?',
        whereArgs: ['SRS_VOCABULARY_voc_hsk1_001'],
      );
      expect(canonicalRows, isNotEmpty);
      final mergedCard = canonicalRows.first;
      expect(mergedCard['repetitions'], 5, reason: 'Kept max repetitions');
      expect(mergedCard['interval_days'], 21, reason: 'Kept max interval');
      expect(mergedCard['ease_factor'], 2.6, reason: 'Kept max ease factor');

      // Verify duplicate card was soft-deleted
      final duplicateRows = await db.query(
        DatabaseConstants.tableSrsItems,
        where: 'id = ?',
        whereArgs: ['SRS_VOCABULARY_你好'],
      );
      expect(duplicateRows.first['deleted_at'], isNotNull);

      // Verify learner_evidence was re-linked to canonical card
      final evidenceRows = await db.query(
        DatabaseConstants.tableLearnerEvidence,
        where: 'id = ?',
        whereArgs: ['EVI_TEST_OLD_CARD'],
      );
      expect(evidenceRows.first['srs_item_id'], 'SRS_VOCABULARY_voc_hsk1_001');
      expect(evidenceRows.first['content_id'], 'voc_hsk1_001');
    });
  });

  group('Nhiệm vụ D – Deterministic Primary Sense Query Tests (F-17)', () {
    test('1. Always deterministically selects sense with lowest order_index', () async {
      final nowIso = DateTime.now().toUtc().toIso8601String();

      // Insert 3 senses for voc_hsk1_001 out-of-order
      await db.insert(DatabaseConstants.tableVocabularySenses, {
        'id': 'SENSE_SECONDARY_2',
        'vocabulary_id': 'voc_hsk1_001',
        'part_of_speech': 'đại từ',
        'meaning_vi': 'Ý nghĩa phụ bậc 2',
        'order_index': 3,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      await db.insert(DatabaseConstants.tableVocabularySenses, {
        'id': 'SENSE_PRIMARY',
        'vocabulary_id': 'voc_hsk1_001',
        'part_of_speech': 'thán từ',
        'meaning_vi': 'Xin chào (Nghĩa chính)',
        'order_index': 1,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      await db.insert(DatabaseConstants.tableVocabularySenses, {
        'id': 'SENSE_SECONDARY_1',
        'vocabulary_id': 'voc_hsk1_001',
        'part_of_speech': 'danh từ',
        'meaning_vi': 'Ý nghĩa phụ bậc 1',
        'order_index': 2,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      // Create due SRS item
      await srsRepository.getOrCreateCardState(contentId: 'voc_hsk1_001');

      // Query due flashcards 10 times consecutively to verify absolute determinism
      for (int i = 0; i < 10; i++) {
        final cards = await srsRepository.getDueFlashcards(limit: 5);
        expect(cards, isNotEmpty);
        final card = cards.firstWhere((c) => c.id == 'voc_hsk1_001');
        expect(
          card.meaningVi,
          'Xin chào (Nghĩa chính)',
          reason: 'Iteration $i: Must always return sense with lowest order_index (1)',
        );
      }
    });

    test('2. Tie-breaker with equal order_index deterministically selects by id ASC', () async {
      final nowIso = DateTime.now().toUtc().toIso8601String();

      await db.insert(DatabaseConstants.tableVocabularySenses, {
        'id': 'SENSE_Z_TIE',
        'vocabulary_id': 'voc_hsk1_002',
        'part_of_speech': 'thán từ',
        'meaning_vi': 'Cảm ơn (Z)',
        'order_index': 1,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      await db.insert(DatabaseConstants.tableVocabularySenses, {
        'id': 'SENSE_A_TIE',
        'vocabulary_id': 'voc_hsk1_002',
        'part_of_speech': 'thán từ',
        'meaning_vi': 'Cảm ơn (A)',
        'order_index': 1,
        'created_at': nowIso,
        'updated_at': nowIso,
      });

      await srsRepository.getOrCreateCardState(contentId: 'voc_hsk1_002');

      final cards = await srsRepository.getDueFlashcards(limit: 5);
      final card = cards.firstWhere((c) => c.id == 'voc_hsk1_002');
      expect(
        card.meaningVi,
        'Cảm ơn (A)',
        reason: 'Tie-breaker must deterministically select id ASC (SENSE_A_TIE < SENSE_Z_TIE)',
      );
    });

    test('3. Word without any vocabulary_senses still returns clean flashcard with fallback', () async {
      // Insert vocabulary without senses
      await db.insert(DatabaseConstants.tableVocabularies, {
        'id': 'voc_nosense_001',
        'simplified': '猫',
        'traditional': '貓',
        'pinyin': 'māo',
        'hsk_level': 1,
        'stroke_count': 11,
        'frequency_rank': 50,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      await srsRepository.getOrCreateCardState(contentId: 'voc_nosense_001');

      final cards = await srsRepository.getDueFlashcards(limit: 10);
      final card = cards.firstWhere((c) => c.id == 'voc_nosense_001');
      expect(card.simplified, '猫');
      expect(card.meaningVi, 'Chưa có định nghĩa', reason: 'Must safely fallback without throwing');
    });
  });
}
