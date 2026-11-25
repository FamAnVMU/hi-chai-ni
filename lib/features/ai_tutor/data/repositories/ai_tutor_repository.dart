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

  Future<List<Map<String, dynamic>>> getActiveSessions({int limit = 30});

  Future<void> updateSessionTitle(String sessionId, String newTitle);

  Future<void> deleteSession(String sessionId);

  Future<void> removeLastTurn(String sessionId);

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

  int _proposalSeq = 0;

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

  /// Extracts partial plain Chinese text from a JSON response buffer while streaming,
  /// preventing raw JSON syntax (`{"reply_zh": ...}`) from rendering in chat bubbles.
  @visibleForTesting
  static String extractStreamingReplyZh(String rawBuffer) {
    final trimmedLeft = rawBuffer.trimLeft();
    if (trimmedLeft.isEmpty) return '';

    String stripped = trimmedLeft;
    if (stripped.startsWith('```json')) {
      stripped = stripped.substring(7).trimLeft();
    } else if (stripped.startsWith('```')) {
      stripped = stripped.substring(3).trimLeft();
    } else if (stripped == '`' || stripped == '``' || stripped.startsWith('```j')) {
      return '';
    }

    // If response does not appear to be JSON, stream plain text as-is.
    if (!stripped.startsWith('{')) {
      return rawBuffer;
    }

    final keyMatch = RegExp(r'"reply_zh"\s*:\s*"').firstMatch(stripped);
    if (keyMatch == null) {
      return '';
    }

    final sb = StringBuffer();
    int i = keyMatch.end;
    while (i < stripped.length) {
      final ch = stripped[i];
      if (ch == '"') {
        break; // Closing quote of reply_zh string
      }
      if (ch == r'\') {
        if (i + 1 >= stripped.length) {
          break; // Incomplete escape at chunk boundary; wait for next chunk
        }
        final next = stripped[i + 1];
        switch (next) {
          case '"':
          case r'\':
          case '/':
            sb.write(next);
            i += 2;
            break;
          case 'n':
            sb.write('\n');
            i += 2;
            break;
          case 'r':
            sb.write('\r');
            i += 2;
            break;
          case 't':
            sb.write('\t');
            i += 2;
            break;
          case 'u':
            if (i + 6 > stripped.length) {
              return sb.toString(); // Incomplete unicode escape; wait for next chunk
            }
            final hex = stripped.substring(i + 2, i + 6);
            final code = int.tryParse(hex, radix: 16);
            if (code != null) {
              sb.writeCharCode(code);
              i += 6;
            } else {
              sb.write(next);
              i += 2;
            }
            break;
          default:
            sb.write(next);
            i += 2;
        }
      } else {
        sb.write(ch);
        i++;
      }
    }
    return sb.toString();
  }

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
      'persona_id': personaId.name,
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
  Future<List<Map<String, dynamic>>> getActiveSessions({int limit = 30}) async {
    final db = await _getDb();
    final chatDao = ChatDao(db);
    return chatDao.getActiveSessions(limit: limit);
  }

  @override
  Future<void> updateSessionTitle(String sessionId, String newTitle) async {
    final db = await _getDb();
    final chatDao = ChatDao(db);
    await chatDao.updateSessionTitle(sessionId, newTitle);
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final db = await _getDb();
    final chatDao = ChatDao(db);
    await chatDao.deleteSession(sessionId);
  }

  @override
  Future<void> removeLastTurn(String sessionId) async {
    final db = await _getDb();
    final chatDao = ChatDao(db);
    final recent = await chatDao.getSessionMessages(sessionId, limit: 1);
    if (recent.isEmpty) return;

    await chatDao.deleteMessage(recent.last['id'] as String);
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

    // 2. Resolve profile & weak SRS words from SQLite when caller uses defaults
    final dbProfile = await learnerContextService.loadLearnerProfileAndWeakWords(db);
    final effectiveHskLevel =
        (learnerHskLevel == 1 && dbProfile.hskLevel > 1) ? dbProfile.hskLevel : learnerHskLevel;
    final effectiveLearnerName =
        (learnerName == 'Học viên' && dbProfile.learnerName != 'Học viên')
            ? dbProfile.learnerName
            : learnerName;
    final effectiveWeakWords =
        weakSrsWords.isEmpty ? dbProfile.weakSrsWords : weakSrsWords;

    final learnerContext = await learnerContextService.buildContext(
      db,
      sessionId: sessionId,
      hskLevel: effectiveHskLevel,
      learnerName: effectiveLearnerName,
    );

    // 3. Fetch history and build prompt request with 20-message sliding window (F-08)
    final rawHistory = await chatDao.getSessionMessages(
      sessionId,
      limit: 20,
    );
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
      learnerHskLevel: effectiveHskLevel,
      learnerName: effectiveLearnerName,
      weakSrsWords: effectiveWeakWords,
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

    // 6. Persist assistant reply to SQLite (including evaluation_json & follow_up_suggestions_json)
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
      'evaluation_json': tutorResponse.evaluation != null
          ? jsonEncode(tutorResponse.evaluation!.toMap())
          : null,
      'follow_up_suggestions_json': tutorResponse.followUpSuggestions.isNotEmpty
          ? jsonEncode(tutorResponse.followUpSuggestions)
          : null,
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

          // 2. Resolve profile & weak SRS words from SQLite when caller uses defaults
          final dbProfile = await learnerContextService.loadLearnerProfileAndWeakWords(db);
          final effectiveHskLevel =
              (learnerHskLevel == 1 && dbProfile.hskLevel > 1) ? dbProfile.hskLevel : learnerHskLevel;
          final effectiveLearnerName =
              (learnerName == 'Học viên' && dbProfile.learnerName != 'Học viên')
                  ? dbProfile.learnerName
                  : learnerName;
          final effectiveWeakWords =
              weakSrsWords.isEmpty ? dbProfile.weakSrsWords : weakSrsWords;

          final learnerContext = await learnerContextService.buildContext(
            db,
            sessionId: sessionId,
            hskLevel: effectiveHskLevel,
            learnerName: effectiveLearnerName,
          );

          // 3. Fetch history and build request with 20-message sliding window (F-08)
          final rawHistory = await chatDao.getSessionMessages(
            sessionId,
            limit: 20,
          );
          final historyExcludingLast =
              rawHistory.isNotEmpty && rawHistory.last['id'] == userMessageId
                  ? rawHistory.sublist(0, rawHistory.length - 1)
                  : rawHistory;

          final request = contextBuilder.buildRequest(
            userInput: userText,
            rawDbHistory: historyExcludingLast,
            persona: persona,
            scenario: scenario,
            learnerHskLevel: effectiveHskLevel,
            learnerName: effectiveLearnerName,
            weakSrsWords: effectiveWeakWords,
            learnerContext: learnerContext,
          );

          // 4. Stream from AI service, extracting only clean reply_zh deltas for UI
          final stream = aiService.streamText(
            request,
            taskType: AiTaskType.chatTutor,
            cancelToken: cancelToken,
          );

          final accumulatedBuffer = StringBuffer();
          String lastEmittedReply = '';
          int totalTokensUsed = 0;

          await for (final chunk in stream) {
            accumulatedBuffer.write(chunk.text);
            if (chunk.usageMetadata?.totalTokenCount != null) {
              totalTokensUsed = chunk.usageMetadata!.totalTokenCount;
            }
            final extracted = extractStreamingReplyZh(accumulatedBuffer.toString());
            if (extracted.length > lastEmittedReply.length) {
              controller.add(extracted.substring(lastEmittedReply.length));
              lastEmittedReply = extracted;
            }
          }

          // 5. On stream completion, parse full accumulated text
          final fullText = accumulatedBuffer.toString();
          final tutorResponse = TutorResponseParser.parse(
            fullText,
            sessionId: sessionId,
          );

          // 6. Save assistant turn to SQLite (including evaluation_json, follow_up_suggestions_json, tokens_used)
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
            'tokens_used': totalTokensUsed > 0 ? totalTokensUsed : tutorResponse.tokensUsed,
            'evaluation_json': tutorResponse.evaluation != null
                ? jsonEncode(tutorResponse.evaluation!.toMap())
                : null,
            'follow_up_suggestions_json': tutorResponse.followUpSuggestions.isNotEmpty
                ? jsonEncode(tutorResponse.followUpSuggestions)
                : null,
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

      // Invalidate context cache so subsequent turns immediately reflect new evidence
      LearnerContextService.invalidateCache(sessionId);
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
        final effectiveScore =
            proposal.eventType == 'error' ? 0.0 : proposal.confidence;
        await evidenceDao.appendEvidence({
          'id': 'ev_proposal_${DateTime.now().microsecondsSinceEpoch}_${++_proposalSeq}',
          'srs_item_id': null,
          'content_id': proposal.contentId,
          'content_type': proposal.contentType,
          'source': proposal.source,
          'score': effectiveScore,
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
      LearnerContextService.invalidateCache();
    } catch (e) {
      debugPrint('[AiTutorRepository] Warning: failed to apply evidence proposals: $e');
    }
  }
}
