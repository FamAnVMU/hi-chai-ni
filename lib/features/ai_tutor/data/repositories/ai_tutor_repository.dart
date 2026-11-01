import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/dao/chat_dao.dart';
import '../../../../core/database/dao/learner_evidence_dao.dart';
import '../../../../core/network/ai/ai_service.dart';
import '../../../../core/network/ai/models/ai_model_config.dart';
import '../../../../core/network/ai/models/cancel_token.dart';
import '../../domain/context/learner_context_service.dart';
import '../../domain/context/tutor_context_builder.dart';
import '../../domain/models/learning_evidence_proposal.dart';
import '../../domain/models/tutor_chat_turn.dart';
import '../../domain/models/tutor_correction.dart';
import '../../domain/models/tutor_persona.dart';
import '../../domain/models/tutor_response.dart';
import '../../domain/models/tutor_scenario.dart';
import '../../domain/parsers/tutor_response_parser.dart';

/// Contract for AI Tutor business operations.
abstract class AiTutorRepository {
  Future<String> createSession({
    required String title,
    required String scenarioCode,
    TutorPersonaId personaId = TutorPersonaId.qiaoqiao,
  });

  Future<List<TutorChatTurn>> getSessionTurns(String sessionId);

  Future<TutorResponse> sendMessage({
    required String sessionId,
    required String userText,
    TutorPersona persona = TutorPersonas.qiaoqiao,
    TutorScenario scenario = TutorScenarios.freeChat,
    int learnerHskLevel = 1,
    String learnerName = 'Học viên',
    List<String> weakSrsWords = const [],
    CancelToken? cancelToken,
  });

  Stream<String> sendMessageStream({
    required String sessionId,
    required String userText,
    TutorPersona persona = TutorPersonas.qiaoqiao,
    TutorScenario scenario = TutorScenarios.freeChat,
    int learnerHskLevel = 1,
    String learnerName = 'Học viên',
    List<String> weakSrsWords = const [],
    CancelToken? cancelToken,
    void Function(TutorResponse response)? onComplete,
  });
}

/// Concrete implementation of [AiTutorRepository] using SQLite and [AiService].
class AiTutorRepositoryImpl implements AiTutorRepository {
  final AppDatabase database;
  final AiService aiService;
  final TutorContextBuilder contextBuilder;
  final LearnerContextService learnerContextService;
  final LearningEvidenceValidator evidenceValidator;

  AiTutorRepositoryImpl({
    required this.database,
    required this.aiService,
    TutorContextBuilder? contextBuilder,
    LearnerContextService? learnerContextService,
    LearningEvidenceValidator? evidenceValidator,
  })  : contextBuilder = contextBuilder ?? const TutorContextBuilder(),
        learnerContextService =
            learnerContextService ?? const LearnerContextService(),
        evidenceValidator =
            evidenceValidator ?? const LearningEvidenceValidator();

  Future<DatabaseExecutor> _getDb() async {
    return database.isOpen ? database.database : await database.open();
  }

  @override
  Future<String> createSession({
    required String title,
    required String scenarioCode,
    TutorPersonaId personaId = TutorPersonaId.qiaoqiao,
  }) async {
    final db = await _getDb();
    final chatDao = ChatDao(db);

    final sessionId = 'chat_session_${DateTime.now().millisecondsSinceEpoch}_$scenarioCode';
    final nowUtc = DateTime.now().toUtc().toIso8601String();

    await chatDao.insertSession({
      'id': sessionId,
      'title': title,
      'scenario_code': scenarioCode,
      'is_archived': 0,
      'created_at': nowUtc,
      'updated_at': nowUtc,
    });

    // Insert the scenario's initial greeting turn as the opening assistant message
    final scenario = TutorScenarios.fromCode(scenarioCode);
    final greetingMessageId = 'msg_${DateTime.now().millisecondsSinceEpoch}_greeting';

    await chatDao.insertMessage({
      'id': greetingMessageId,
      'session_id': sessionId,
      'role': 'assistant',
      'content': scenario.initialAiGreetingZh,
      'pinyin': scenario.initialAiGreetingPinyin,
      'translation_vi': scenario.initialAiGreetingVi,
      'audio_uri': null,
      'tokens_used': 0,
      'created_at': nowUtc,
    });

    return sessionId;
  }

  @override
  Future<List<TutorChatTurn>> getSessionTurns(String sessionId) async {
    final db = await _getDb();
    final chatDao = ChatDao(db);
    final rows = await chatDao.getMessagesBySessionId(sessionId);

    return rows.map((row) => TutorChatTurn.fromDbMap(row)).toList();
  }

  @override
  Future<TutorResponse> sendMessage({
    required String sessionId,
    required String userText,
    TutorPersona persona = TutorPersonas.qiaoqiao,
    TutorScenario scenario = TutorScenarios.freeChat,
    int learnerHskLevel = 1,
    String learnerName = 'Học viên',
    List<String> weakSrsWords = const [],
    CancelToken? cancelToken,
  }) async {
    final db = await _getDb();
    final chatDao = ChatDao(db);
    final nowUtc = DateTime.now().toUtc();

    // 1. Save user message to SQLite
    final userMessageId = 'msg_${nowUtc.millisecondsSinceEpoch}_user';
    await chatDao.insertMessage({
      'id': userMessageId,
      'session_id': sessionId,
      'role': 'user',
      'content': userText.trim(),
      'pinyin': null,
      'translation_vi': null,
      'audio_uri': null,
      'tokens_used': 0,
      'created_at': nowUtc.toIso8601String(),
    });
    await chatDao.touchSession(sessionId);

    // 2. Build learner context from DB (runs concurrently with nothing — serial here for simplicity)
    final learnerContext = await learnerContextService.buildContext(
      db,
      sessionId: sessionId,
      hskLevel: learnerHskLevel,
      learnerName: learnerName,
    );

    // 3. Fetch history and build prompt request
    final rawHistory = await chatDao.getMessagesBySessionId(sessionId);
    // Remove the message we just inserted so the context builder can append it cleanly
    final historyExcludingLast =
        rawHistory.isNotEmpty && rawHistory.last['id'] == userMessageId
            ? rawHistory.sublist(0, rawHistory.length - 1)
            : rawHistory;

    final request = contextBuilder.buildRequest(
      userInput: userText,
      rawDbHistory: historyExcludingLast,
      persona: persona,
      scenario: scenario,
      learnerHskLevel: learnerHskLevel,
      learnerName: learnerName,
      weakSrsWords: weakSrsWords,
      learnerContext: learnerContext,
    );

    // 4. Dispatch to AI service
    final aiResponse = await aiService.generateText(
      request,
      taskType: AiTaskType.chatTutor,
      cancelToken: cancelToken,
    );

    // 5. Parse response (pass sessionId so proposals can be attributed)
    final tutorResponse = TutorResponseParser.parse(
      aiResponse.text,
      sessionId: sessionId,
    );

    // 6. Persist assistant reply to SQLite
    final assistantMessageId = 'msg_${DateTime.now().millisecondsSinceEpoch}_assistant';
    await chatDao.insertMessage({
      'id': assistantMessageId,
      'session_id': sessionId,
      'role': 'assistant',
      'content': tutorResponse.replyZh,
      'pinyin': tutorResponse.replyPinyin,
      'translation_vi': tutorResponse.replyVi,
      'audio_uri': null,
      'tokens_used': aiResponse.usageMetadata?.totalTokenCount ?? 0,
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
    await chatDao.touchSession(sessionId);

    // 7. Record evaluation evidence (dialogue-level)
    await _recordEvidenceIfNeeded(
      sessionId: sessionId,
      evaluation: tutorResponse.evaluation,
    );

    // 8. Validate and persist AI evidence proposals
    await _applyValidatedProposals(tutorResponse.evidenceProposals);

    return tutorResponse;
  }

  @override
  Stream<String> sendMessageStream({
    required String sessionId,
    required String userText,
    TutorPersona persona = TutorPersonas.qiaoqiao,
    TutorScenario scenario = TutorScenarios.freeChat,
    int learnerHskLevel = 1,
    String learnerName = 'Học viên',
    List<String> weakSrsWords = const [],
    CancelToken? cancelToken,
    void Function(TutorResponse response)? onComplete,
  }) {
    late final StreamController<String> controller;

    controller = StreamController<String>(
      onListen: () async {
        try {
          final db = await _getDb();
          final chatDao = ChatDao(db);
          final nowUtc = DateTime.now().toUtc();

          // 1. Save user message
          final userMessageId = 'msg_${nowUtc.millisecondsSinceEpoch}_user';
          await chatDao.insertMessage({
            'id': userMessageId,
            'session_id': sessionId,
            'role': 'user',
            'content': userText.trim(),
            'pinyin': null,
            'translation_vi': null,
            'audio_uri': null,
            'tokens_used': 0,
            'created_at': nowUtc.toIso8601String(),
          });
          await chatDao.touchSession(sessionId);

          // 2. Build learner context
          final learnerContext = await learnerContextService.buildContext(
            db,
            sessionId: sessionId,
            hskLevel: learnerHskLevel,
            learnerName: learnerName,
          );

          // 3. Fetch history and build request
          final rawHistory = await chatDao.getMessagesBySessionId(sessionId);
          final historyExcludingLast =
              rawHistory.isNotEmpty && rawHistory.last['id'] == userMessageId
                  ? rawHistory.sublist(0, rawHistory.length - 1)
                  : rawHistory;

          final request = contextBuilder.buildRequest(
            userInput: userText,
            rawDbHistory: historyExcludingLast,
            persona: persona,
            scenario: scenario,
            learnerHskLevel: learnerHskLevel,
            learnerName: learnerName,
            weakSrsWords: weakSrsWords,
            learnerContext: learnerContext,
          );

          // 4. Stream from AI service
          final stream = aiService.streamText(
            request,
            taskType: AiTaskType.chatTutor,
            cancelToken: cancelToken,
          );

          final accumulatedBuffer = StringBuffer();

          await for (final chunk in stream) {
            accumulatedBuffer.write(chunk.text);
            controller.add(chunk.text);
          }

          // 5. On stream completion, parse full accumulated text
          final fullText = accumulatedBuffer.toString();
          final tutorResponse = TutorResponseParser.parse(
            fullText,
            sessionId: sessionId,
          );

          // 6. Save assistant turn to SQLite
          final assistantMessageId =
              'msg_${DateTime.now().millisecondsSinceEpoch}_assistant';
          await chatDao.insertMessage({
            'id': assistantMessageId,
            'session_id': sessionId,
            'role': 'assistant',
            'content': tutorResponse.replyZh,
            'pinyin': tutorResponse.replyPinyin,
            'translation_vi': tutorResponse.replyVi,
            'audio_uri': null,
            'tokens_used': 0,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          });
          await chatDao.touchSession(sessionId);

          // 7. Record evaluation evidence and validated proposals
          await _recordEvidenceIfNeeded(
            sessionId: sessionId,
            evaluation: tutorResponse.evaluation,
          );
          await _applyValidatedProposals(tutorResponse.evidenceProposals);

          onComplete?.call(tutorResponse);
          await controller.close();
        } catch (e, stack) {
          debugPrint('[AiTutorRepository] Streaming error: $e');
          if (!controller.isClosed) {
            controller.addError(e, stack);
            await controller.close();
          }
        }
      },
    );

    return controller.stream;
  }

  // ---------------------------------------------------------------------------
  // Evidence helpers
  // ---------------------------------------------------------------------------

  Future<void> _recordEvidenceIfNeeded({
    required String sessionId,
    required TutorEvaluation? evaluation,
  }) async {
    if (evaluation == null) return;

    try {
      final db = await _getDb();
      final evidenceDao = LearnerEvidenceDao(db);
      final nowUtc = DateTime.now().toUtc().toIso8601String();

      await evidenceDao.appendEvidence({
        'id': 'ev_tutor_${DateTime.now().millisecondsSinceEpoch}',
        'srs_item_id': null,
        'content_id': sessionId,
        'content_type': 'ai_tutor_dialogue',
        'source': 'ai_tutor',
        'score': evaluation.isCorrect ? 1.0 : 0.0,
        'duration_ms': 0,
        'metadata_json': jsonEncode(evaluation.toMap()),
        'created_at': nowUtc,
      });
    } catch (e) {
      debugPrint('[AiTutorRepository] Warning: failed to append learner evidence: $e');
    }
  }

  /// Validates AI-proposed evidence and writes only passing proposals to DB.
  ///
  /// Policy: AI proposes → validator filters → repository writes.
  /// Rejected proposals are logged but never written.
  Future<void> _applyValidatedProposals(
    List<LearningEvidenceProposal> proposals,
  ) async {
    if (proposals.isEmpty) return;

    final valid = evidenceValidator.filterValid(
      proposals,
      onRejected: (proposal, reason) {
        debugPrint(
          '[AiTutorRepository] Evidence proposal rejected '
          '(${proposal.contentId}/${proposal.eventType}): $reason',
        );
      },
    );

    if (valid.isEmpty) return;

    try {
      final db = await _getDb();
      final evidenceDao = LearnerEvidenceDao(db);

      for (final proposal in valid) {
        final nowUtc = DateTime.now().toUtc().toIso8601String();
        await evidenceDao.appendEvidence({
          'id': 'ev_proposal_${DateTime.now().microsecondsSinceEpoch}',
          'srs_item_id': null,
          'content_id': proposal.contentId,
          'content_type': proposal.contentType,
          'source': proposal.source,
          'score': proposal.confidence,
          'duration_ms': 0,
          'metadata_json': jsonEncode({
            'event_type': proposal.eventType,
            'task_context': proposal.taskContext,
            'session_id': proposal.sessionId,
            'proposed_at': proposal.proposedAt.toIso8601String(),
          }),
          'created_at': nowUtc,
        });
      }

      debugPrint(
        '[AiTutorRepository] Applied ${valid.length}/${proposals.length} evidence proposals.',
      );
    } catch (e) {
      debugPrint('[AiTutorRepository] Warning: failed to apply evidence proposals: $e');
    }
  }
}
