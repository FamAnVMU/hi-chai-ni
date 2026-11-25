import 'dart:convert';
import 'tutor_correction.dart';

/// Represents a single message turn in an AI Tutor conversation.
class TutorChatTurn {
  final String id;
  final String sessionId;
  final String role; // 'user' or 'assistant'
  final String content;
  final String? pinyin;
  final String? translationVi;
  final String? audioUri;
  final int tokensUsed;
  final DateTime createdAt;
  final TutorEvaluation? evaluation;
  final List<String> followUpSuggestions;

  const TutorChatTurn({
    required this.id,
    required this.sessionId,
    required this.role,
    required this.content,
    this.pinyin,
    this.translationVi,
    this.audioUri,
    this.tokensUsed = 0,
    required this.createdAt,
    this.evaluation,
    this.followUpSuggestions = const [],
  });

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'role': role,
      'content': content,
      'pinyin': pinyin,
      'translation_vi': translationVi,
      'audio_uri': audioUri,
      'tokens_used': tokensUsed,
      'evaluation_json': evaluation != null ? jsonEncode(evaluation!.toMap()) : null,
      'follow_up_suggestions_json':
          followUpSuggestions.isNotEmpty ? jsonEncode(followUpSuggestions) : null,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  factory TutorChatTurn.fromDbMap(Map<String, dynamic> map, {TutorEvaluation? evaluation}) {
    TutorEvaluation? parsedEval = evaluation;
    if (parsedEval == null) {
      final rawEval = map['evaluation_json'];
      if (rawEval is String && rawEval.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(rawEval);
          if (decoded is Map<String, dynamic>) {
            parsedEval = TutorEvaluation.fromMap(decoded);
          }
        } catch (_) {}
      } else if (rawEval is Map<String, dynamic>) {
        parsedEval = TutorEvaluation.fromMap(rawEval);
      }
    }

    List<String> suggestions = const [];
    final rawSuggestions = map['follow_up_suggestions_json'];
    if (rawSuggestions is String && rawSuggestions.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawSuggestions);
        if (decoded is List) {
          suggestions = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    } else if (rawSuggestions is List) {
      suggestions = rawSuggestions.map((e) => e.toString()).toList();
    }

    return TutorChatTurn(
      id: map['id'] as String,
      sessionId: map['session_id'] as String,
      role: map['role'] as String,
      content: map['content'] as String,
      pinyin: map['pinyin'] as String?,
      translationVi: map['translation_vi'] as String?,
      audioUri: map['audio_uri'] as String?,
      tokensUsed: (map['tokens_used'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      evaluation: parsedEval,
      followUpSuggestions: suggestions,
    );
  }
}
