import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/core/network/ai/ai.dart';
import 'package:hi_chinese/features/reading/reading.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late Directory tempDir;
  late MockAiProvider mockAiProvider;
  late AiService aiService;
  late ReadingRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rdg_test_');
    final dbPath = '${tempDir.path}/test_reading.db';
    db = await databaseFactory.openDatabase(dbPath);

    final engine = MigrationEngine();
    await engine.executeMigrations(db, 0, DatabaseConstants.currentDatabaseVersion);

    mockAiProvider = MockAiProvider();
    aiService = AiService(
      provider: mockAiProvider,
      credentialStorage: AiCredentialStorage.inMemory(initialApiKey: 'test_key'),
      modelRegistry: AiModelRegistry(),
    );
    repository = DefaultReadingRepository(db, aiService: aiService);

    // Insert test passage into SQLite
    final now = DateTime.utc(2026, 11, 1).toIso8601String();
    await db.insert(DatabaseConstants.tableReadingPassages, {
      'id': 'RDG_TEST_01',
      'hsk_level': 1,
      'title_cn': '我的朋友',
      'content_cn': '我有一个好朋友，他叫李明。他是中国人。',
      'pinyin': 'Wǒ yǒu yí gè hǎo péngyou, tā jiào Lǐ Míng. Tā shì Zhōngguó rén.',
      'translation_vi': 'Tôi có một người bạn tốt, anh ấy tên Lý Minh. Anh ấy là người Trung Quốc.',
      'audio_uri': null,
      'questions_json': '[{"id":"q1","type":"single_choice","question":"李明是哪国人？","options":["中国人","美国人"],"answer":0,"explanationVi":"Bài nêu rõ李明是中国人"}]',
      'created_at': now,
      'updated_at': now,
    });
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('ReadingRepository SQLite & Persistence Tests', () {
    test('1. getPassages loads passages from DB and filters by HSK level', () async {
      final allPassages = await repository.getPassages();
      expect(allPassages, isNotEmpty);
      expect(allPassages.any((p) => p.id == 'RDG_TEST_01'), isTrue);

      final hsk1Only = await repository.getPassages(hskLevel: 1);
      expect(hsk1Only.every((p) => p.hskLevel == 1), isTrue);

      final hsk5Only = await repository.getPassages(hskLevel: 5);
      expect(hsk5Only.every((p) => p.hskLevel == 5), isTrue);
    });

    test('2. Unfinished reading session saves scroll offset and duration without completion', () async {
      await repository.saveReadingSession(
        passageId: 'RDG_TEST_01',
        readingTimeSeconds: 45,
        lastScrollOffset: 120.5,
        answers: const {'q1': 0},
        isCompleted: false,
      );

      final progress = await repository.getProgress('RDG_TEST_01');
      expect(progress, isNotNull);
      expect(progress!.isCompleted, isFalse);
      expect(progress.readingTimeSeconds, equals(45));
      expect(progress.lastScrollOffset, equals(120.5));
      expect(progress.score, isNull);

      // Verify NO learner_evidence or learning_activities rows were created yet
      final evidence = await db.query(DatabaseConstants.tableLearnerEvidence);
      expect(evidence, isEmpty);
      final activities = await db.query(DatabaseConstants.tableLearningActivities);
      expect(activities, isEmpty);
    });

    test('3. Completed reading session persists evidence and updates learning streak', () async {
      await repository.saveReadingSession(
        passageId: 'RDG_TEST_01',
        readingTimeSeconds: 90,
        lastScrollOffset: 300.0,
        answers: const {'q1': 0},
        isCompleted: true,
        score: 100.0,
      );

      final progress = await repository.getProgress('RDG_TEST_01');
      expect(progress, isNotNull);
      expect(progress!.isCompleted, isTrue);
      expect(progress.score, equals(100.0));
      expect(progress.completedAt, isNotNull);

      // Verify learner_evidence has recorded source 'reading_comprehension'
      final evidence = await db.query(
        DatabaseConstants.tableLearnerEvidence,
        where: "source = 'reading_comprehension'",
      );
      expect(evidence, hasLength(1));
      expect(evidence.first['content_id'], equals('RDG_TEST_01'));
      expect(evidence.first['score'], equals(1.0));

      // Verify learning_activities has logged 'reading' to sustain streak
      final activities = await db.query(
        DatabaseConstants.tableLearningActivities,
        where: "activity_type = 'reading'",
      );
      expect(activities, hasLength(1));
      expect(activities.first['duration_seconds'], equals(90));
    });

    test('4. askAiAboutPassage returns real AI pedagogical response via AiService (Task 3.2)', () async {
      mockAiProvider.customTextResponse =
          'Giải thích AI: Trong đoạn văn "他叫李明。他是中国人。", câu hỏi của bạn về quốc tịch được giải đáp rõ: Lý Minh là người Trung Quốc (中国人).';
      final response = await repository.askAiAboutPassage(
        passageText: '他是中国人。',
        userQuestion: 'Là người nước nào?',
      );
      expect(response, contains('Giải thích AI'));
      expect(response, contains('中国人'));
    });

    test('5. askAiAboutPassage throws AiAuthenticationException when no API key configured (Task 3.2)', () async {
      final unauthedAiService = AiService(
        provider: GeminiRestAiProvider(
          credentialStorage: AiCredentialStorage.inMemory(initialApiKey: null),
        ),
        credentialStorage: AiCredentialStorage.inMemory(initialApiKey: null),
        modelRegistry: AiModelRegistry(),
      );
      final unauthedRepo = DefaultReadingRepository(db, aiService: unauthedAiService);

      expect(
        () => unauthedRepo.askAiAboutPassage(
          passageText: '他是中国人。',
          userQuestion: 'Là người nước nào?',
        ),
        throwsA(isA<AiAuthenticationException>()),
      );
    });

    test('6. askAiAboutPassage supports CancelToken and cancels gracefully (Task 3.2)', () async {
      final cancelToken = CancelToken();
      cancelToken.cancel();

      expect(
        () => repository.askAiAboutPassage(
          passageText: '他是中国人。',
          userQuestion: 'Là người nước nào?',
          cancelToken: cancelToken,
        ),
        throwsA(isA<AiCancelledException>()),
      );
    });
  });
}
