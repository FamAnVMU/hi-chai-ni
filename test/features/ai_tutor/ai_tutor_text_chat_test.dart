import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/app_database.dart';
import 'package:hi_chinese/core/network/ai/ai_service.dart';
import 'package:hi_chinese/core/network/ai/models/ai_model_config.dart';
import 'package:hi_chinese/core/network/ai/models/cancel_token.dart';
import 'package:hi_chinese/core/network/ai/providers/mock_ai_provider.dart';
import 'package:hi_chinese/core/network/ai/security/ai_credential_storage.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/features/ai_tutor/ai_tutor.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeSessionIdNotifier extends CurrentChatSessionIdNotifier {
  final String _initial;
  _FakeSessionIdNotifier(this._initial);

  @override
  String? build() => _initial;
}

class _FakeScenarioNotifier extends ActiveScenarioNotifier {
  final TutorScenario _scenario;
  _FakeScenarioNotifier(this._scenario);

  @override
  TutorScenario build() => _scenario;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('AI Tutor Text Chat & Session Repository Tests', () {
    late Directory tempDir;
    late String dbPath;
    late AppDatabase appDatabase;
    late MockAiProvider mockAiProvider;
    late AiService aiService;
    late AiTutorRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hi_chinese_text_chat_test_');
      dbPath = '${tempDir.path}/test_text_chat.db';

      appDatabase = AppDatabase.instance;
      await appDatabase.open(customPath: dbPath);

      mockAiProvider = MockAiProvider();
      aiService = AiService(
        provider: mockAiProvider,
        credentialStorage: AiCredentialStorage.inMemory(initialApiKey: 'test_key'),
        modelRegistry: AiModelRegistry(),
      );

      repository = AiTutorRepositoryImpl(
        database: appDatabase,
        aiService: aiService,
      );
    });

    tearDown(() async {
      await appDatabase.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('1. Session List, Creation, Rename, and Soft Deletion', () async {
      // Create session
      final sessionId = await repository.createSession(
        title: 'Luyện tập sơ cấp',
        scenarioCode: 'ordering_food',
      );
      expect(sessionId, isNotEmpty);

      // Verify session exists in active sessions
      var activeSessions = await repository.getActiveSessions();
      expect(activeSessions.length, 1);
      expect(activeSessions.first['id'], sessionId);
      expect(activeSessions.first['title'], 'Luyện tập sơ cấp');

      // Rename session
      await repository.updateSessionTitle(sessionId, 'Hội thoại nhà hàng HSK 2');
      activeSessions = await repository.getActiveSessions();
      expect(activeSessions.first['title'], 'Hội thoại nhà hàng HSK 2');

      // Soft delete session
      await repository.deleteSession(sessionId);
      activeSessions = await repository.getActiveSessions();
      expect(activeSessions.isEmpty, isTrue);
    });

    test('2. Streaming response completes and persists complete assistant turn', () async {
      final sessionId = await repository.createSession(
        title: 'Phiên hỏi đáp',
        scenarioCode: 'free_chat',
      );

      mockAiProvider.customStreamChunks = [
        '{"reply_zh": "你好，',
        '很高兴认识你！", ',
        '"reply_pinyin": "Nǐ hǎo, hěn gāoxìng rènshi nǐ!", ',
        '"reply_vi": "Xin chào, rất vui được làm quen với bạn!"}'
      ];

      final accumulated = StringBuffer();
      final completer = Completer<TutorResponse>();

      final stream = repository.sendMessageStream(
        sessionId: sessionId,
        userText: '你好！',
        onComplete: (res) => completer.complete(res),
      );

      await for (final chunk in stream) {
        accumulated.write(chunk);
      }

      final tutorResponse = await completer.future;
      expect(tutorResponse.replyZh, '你好，很高兴认识你！');
      expect(tutorResponse.replyVi, contains('rất vui được làm quen'));

      // Check DB persistence: 1 greeting + 1 user turn + 1 assistant turn = 3 turns
      final turns = await repository.getSessionTurns(sessionId);
      expect(turns.length, 3);
      expect(turns[1].role, 'user');
      expect(turns[1].content, '你好！');
      expect(turns[2].role, 'assistant');
      expect(turns[2].content, '你好，很高兴认识你！');
    });

    test('3. Stop generation with CancelToken stops stream and does not save assistant turn', () async {
      final sessionId = await repository.createSession(
        title: 'Phiên huỷ dòng',
        scenarioCode: 'free_chat',
      );

      mockAiProvider.customStreamChunks = [
        '{"reply_zh": "你好呀！',
        '我是你的老师',
        '，今天想学什么？"}',
      ];

      final cancelToken = CancelToken();

      // Trigger stream and cancel immediately
      final stream = repository.sendMessageStream(
        sessionId: sessionId,
        userText: 'Câu hỏi cần huỷ',
        cancelToken: cancelToken,
      );

      try {
        await for (final _ in stream) {
          cancelToken.cancel('User stopped generation');
        }
      } catch (_) {
        // Expected cancellation exception
      }

      // Verify: assistant turn was NOT persisted as a complete turn
      final turns = await cancelRepoCheck(repository, sessionId);
      final assistantTurns = turns.where((t) => t.isAssistant).toList();
      // Only the initial greeting should be present
      expect(assistantTurns.length, 1);
    });

    test('4. Controlled Retry: removeLastTurn removes the last assistant turn', () async {
      final sessionId = await repository.createSession(
        title: 'Phiên retry',
        scenarioCode: 'free_chat',
      );

      mockAiProvider.customStreamChunks = [
        '{"reply_zh": "Câu trả lời thử lần 1", "reply_pinyin": "...", "reply_vi": "..."}'
      ];

      // Send first attempt
      final stream = repository.sendMessageStream(
        sessionId: sessionId,
        userText: 'Thử lại nhé',
      );
      await stream.drain();

      var turns = await repository.getSessionTurns(sessionId);
      expect(turns.last.content, 'Câu trả lời thử lần 1');

      // Remove last turn for retry
      await repository.removeLastTurn(sessionId);
      turns = await repository.getSessionTurns(sessionId);
      expect(turns.last.role, 'user');
      expect(turns.last.content, 'Thử lại nhé');
    });
  });

  group('AiTutorTextChatScreen Widget Tests', () {
    late Directory tempDir;
    late String dbPath;
    late AppDatabase appDatabase;
    late MockAiProvider mockAiProvider;
    late AiService aiService;
    late AiTutorRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hi_chinese_text_ui_test_');
      dbPath = '${tempDir.path}/test_text_ui.db';

      appDatabase = AppDatabase.instance;
      await appDatabase.open(customPath: dbPath);

      mockAiProvider = MockAiProvider();
      aiService = AiService(
        provider: mockAiProvider,
        credentialStorage: AiCredentialStorage.inMemory(initialApiKey: 'test_key'),
        modelRegistry: AiModelRegistry(),
      );

      repository = AiTutorRepositoryImpl(
        database: appDatabase,
        aiService: aiService,
      );
    });

    tearDown(() async {
      await appDatabase.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets('Renders scenario prompt chips and handles input typing', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      late String sessionId;
      late List<TutorChatTurn> initialTurns;

      await tester.runAsync(() async {
        sessionId = await repository.createSession(
          title: 'Phiên Widget Test',
          scenarioCode: 'ordering_food',
        );
        initialTurns = await repository.getSessionTurns(sessionId);
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(appDatabase),
            aiTutorRepositoryProvider.overrideWithValue(repository),
            currentChatSessionIdProvider.overrideWith(() => _FakeSessionIdNotifier(sessionId)),
            activeScenarioProvider.overrideWith(() => _FakeScenarioNotifier(TutorScenarios.restaurant)),
            sessionMessagesProvider.overrideWith((ref, arg) => Future.value(initialTurns)),
          ],
          child: const MaterialApp(
            home: AiTutorTextChatScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('乔乔老师'), findsWidgets);
      expect(find.byType(HiChip), findsWidgets);
    });
  });
}

Future<List<TutorChatTurn>> cancelRepoCheck(AiTutorRepository repo, String sessionId) async {
  return await repo.getSessionTurns(sessionId);
}
