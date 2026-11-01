import 'dart:convert';
import '../models/learning_evidence_proposal.dart';
import '../models/tutor_response.dart';

/// Fault-tolerant parser for AI Tutor responses.
/// Handles pure JSON, markdown code-fenced JSON, and raw text fallbacks.
class TutorResponseParser {
  TutorResponseParser._();

  /// Parses raw LLM text into a structured [TutorResponse].
  ///
  /// [sessionId] is needed to populate [LearningEvidenceProposal.sessionId].
  static TutorResponse parse(String rawText, {String sessionId = ''}) {
    final cleaned = _extractJsonBlock(rawText.trim());

    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) {
        // Inject sessionId into the map so fromMap can pass it to proposals
        final mapWithSession = Map<String, dynamic>.from(decoded)
          ..['session_id'] = sessionId;
        return TutorResponse.fromMap(mapWithSession);
      }
    } catch (_) {
      // Fallback if model output is not valid JSON
    }

    return _fallbackUnstructuredResponse(rawText);
  }

  /// Strips markdown fences such as ```json ... ``` or ``` ... ```
  static String _extractJsonBlock(String text) {
    String content = text.trim();

    if (content.startsWith('```json')) {
      content = content.substring(7);
    } else if (content.startsWith('```')) {
      content = content.substring(3);
    }

    if (content.endsWith('```')) {
      content = content.substring(0, content.length - 3);
    }

    content = content.trim();

    // In case there is text before the first '{' or after the last '}'
    final startIdx = content.indexOf('{');
    final endIdx = content.lastIndexOf('}');
    if (startIdx != -1 && endIdx != -1 && endIdx > startIdx) {
      return content.substring(startIdx, endIdx + 1);
    }

    return content;
  }

  /// Robust fallback when model returns raw unstructured conversational text.
  static TutorResponse _fallbackUnstructuredResponse(String rawText) {
    final lines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String replyZh = '';
    String replyPinyin = '';
    String replyVi = '';

    final chineseRegex = RegExp(r'[\u4e00-\u9fa5]');

    for (final line in lines) {
      if (chineseRegex.hasMatch(line) && replyZh.isEmpty) {
        replyZh = line;
      } else if (replyPinyin.isEmpty && _isLikelyPinyin(line)) {
        replyPinyin = line;
      } else if (replyVi.isEmpty) {
        replyVi = line;
      }
    }

    if (replyZh.isEmpty) {
      replyZh = rawText;
    }

    return TutorResponse(
      replyZh: replyZh,
      replyPinyin: replyPinyin,
      replyVi: replyVi,
      evaluation: null,
      followUpSuggestions: const [],
      targetVocabulary: const [],
      evidenceProposals: const [],
    );
  }

  /// Heuristic to detect pinyin strings containing tone-marked vowels.
  static bool _isLikelyPinyin(String text) {
    // Matches common pinyin tone marks: ā á ǎ à ē é ě è ī í ǐ ì ō ó ǒ ò ū ú ǔ ù ǖ ǘ ǚ ǜ
    final pinyinToneRegex = RegExp(r'[āáǎàēéěèīíǐìōóǒòūúǔùǖǘǚǜ]');
    return pinyinToneRegex.hasMatch(text);
  }
}
