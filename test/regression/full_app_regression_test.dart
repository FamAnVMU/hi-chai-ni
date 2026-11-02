import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/dao/app_settings_dao.dart';
import 'package:hi_chinese/core/database/database_backup_helper.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/core/utils/permission_helper.dart';
import 'package:hi_chinese/features/ai_tutor/ai_tutor.dart';
import 'package:hi_chinese/features/grammar/grammar.dart';
import 'package:hi_chinese/features/hanzi_writing/hanzi_writing.dart';
import 'package:hi_chinese/features/listening/listening.dart';
import 'package:hi_chinese/features/placement_test/domain/engine/cat_engine.dart';
import 'package:hi_chinese/features/placement_test/domain/models/cat_skill.dart';
import 'package:hi_chinese/features/practice/practice.dart';
import 'package:hi_chinese/features/profile/data/repositories/profile_repository.dart';
import 'package:hi_chinese/features/pronunciation/pronunciation.dart';
import 'package:hi_chinese/features/roadmap/roadmap.dart';
import 'package:hi_chinese/features/settings/data/services/data_management_service.dart';
import 'package:hi_chinese/features/shadowing/shadowing.dart';
import 'package:hi_chinese/features/vocabulary_srs/vocabulary_srs.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late Directory tempDir;
  late String dbPath;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('regression_master_');
    dbPath = '${tempDir.path}/regression_hi_chinese.db';
    db = await databaseFactory.openDatabase(dbPath);

    // Apply migrations v0 -> v8
    final engine = MigrationEngine();
    await engine.executeMigrations(db, 0, DatabaseConstants.currentDatabaseVersion);
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('HI Chinese Master Regression Test Suite', () {
    // ------------------------------------------------------------------------
    // 1. DATABASE & SCHEMA MIGRATION v8
    // ------------------------------------------------------------------------
    test('1. Database Engine & Schema v8 Integrity', () async {
      final issues = await DatabaseBackupHelper.checkIntegrity(db);
      expect(issues, isEmpty, reason: 'Database integrity check must report 100% OK');

      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table';");
      final tableNames = tables.map((t) => t['name'] as String).toSet();

      expect(tableNames, contains(DatabaseConstants.tableVocabularies));
      expect(tableNames, contains(DatabaseConstants.tableGrammarItems));
      expect(tableNames, contains(DatabaseConstants.tableSrsItems));
      expect(tableNames, contains(DatabaseConstants.tablePlacementTestSessions));
      expect(tableNames, contains(DatabaseConstants.tablePracticeExercises));
      expect(tableNames, contains(DatabaseConstants.tableUserProfiles));
      expect(tableNames, contains(DatabaseConstants.tableGoalHistory));
      expect(tableNames, contains(DatabaseConstants.tableAppSettings));
    });

    // ------------------------------------------------------------------------
    // 2. SRS ENGINE REGRESSION
    // ------------------------------------------------------------------------
    test('2. SM-2 Pure Engine calculates ease factor delta, bounds and intervals', () {
      const engine = Sm2Engine();
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

      // Minimum floor threshold
      expect(engine.calculateNewEaseFactor(1.4, 1), equals(1.3));
    });

    // ------------------------------------------------------------------------
    // 3. AI TUTOR, CONTEXT BUILDER & PARSER
    // ------------------------------------------------------------------------
    test('3. AI Tutor Prompt Builder, Context Pruning & Response Parser', () {
      final prompt = TutorSystemPromptBuilder.build(
        const TutorPromptOptions(
          persona: TutorPersonas.qiaoqiao,
          scenario: TutorScenarios.restaurant,
          learnerHskLevel: 2,
          learnerName: 'Nguyễn Văn A',
        ),
      );
      expect(prompt, contains('Gia Sư Tiếng Trung AI'));
      expect(prompt, contains('餐厅点餐'));

      const contextBuilder = TutorContextBuilder(maxHistoryTurns: 4);
      final rawHistory = [
        {'role': 'user', 'content': 'Turn 1'},
        {'role': 'assistant', 'content': 'Turn 2'},
        {'role': 'user', 'content': 'Turn 3'},
        {'role': 'assistant', 'content': 'Turn 4'},
        {'role': 'user', 'content': 'Turn 5'},
        {'role': 'assistant', 'content': 'Turn 6'},
      ];

      final request = contextBuilder.buildRequest(
        rawDbHistory: rawHistory,
        userInput: 'Turn 7',
      );
      expect(request.contents.length, lessThanOrEqualTo(5));

      const jsonText = '''
{
  "reply_zh": "太好了！我也很喜欢中国菜。你最喜欢吃什么？",
  "reply_pinyin": "Tài hǎo le! Wǒ yě hěn xǐhuan Zhōngguó cài. Nǐ zuì xǐhuan chī shénme?",
  "reply_vi": "Tuyệt quá! Tôi cũng rất thích món ăn Trung Quốc. Bạn thích ăn món gì nhất?",
  "evaluation": {
    "is_correct": true,
    "original_text": "我很喜欢中国菜",
    "corrected_text": null,
    "pinyin": "Wǒ hěn xǐhuan Zhōngguó cài",
    "explanation_vi": "Câu của bạn rất chuẩn và tự nhiên!"
  },
  "follow_up_suggestions": [
    "我最喜欢北京烤鸭",
    "中国菜太辣了"
  ],
  "target_vocabulary": ["中国菜"]
}
''';

      final response = TutorResponseParser.parse(jsonText);
      expect(response.replyZh, contains('太好了'));
      expect(response.replyVi, contains('Tuyệt quá'));
      expect(response.evaluation, isNotNull);
      expect(response.evaluation!.isCorrect, isTrue);
      expect(response.followUpSuggestions.length, 2);
    });

    test('4. Voice Conversation Machine 10 States & Live API Preview Info', () {
      expect(VoiceConversationStatus.values.length, 10);
      expect(VoiceConversationStatus.values, containsAll([
        VoiceConversationStatus.idle,
        VoiceConversationStatus.requestingPermission,
        VoiceConversationStatus.connecting,
        VoiceConversationStatus.listening,
        VoiceConversationStatus.processing,
        VoiceConversationStatus.speaking,
        VoiceConversationStatus.interrupted,
        VoiceConversationStatus.reconnecting,
        VoiceConversationStatus.error,
        VoiceConversationStatus.ended,
      ]));

      const info = LiveApiPreviewInfo();
      expect(info.isPreview, isTrue);
      expect(info.previewModelName, contains('gemini-2.0-flash-exp'));
      expect(info.limitationNotice, contains('Voice Live API'));
      expect(info.isDeviceSupported, isTrue);
    });

    // ------------------------------------------------------------------------
    // 4. PLACEMENT TEST (CAT IRT FORMULAS)
    // ------------------------------------------------------------------------
    test('5. Computerized Adaptive Testing (CAT) 2PL IRT calculation', () {
      final p = CatEngine.calculateProbability(0.0, 0.0, 1.0);
      expect(p, closeTo(0.5, 0.001));

      final info = CatEngine.calculateInformation(0.0, 0.0, 1.0);
      expect(info, closeTo(0.25, 0.001));

      final pHigh = CatEngine.calculateProbability(2.0, 0.0, 1.0);
      expect(pHigh, greaterThan(0.8));

      final pLow = CatEngine.calculateProbability(-2.0, 0.0, 1.0);
      expect(pLow, lessThan(0.2));

      expect(CatSkill.values.length, 6);
    });

    // ------------------------------------------------------------------------
    // 5. ROADMAP, GRAMMAR & PRACTICE
    // ------------------------------------------------------------------------
    test('6. Adaptive Roadmap generates structured sequence from learner context', () {
      const engine = AdaptiveRoadmapEngine();
      final goal = LearnerGoal.defaultGoal();
      final context = AdaptiveRoadmapContext(
        goal: goal,
        currentLevel: goal.targetHskLevel,
        progressMap: const {},
        recentEvidence: const [],
        skillMasteryScores: const {},
      );

      final state = engine.generateRoadmap(context);
      expect(state.currentLevel, 1);
      expect(state.activeGoal.targetHskLevel, 1);
      expect(state.recommendations, isNotEmpty);
    });

    test('7. Grammar Evaluation Engine scores multiple choice deterministically', () {
      const engine = GrammarEvaluationEngine();
      const exercise = GrammarExercise(
        id: 'ex_mc_1',
        type: GrammarExerciseType.multipleChoice,
        prompt: 'Chọn từ đúng:',
        sentenceWithBlank: '李明 ___ 老师。',
        options: ['是', '在', '有'],
        correctAnswerIndex: 0,
        targetSentence: '李明是老师。',
        explanationVi: 'Câu phán đoán dùng 是.',
      );

      final resultCorrect = engine.evaluate(
        exercise: exercise,
        selectedOptionIndex: 0,
      );
      expect(resultCorrect.isCorrect, isTrue);
      expect(resultCorrect.score, 1.0);

      final resultWrong = engine.evaluate(
        exercise: exercise,
        selectedOptionIndex: 1,
      );
      expect(resultWrong.isCorrect, isFalse);
      expect(resultWrong.score, 0.0);
    });

    test('8. Practice Scoring Engine evaluates exercises with partial credit and idempotency', () async {
      const scoringEngine = PracticeScoringEngine();

      final mcDef = PracticeSeedCatalog.items.firstWhere((e) => e.type == ExerciseType.multipleChoice);
      final resCorrect = await scoringEngine.evaluate(
        definition: mcDef,
        answer: const ExerciseAnswer(exerciseId: 'EX_MC_VOCAB_01', selectedOptionIndex: 0),
      );
      expect(resCorrect.isCorrect, isTrue);
      expect(resCorrect.score, 1.0);

      final matchDef = PracticeSeedCatalog.items.firstWhere((e) => e.type == ExerciseType.matchingPairs);
      final resMatch = await scoringEngine.evaluate(
        definition: matchDef,
        answer: const ExerciseAnswer(
          exerciseId: 'EX_MATCH_VOCAB_03',
          matchedPairs: {
            '你好': 'Xin chào',
            '谢谢': 'Cảm ơn',
            '再见': 'Sai',
          },
        ),
      );
      expect(resMatch.isCorrect, isFalse);
      expect(resMatch.score, 0.5);
    });

    // ------------------------------------------------------------------------
    // 6. DICTIONARY, READING & LISTENING
    // ------------------------------------------------------------------------
    test('9. Reading RubyText and Listening Comprehension', () async {
      final seg = RubySegment.word(
        hanzi: '学习',
        pinyin: 'xuéxí',
        wordId: 'w_101',
        meaning: 'học tập',
        traditionalText: '學習',
      );
      expect(seg.text, '学习');
      expect(seg.pinyin, 'xuéxí');
      expect(seg.meaning, 'học tập');

      final listeningRepo = DefaultListeningRepository();
      final lessons = await listeningRepo.getLessons(hskLevel: 1);
      expect(lessons.isNotEmpty, isTrue);
      expect(lessons.first.questions.isNotEmpty, isTrue);
      expect(lessons.first.transcriptZh, isNotEmpty);
    });

    // ------------------------------------------------------------------------
    // 7. HANZI WRITING & PRONUNCIATION / SHADOWING
    // ------------------------------------------------------------------------
    test('10. Hanzi Writing Stroke Evaluation on "十" (先横后竖)', () {
      const bank = HanziStrokeBank();
      const evaluator = StrokeEvaluator();
      const canvasSize = Size(320.0, 320.0);

      final shiData = bank.getStrokeData('十')!;

      final stroke1 = DrawnStroke(points: [
        StrokePoint(offset: const Offset(64, 144), pressure: 1.0, timestamp: DateTime.now()),
        StrokePoint(offset: const Offset(256, 144), pressure: 1.0, timestamp: DateTime.now()),
      ]);

      final stroke2 = DrawnStroke(points: [
        StrokePoint(offset: const Offset(160, 64), pressure: 1.0, timestamp: DateTime.now()),
        StrokePoint(offset: const Offset(160, 256), pressure: 1.0, timestamp: DateTime.now()),
      ]);

      final result = evaluator.evaluate(
        drawnStrokes: [stroke1, stroke2],
        canvasSize: canvasSize,
        strokeData: shiData,
        mode: WritingMode.tracing,
      );

      expect(result.scorePercent, 100);
      expect(result.isPassed, isTrue);
    });

    test('11. Pronunciation & Shadowing objective evaluation', () async {
      const target = PronunciationTarget(
        id: 'TONE_01_MA1',
        text: '妈',
        pinyin: 'mā',
        meaningVi: 'Mẹ',
        category: PronunciationCategory.tone,
      );

      const service = DefaultPronunciationAnalysisService(
        providerId: 'local_text_asr',
        hasAcousticModel: false,
      );

      final pronResult = await service.evaluatePronunciation(
        target: target,
        audioPath: 'dummy.wav',
        duration: const Duration(milliseconds: 600),
      );
      expect(pronResult.overallScore, isNotNull);

      const evaluator = ShadowingEvaluator();
      const segment = ShadowingSegment(
        id: 'SEG_TEST_01',
        order: 1,
        hanzi: '你好，请问你是王老师吗？',
        pinyin: 'Nǐ hǎo, qǐngwèn nǐ shì Wáng lǎoshī ma?',
        meaningVi: 'Xin chào, xin hỏi bạn có phải là thầy Vương không?',
        durationMs: 3000,
      );

      final shadowResult = evaluator.evaluate(
        segment: segment,
        userDuration: const Duration(milliseconds: 3000),
        mode: ShadowingMode.listenThenRepeat,
        speed: ShadowingPlaybackSpeed.normal,
      );
      expect(shadowResult.pacingRatio, equals(1.0));
      expect(shadowResult.pacingVerdict, contains('Chuẩn nhịp độ bản xứ'));
      expect(shadowResult.timelineMatchPercent, equals(100.0));
    });

    // ------------------------------------------------------------------------
    // 8. PROFILE, SETTINGS & SAFE DATA MANAGEMENT
    // ------------------------------------------------------------------------
    test('12. Profile Repository updates goal with required reason and logs history', () async {
      final profileRepo = DefaultProfileRepository(db);
      final initial = await profileRepo.getProfile();
      expect(initial.targetHskLevel, 3);

      await profileRepo.updateGoal(
        targetHskLevel: 4,
        dailyMinutes: 45,
        purpose: LearnerPurpose.businessWork,
        reason: 'Nâng mục tiêu phục vụ đàm phán hợp đồng thương mại',
      );

      final updated = await profileRepo.getProfile();
      expect(updated.targetHskLevel, 4);
      expect(updated.dailyMinutes, 45);

      final history = await profileRepo.getGoalHistory();
      expect(history.length, 1);
      expect(history.first.reason, contains('đàm phán hợp đồng'));
    });

    test('13. App Settings DAO saves and restores configuration', () async {
      final settingsDao = AppSettingsDao(db);
      await settingsDao.setSetting('theme_mode', 'dark');
      await settingsDao.setSetting('font_scale', '1.15');

      final all = await settingsDao.getAllSettings();
      expect(all['theme_mode'], 'dark');
      expect(all['font_scale'], '1.15');
    });

    test('14. Data Management Service enforces backup, integrity check, and protected reset', () async {
      final dataService = DataManagementService(db, dbPath);

      final backup = await dataService.createBackup();
      expect(await backup.exists(), isTrue);

      final integrity = await dataService.checkIntegrity();
      expect(integrity, isEmpty);

      final jsonExport = await dataService.exportUserDataJson();
      expect(jsonExport, contains('"app_name": "HI Chinese"'));

      expect(
        () => dataService.clearAllUserData(confirmationCode: 'SAI'),
        throwsA(isA<DestructiveActionException>()),
      );

      await dataService.clearAllUserData(confirmationCode: 'RESET');
      final backups = await dataService.listBackups();
      expect(backups.any((b) => b.path.contains('pre_destruction_safety_snapshot')), isTrue);
    });

    test('15. Audio Permission Helper checks status without forced startup prompt', () async {
      PermissionHelper.mockPermissionStatus = PermissionStatus.granted;
      final status = await PermissionHelper.checkMicrophoneStatus();
      expect(status.isGranted, isTrue);
      PermissionHelper.mockPermissionStatus = null;
    });
  });
}
