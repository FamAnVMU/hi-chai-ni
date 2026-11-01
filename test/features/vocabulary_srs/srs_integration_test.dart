import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/features/vocabulary_srs/vocabulary_srs.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late Directory tempDir;
  late SrsRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('srs_integration_test_');
    final dbPath = '${tempDir.path}/test_srs_integration.db';
    db = await databaseFactory.openDatabase(dbPath);

    final engine = MigrationEngine();
    await engine.executeMigrations(db, 0, DatabaseConstants.currentDatabaseVersion);

    repository = SrsRepository(db, debounceCooldownMs: 100);

    // Seed test vocabulary
    await db.insert(DatabaseConstants.tableVocabularies, {
      'id': 'VOCAB_001',
      'simplified': '你好',
      'traditional': '你好',
      'pinyin': 'nǐ hǎo',
      'hsk_level': 1,
      'stroke_count': 6,
      'radicals': '亻',
      'frequency_rank': 1,
      'audio_uri': 'assets/audio/nihao.mp3',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    await db.insert(DatabaseConstants.tableVocabularySenses, {
      'id': 'SENSE_001',
      'vocabulary_id': 'VOCAB_001',
      'part_of_speech': 'thán từ',
      'meaning_vi': 'Xin chào',
      'example_cn': '你好[nǐhǎo]，很[hěn]高兴[gāoxìng]认识[rènshi]你[nǐ]。',
      'example_pinyin': 'Nǐ hǎo, hěn gāoxìng rènshi nǐ.',
      'example_vi': 'Xin chào, rất vui được làm quen với bạn.',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    await db.insert(DatabaseConstants.tableVocabularies, {
      'id': 'VOCAB_002',
      'simplified': '谢谢',
      'traditional': '謝謝',
      'pinyin': 'xièxie',
      'hsk_level': 1,
      'stroke_count': 12,
      'radicals': '讠',
      'frequency_rank': 2,
      'audio_uri': null, // Test without audio
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });

    await db.insert(DatabaseConstants.tableVocabularySenses, {
      'id': 'SENSE_002',
      'vocabulary_id': 'VOCAB_002',
      'part_of_speech': 'động từ',
      'meaning_vi': 'Cảm ơn',
      'example_cn': '谢谢[xièxie]你[nǐ]的[de]帮助[bāngzhù]。',
      'example_pinyin': 'Xièxie nǐ de bāngzhù.',
      'example_vi': 'Cảm ơn sự giúp đỡ của bạn.',
      'created_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SRS Integration & Due Date Precision Tests', () {
    test('1. getDueFlashcards seamlessly introduces new unstudied words with preview intervals', () async {
      final cards = await repository.getDueFlashcards(limit: 10);
      expect(cards.length, equals(2));

      final firstCard = cards.first;
      expect(firstCard.id, equals('VOCAB_001'));
      expect(firstCard.simplified, equals('你好'));
      expect(firstCard.pinyin, equals('nǐ hǎo'));
      expect(firstCard.meaningVi, equals('Xin chào'));
      expect(firstCard.audioUri, equals('assets/audio/nihao.mp3'));

      // Check preview intervals for 4 ratings
      expect(firstCard.estimatedIntervalDays.containsKey(SrsRating.again), isTrue);
      expect(firstCard.estimatedIntervalDays.containsKey(SrsRating.hard), isTrue);
      expect(firstCard.estimatedIntervalDays.containsKey(SrsRating.good), isTrue);
      expect(firstCard.estimatedIntervalDays.containsKey(SrsRating.easy), isTrue);

      // New card initial preview intervals
      expect(firstCard.estimatedIntervalDays[SrsRating.again], equals(1));
      expect(firstCard.estimatedIntervalDays[SrsRating.good], equals(1));
      expect(firstCard.estimatedIntervalDays[SrsRating.easy], equals(3));
    });

    test('2. Rating "Good" advances intervals, updates due_at, and writes immutable learner evidence', () async {
      final cards = await repository.getDueFlashcards(limit: 10);
      final card = cards.first;

      final reviewTime = DateTime.utc(2026, 11, 1, 10, 0, 0);

      // Review turn 1: Good (n = 1) -> interval = 1 day
      final result1 = await repository.recordReviewAndProgress(
        item: card,
        rating: SrsRating.good,
        durationMs: 2500,
        reviewTime: reviewTime,
      );

      expect(result1.newIntervalDays, equals(1));
      expect(result1.scheduledDueAt, equals(reviewTime.add(const Duration(days: 1))));

      // Verify database updated
      final updatedRow = await db.query(
        DatabaseConstants.tableSrsItems,
        where: 'content_id = ?',
        whereArgs: [card.id],
      );
      expect(updatedRow.first['repetitions'], equals(1));
      expect(updatedRow.first['interval_days'], equals(1));

      // Verify learner_evidence has append-only audit log
      final evidenceRows = await db.query(
        DatabaseConstants.tableLearnerEvidence,
        where: 'content_id = ?',
        whereArgs: [card.id],
      );
      expect(evidenceRows.length, equals(1));
      expect(evidenceRows.first['source'], equals('srs_flashcard'));
      expect(evidenceRows.first['score'], equals(1.0));

      // Verify learning_activities recorded for Home Screen streak
      final activityRows = await db.query(
        DatabaseConstants.tableLearningActivities,
        where: 'activity_type = ?',
        whereArgs: ['srs_review'],
      );
      expect(activityRows.length, equals(1));
      expect(activityRows.first['activity_type'], equals('srs_review'));
    });

    test('3. Rating "Again" resets interval to 1 day and increments lapses', () async {
      final cards = await repository.getDueFlashcards(limit: 10);
      final card = cards.first;

      // Simulate prior mastery: reps = 3, interval = 15 days
      final cardState = card.srsState.copyWith(
        repetitions: 3,
        intervalDays: 15,
        easeFactor: 2.5,
        state: SrsItemState.review,
      );
      await db.update(
        DatabaseConstants.tableSrsItems,
        cardState.toMap(),
        where: 'id = ?',
        whereArgs: [cardState.id],
      );

      final updatedCard = card.copyWith(srsState: cardState);

      // User lapses (Again)
      final reviewResult = await repository.recordReviewAndProgress(
        item: updatedCard,
        rating: SrsRating.again,
      );

      expect(reviewResult.newIntervalDays, equals(1));
      expect(reviewResult.nextState.repetitions, equals(0));
      expect(reviewResult.nextState.lapses, equals(1));
      expect(reviewResult.nextState.state, equals(SrsItemState.relearning));

      // Check DB
      final row = await db.query(
        DatabaseConstants.tableSrsItems,
        where: 'content_id = ?',
        whereArgs: [card.id],
      );
      expect(row.first['interval_days'], equals(1));
      expect(row.first['repetitions'], equals(0));
      expect(row.first['lapses'], equals(1));
      expect(row.first['state'], equals('relearning'));
    });

    test('4. Rating "Easy" applies bonus multiplier and boosts Ease Factor', () async {
      final cards = await repository.getDueFlashcards(limit: 10);
      final card = cards.first;

      final result = await repository.recordReviewAndProgress(
        item: card,
        rating: SrsRating.easy,
      );

      expect(result.newIntervalDays, equals(3)); // Easy jumpstart
      expect(result.newEaseFactor, greaterThan(2.5)); // +0.1 bonus
    });

    test('5. Rejects duplicate rapid review taps within debounce threshold', () async {
      final cards = await repository.getDueFlashcards(limit: 10);
      final card = cards.first;

      // First review succeeds
      await repository.recordReviewAndProgress(
        item: card,
        rating: SrsRating.good,
      );

      // Immediate second review for the same item throws DuplicateReviewException
      expect(
        () => repository.recordReviewAndProgress(
          item: card,
          rating: SrsRating.good,
        ),
        throwsA(isA<DuplicateReviewException>()),
      );
    });
  });
}
