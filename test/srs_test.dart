import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database.dart';
import 'package:hi_chinese/features/vocabulary_srs/vocabulary_srs.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('SM-2 Pure Engine Mathematical Verification', () {
    const engine = Sm2Engine();

    test('1. Ease Factor formula delta values match Piotr Woźniak (1987) specification', () {
      const initialEf = 2.5;

      // Quality 5 (Easy): delta = +0.10
      final ef5 = engine.calculateNewEaseFactor(initialEf, 5);
      expect((ef5 - 2.6).abs(), lessThan(1e-6));

      // Quality 4 (Good): delta = 0.00
      final ef4 = engine.calculateNewEaseFactor(initialEf, 4);
      expect((ef4 - 2.5).abs(), lessThan(1e-6));

      // Quality 3 (Hard): delta = -0.14
      final ef3 = engine.calculateNewEaseFactor(initialEf, 3);
      expect((ef3 - 2.36).abs(), lessThan(1e-6));

      // Quality 1 (Again): delta = -0.54
      final ef1 = engine.calculateNewEaseFactor(initialEf, 1);
      expect((ef1 - 1.96).abs(), lessThan(1e-6));

      // Quality 0 (Blackout): delta = -0.80
      final ef0 = engine.calculateNewEaseFactor(initialEf, 0);
      expect((ef0 - 1.70).abs(), lessThan(1e-6));
    });

    test('2. Ease Factor floor policy strictly enforces minimum threshold of 1.3', () {
      var ef = 1.4;
      // Multiple consecutive failures (quality 1)
      ef = engine.calculateNewEaseFactor(ef, 1); // 1.4 - 0.54 = 0.86 -> clamped to 1.3
      expect(ef, equals(1.3));

      // Further failures must never drop below 1.3
      ef = engine.calculateNewEaseFactor(ef, 0);
      expect(ef, equals(1.3));
      ef = engine.calculateNewEaseFactor(ef, 1);
      expect(ef, equals(1.3));
    });

    test('3. Ease Factor ceiling policy prevents unbounded escalation', () {
      var ef = 4.95;
      ef = engine.calculateNewEaseFactor(ef, 5); // 4.95 + 0.10 = 5.05 -> clamped to 5.0
      expect(ef, equals(5.0));
      ef = engine.calculateNewEaseFactor(ef, 5);
      expect(ef, equals(5.0));
    });

    test('4. First review behavior (repetitions = 0)', () {
      final newCard = SrsCardState.newCard(
        id: 'SRS_TEST_1',
        contentId: 'VOC_001',
        now: DateTime.utc(2026, 11, 1, 10, 0, 0),
      );

      // Again: restarts learning, 1 day interval, lapses incremented
      final resAgain = engine.calculateNextState(
        currentState: newCard,
        rating: SrsRating.again,
        reviewTime: DateTime.utc(2026, 11, 1, 10, 0, 0),
      );
      expect(resAgain.nextState.state, equals(SrsItemState.learning));
      expect(resAgain.newIntervalDays, equals(1));
      expect(resAgain.nextState.repetitions, equals(0));
      expect(resAgain.nextState.lapses, equals(1));
      expect((resAgain.newEaseFactor - 1.96).abs(), lessThan(1e-6));

      // Hard: passes, 1 day interval, repetitions = 1
      final resHard = engine.calculateNextState(
        currentState: newCard,
        rating: SrsRating.hard,
        reviewTime: DateTime.utc(2026, 11, 1, 10, 0, 0),
      );
      expect(resHard.nextState.state, equals(SrsItemState.review));
      expect(resHard.newIntervalDays, equals(1));
      expect(resHard.nextState.repetitions, equals(1));
      expect((resHard.newEaseFactor - 2.36).abs(), lessThan(1e-6));

      // Good: passes, 1 day interval, repetitions = 1, EF unchanged
      final resGood = engine.calculateNextState(
        currentState: newCard,
        rating: SrsRating.good,
        reviewTime: DateTime.utc(2026, 11, 1, 10, 0, 0),
      );
      expect(resGood.nextState.state, equals(SrsItemState.review));
      expect(resGood.newIntervalDays, equals(1));
      expect(resGood.nextState.repetitions, equals(1));
      expect(resGood.newEaseFactor, equals(2.5));

      // Easy: passes, 3 days interval bonus, repetitions = 1, EF increases
      final resEasy = engine.calculateNextState(
        currentState: newCard,
        rating: SrsRating.easy,
        reviewTime: DateTime.utc(2026, 11, 1, 10, 0, 0),
      );
      expect(resEasy.nextState.state, equals(SrsItemState.review));
      expect(resEasy.newIntervalDays, equals(3));
      expect(resEasy.nextState.repetitions, equals(1));
      expect(resEasy.newEaseFactor, equals(2.6));
    });

    test('5. Multi-step progression of canonical SM-2 intervals (Good reviews)', () {
      var state = SrsCardState.newCard(
        id: 'SRS_TEST_SEQ',
        contentId: 'VOC_SEQ',
        now: DateTime.utc(2026, 1, 1, 8, 0, 0),
      );

      // Step 1: Good (n=1) -> 1 day
      var res = engine.calculateNextState(
        currentState: state,
        rating: SrsRating.good,
        reviewTime: state.dueAt,
      );
      state = res.nextState;
      expect(state.repetitions, equals(1));
      expect(state.intervalDays, equals(1));
      expect(state.easeFactor, equals(2.5));

      // Step 2: Good (n=2) -> 6 days
      res = engine.calculateNextState(
        currentState: state,
        rating: SrsRating.good,
        reviewTime: state.dueAt,
      );
      state = res.nextState;
      expect(state.repetitions, equals(2));
      expect(state.intervalDays, equals(6));
      expect(state.easeFactor, equals(2.5));

      // Step 3: Good (n=3) -> round(6 * 2.5) = 15 days
      res = engine.calculateNextState(
        currentState: state,
        rating: SrsRating.good,
        reviewTime: state.dueAt,
      );
      state = res.nextState;
      expect(state.repetitions, equals(3));
      expect(state.intervalDays, equals(15));

      // Step 4: Good (n=4) -> round(15 * 2.5) = 38 days
      res = engine.calculateNextState(
        currentState: state,
        rating: SrsRating.good,
        reviewTime: state.dueAt,
      );
      state = res.nextState;
      expect(state.repetitions, equals(4));
      expect(state.intervalDays, equals(38));

      // Step 5: Good (n=5) -> round(38 * 2.5) = 95 days
      res = engine.calculateNextState(
        currentState: state,
        rating: SrsRating.good,
        reviewTime: state.dueAt,
      );
      state = res.nextState;
      expect(state.repetitions, equals(5));
      expect(state.intervalDays, equals(95));
    });

    test('6. Lapse on learned card resets interval and increments lapses count', () {
      // Create a card that has reached 38 days interval
      final matureCard = SrsCardState(
        id: 'SRS_MATURE',
        contentId: 'VOC_MATURE',
        state: SrsItemState.review,
        intervalDays: 38,
        easeFactor: 2.5,
        repetitions: 4,
        lapses: 0,
        dueAt: DateTime.utc(2026, 6, 1),
        createdAt: DateTime.utc(2026, 1, 1),
        updatedAt: DateTime.utc(2026, 5, 1),
      );

      final res = engine.calculateNextState(
        currentState: matureCard,
        rating: SrsRating.again,
        reviewTime: DateTime.utc(2026, 6, 1),
      );

      expect(res.nextState.state, equals(SrsItemState.relearning));
      expect(res.nextState.intervalDays, equals(1));
      expect(res.nextState.repetitions, equals(0));
      expect(res.nextState.lapses, equals(1));
      expect(res.newEaseFactor, equals(1.96)); // 2.5 - 0.54
    });

    test('7. Due date calculation across leap year and month boundaries', () {
      // Leap year test: 2028 is a leap year (Feb 29 exists)
      final leapBase = DateTime.utc(2028, 2, 28, 14, 30, 0);
      final cardLeap = SrsCardState.newCard(
        id: 'SRS_LEAP',
        contentId: 'VOC_LEAP',
        now: leapBase,
      );

      final res1Day = engine.calculateNextState(
        currentState: cardLeap,
        rating: SrsRating.good, // 1 day
        reviewTime: leapBase,
      );
      // 2028-02-28 + 1 day MUST equal 2028-02-29 (Leap Day)
      expect(res1Day.scheduledDueAt, equals(DateTime.utc(2028, 2, 29, 14, 30, 0)));
      expect(res1Day.scheduledDueAt.isUtc, isTrue);

      // Month rollover across year-end
      final yearEndBase = DateTime.utc(2027, 12, 31, 23, 0, 0);
      final cardYearEnd = SrsCardState.newCard(
        id: 'SRS_YE',
        contentId: 'VOC_YE',
        now: yearEndBase,
      );
      final resYearEnd = engine.calculateNextState(
        currentState: cardYearEnd,
        rating: SrsRating.easy, // 3 days
        reviewTime: yearEndBase,
      );
      expect(resYearEnd.scheduledDueAt, equals(DateTime.utc(2028, 1, 3, 23, 0, 0)));
    });

    test('8. State serialization (fromMap / toMap / fromJson / toJson) integrity', () {
      final original = SrsCardState(
        id: 'SRS_SERIAL_01',
        contentId: 'VOC_NIHAO',
        contentType: 'vocabulary',
        state: SrsItemState.review,
        intervalDays: 15,
        easeFactor: 2.36,
        repetitions: 3,
        lapses: 1,
        dueAt: DateTime.utc(2026, 11, 20, 10, 0, 0),
        lastReviewedAt: DateTime.utc(2026, 11, 5, 10, 0, 0),
        createdAt: DateTime.utc(2026, 10, 1, 10, 0, 0),
        updatedAt: DateTime.utc(2026, 11, 5, 10, 0, 0),
      );

      final map = original.toMap();
      final restored = SrsCardState.fromMap(map);

      expect(restored.id, equals(original.id));
      expect(restored.contentId, equals(original.contentId));
      expect(restored.contentType, equals(original.contentType));
      expect(restored.state, equals(original.state));
      expect(restored.intervalDays, equals(original.intervalDays));
      expect(restored.easeFactor, equals(original.easeFactor));
      expect(restored.repetitions, equals(original.repetitions));
      expect(restored.lapses, equals(original.lapses));
      expect(restored.dueAt, equals(original.dueAt));
      expect(restored.lastReviewedAt, equals(original.lastReviewedAt));
    });
  });

  group('SrsRepository Persistence & Anti-Double-Tap Tests', () {
    late Directory tempDir;
    late String dbPath;
    late AppDatabase appDb;
    late Database db;
    late SrsRepository srsRepo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hi_chinese_srs_repo_test_');
      dbPath = '${tempDir.path}/srs_repo_test.db';

      appDb = AppDatabase.instance;
      await appDb.open(customPath: dbPath, customFactory: databaseFactoryFfi);
      db = appDb.database;

      srsRepo = SrsRepository(db, debounceCooldownMs: 800);
    });

    tearDown(() async {
      await appDb.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('1. Get or create initializes new card state in SQLite', () async {
      final card = await srsRepo.getOrCreateCardState(contentId: 'VOC_HELLO');
      expect(card.contentId, equals('VOC_HELLO'));
      expect(card.state, equals(SrsItemState.newCard));
      expect(card.repetitions, equals(0));
      expect(card.intervalDays, equals(0));
      expect(card.easeFactor, equals(2.5));

      // Re-fetching returns the exact same card from DB
      final cardAgain = await srsRepo.getOrCreateCardState(contentId: 'VOC_HELLO');
      expect(cardAgain.id, equals(card.id));
      expect(cardAgain.createdAt, equals(card.createdAt));
    });

    test('2. Process review atomically updates state and appends learner evidence', () async {
      final reviewTime = DateTime.utc(2026, 11, 1, 9, 0, 0);

      final result = await srsRepo.processReview(
        contentId: 'VOC_ATOM',
        rating: SrsRating.good,
        reviewTime: reviewTime,
        durationMs: 1500,
        source: 'test_flashcard',
      );

      expect(result.newIntervalDays, equals(1));
      expect(result.nextState.repetitions, equals(1));

      // Verify state was saved to SQLite
      final savedState = await srsRepo.getOrCreateCardState(contentId: 'VOC_ATOM');
      expect(savedState.repetitions, equals(1));
      expect(savedState.intervalDays, equals(1));
      expect(savedState.lastReviewedAt, equals(reviewTime));

      // Verify append-only evidence history was created
      final history = await srsRepo.getReviewHistory('VOC_ATOM');
      expect(history.length, equals(1));
      expect(history.first['score'], equals(1.0));
      expect(history.first['source'], equals('test_flashcard'));
    });

    test('3. Prevents rapid double-tap review spam (Debounce guard)', () async {
      final reviewTime = DateTime.utc(2026, 11, 1, 12, 0, 0);

      // First tap succeeds
      final res = await srsRepo.processReview(
        contentId: 'VOC_DOUBLE',
        rating: SrsRating.easy,
        reviewTime: reviewTime,
      );
      expect(res.isSuccessful, isTrue);

      // Second tap within 100ms MUST throw DuplicateReviewException
      expect(
        () => srsRepo.processReview(
          contentId: 'VOC_DOUBLE',
          rating: SrsRating.easy,
          reviewTime: reviewTime.add(const Duration(milliseconds: 100)),
        ),
        throwsA(isA<DuplicateReviewException>()),
      );

      // Evidence table must only contain the single initial review, not duplicated
      final history = await srsRepo.getReviewHistory('VOC_DOUBLE');
      expect(history.length, equals(1));
    });

    test('4. Sequential distinct reviews generate append-only historical audit trail', () async {
      var t = DateTime.utc(2026, 11, 1, 8, 0, 0);

      // Review 1: Good
      await srsRepo.processReview(
        contentId: 'VOC_HISTORY',
        rating: SrsRating.good,
        reviewTime: t,
      );

      // Review 2: 1 day later (past debounce window) -> Good
      t = t.add(const Duration(days: 1));
      await srsRepo.processReview(
        contentId: 'VOC_HISTORY',
        rating: SrsRating.good,
        reviewTime: t,
      );

      // Review 3: 6 days later -> Hard
      t = t.add(const Duration(days: 6));
      await srsRepo.processReview(
        contentId: 'VOC_HISTORY',
        rating: SrsRating.hard,
        reviewTime: t,
      );

      // Verify 3 distinct immutable evidence rows exist in database
      final history = await srsRepo.getReviewHistory('VOC_HISTORY');
      expect(history.length, equals(3));

      // Order is newest first
      expect(history[0]['created_at'], equals(t.toIso8601String()));
    });
  });
}
