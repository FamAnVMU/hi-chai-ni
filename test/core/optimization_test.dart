import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/app_database.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/network/ai/ai.dart';
import 'package:hi_chinese/features/ai_tutor/ai_tutor.dart';
import 'package:hi_chinese/features/vocabulary_srs/vocabulary_srs.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('1. SQLite Engine PRAGMAs & Performance Tuning Tests', () {
    late Directory tempDir;
    late String dbPath;
    late AppDatabase appDatabase;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hi_chinese_opt_test_');
      dbPath = '${tempDir.path}/opt_test.db';
      appDatabase = AppDatabase.instance;
      await appDatabase.open(customPath: dbPath);
    });

    tearDown(() async {
      await appDatabase.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('SQLite engine activates 8MB page cache and in-memory temp store', () async {
      final db = appDatabase.database;

      final cacheSizeResult = await db.rawQuery('PRAGMA cache_size;');
      final cacheSize = cacheSizeResult.first.values.first as int;
      expect(cacheSize, equals(-8000)); // -8000 KiB = 8MB

      final tempStoreResult = await db.rawQuery('PRAGMA temp_store;');
      final tempStore = tempStoreResult.first.values.first as int;
      expect(tempStore, equals(2)); // 2 = MEMORY
    });

    test('wal_checkpoint and PRAGMA optimize execute smoothly', () async {
      // Execute manual checkpoints
      await appDatabase.checkpoint(truncate: false);
      await appDatabase.checkpoint(truncate: true);

      // Execute query planner cost optimization
      await appDatabase.optimize();

      final integrity = await appDatabase.checkIntegrity();
      expect(integrity, isEmpty); // Empty issues list indicates 100% healthy database
    });

    test('Composite indexes for rapid learning evidence and chat lookup exist', () async {
      final db = appDatabase.database;

      final indexes = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'index';",
      );
      final indexNames = indexes.map((row) => row['name'] as String).toSet();

      expect(indexNames, contains('idx_evidence_type_score'));
      expect(indexNames, contains('idx_chat_messages_lookup'));
    });
  });

  group('2. SRS Repository Due Count Memoization Tests', () {
    late Directory tempDir;
    late String dbPath;
    late AppDatabase appDatabase;
    late SrsRepository srsRepository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hi_chinese_srs_opt_');
      dbPath = '${tempDir.path}/srs_opt.db';
      appDatabase = AppDatabase.instance;
      final db = await appDatabase.open(customPath: dbPath);
      srsRepository = SrsRepository(db);
    });

    tearDown(() async {
      await appDatabase.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('getDueCardsCount caches result and auto-invalidates upon review', () async {
      // 1. Initially 0 due cards
      final initialCount = await srsRepository.getDueCardsCount();
      expect(initialCount, equals(0));

      // 2. Insert a due card directly into SQLite
      final nowUtc = DateTime.now().toUtc();
      final db = appDatabase.database;
      await db.insert(DatabaseConstants.tableSrsItems, {
        'id': 'SRS_VOCAB_test1',
        'content_id': 'v_test1',
        'content_type': 'vocabulary',
        'state': 'learning',
        'interval_days': 1,
        'ease_factor': 2.5,
        'repetitions': 1,
        'lapses': 0,
        'due_at': nowUtc.subtract(const Duration(minutes: 5)).toIso8601String(),
        'created_at': nowUtc.toIso8601String(),
        'updated_at': nowUtc.toIso8601String(),
      });

      // 3. Cached count returns 0 (cache hit within 60s TTL)
      final cachedCount = await srsRepository.getDueCardsCount();
      expect(cachedCount, equals(0));

      // 4. Force clearing cache picks up fresh count = 1
      srsRepository.clearCache();
      final freshCount = await srsRepository.getDueCardsCount();
      expect(freshCount, equals(1));

      // 5. Process a review turn -> cache is automatically invalidated!
      await srsRepository.processReview(
        contentId: 'v_test1',
        rating: SrsRating.good,
      );

      // Now due count is automatically recalculated as 0 because card is scheduled in future
      final afterReviewCount = await srsRepository.getDueCardsCount();
      expect(afterReviewCount, equals(0));
    });
  });

  group('3. LearnerContextService In-Memory Caching Tests', () {
    late Directory tempDir;
    late String dbPath;
    late AppDatabase appDatabase;
    const contextService = LearnerContextService();

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hi_chinese_ctx_opt_');
      dbPath = '${tempDir.path}/ctx_opt.db';
      appDatabase = AppDatabase.instance;
      await appDatabase.open(customPath: dbPath);
      LearnerContextService.invalidateCache();
    });

    tearDown(() async {
      LearnerContextService.invalidateCache();
      await appDatabase.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('buildContext memoizes context per session and invalidates on request', () async {
      final db = appDatabase.database;
      const sessionId = 'session_opt_123';

      // 1. First build creates fresh context
      final context1 = await contextService.buildContext(
        db,
        sessionId: sessionId,
        learnerName: 'Học viên A',
      );
      expect(context1.profile.learnerName, equals('Học viên A'));

      // 2. Second build within TTL returns the exact same instance from memory
      final context2 = await contextService.buildContext(
        db,
        sessionId: sessionId,
        learnerName: 'Học viên B', // Different param, but cache returns cached instance
      );
      expect(identical(context1, context2), isTrue);

      // 3. Invalidate cache for sessionId
      LearnerContextService.invalidateCache(sessionId);

      // 4. Third build re-computes with new parameters
      final context3 = await contextService.buildContext(
        db,
        sessionId: sessionId,
        learnerName: 'Học viên B',
      );
      expect(identical(context1, context3), isFalse);
      expect(context3.profile.learnerName, equals('Học viên B'));
    });
  });

  group('4. Resource Disposal & Lifecycle Tests', () {
    test('AiService and GeminiRestAiProvider dispose client connections cleanly', () {
      final storage = AiCredentialStorage.inMemory();
      final provider = GeminiRestAiProvider(credentialStorage: storage);
      final service = AiService(
        provider: provider,
        credentialStorage: storage,
      );

      // Verify dispose can be invoked without exception
      service.dispose();
      provider.dispose();
    });
  });
}
