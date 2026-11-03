import 'dart:math';
import '../models/grammar_models.dart';

/// Deterministic exercise generator that creates pedagogical exercises
/// strictly grounded in verified grammar point rules and authentic example sentences.
class GrammarExerciseGenerator {
  final Random _random;

  GrammarExerciseGenerator({Random? random}) : _random = random ?? Random();

  /// Generates a complete set of exercises for a given grammar item
  List<GrammarExercise> generateExercises(
    GrammarItem item, {
    List<GrammarItem> pool = const [],
  }) {
    final exercises = <GrammarExercise>[];

    // 1. Structure Selection (Chọn cấu trúc đúng)
    final structEx = _generateStructureSelectionExercise(item, pool);
    if (structEx != null) exercises.add(structEx);

    // 2. Fill in the Blank (Điền từ vào chỗ trống)
    if (item.examples.isNotEmpty) {
      final fillEx = _generateFillInBlankExercise(item);
      if (fillEx != null) exercises.add(fillEx);
    }

    // 3. Sentence Unscramble (Sắp xếp trật tự từ)
    if (item.examples.isNotEmpty) {
      final reorderEx = _generateSentenceUnscrambleExercise(item);
      if (reorderEx != null) exercises.add(reorderEx);
    }

    // 4. Error Recognition (Nhận biết lỗi ngữ pháp)
    final errorEx = _generateErrorRecognitionExercise(item);
    if (errorEx != null) exercises.add(errorEx);

    return exercises;
  }

  /// 1. Structure Selection: Learner selects the canonical formula/pattern
  GrammarExercise? _generateStructureSelectionExercise(
    GrammarItem item,
    List<GrammarItem> pool,
  ) {
    if (item.structure.trim().isEmpty) return null;

    final distractors = <String>{};
    // Pick from pool
    final sameLevelPool = pool.where((p) => p.id != item.id && p.structure.isNotEmpty).toList();
    sameLevelPool.shuffle(_random);
    for (final p in sameLevelPool) {
      if (p.structure != item.structure) {
        distractors.add(p.structure);
      }
      if (distractors.length >= 3) break;
    }

    // Fallback standard distractors if pool is small
    final standardDistractors = [
      'Subj. + Verb + 在 + Place',
      'Subj. + 不 + Verb + 了',
      'Subj. + 比 + Obj. + 不 + Adj.',
      'Subj. + 把 + Obj. + 没 + Verb',
      'Subj. + 已经 + Verb + 着',
    ];
    for (final d in standardDistractors) {
      if (d != item.structure && distractors.length < 3) {
        distractors.add(d);
      }
    }

    final options = [item.structure, ...distractors.take(3)]..shuffle(_random);
    final correctIdx = options.indexOf(item.structure);

    return GrammarExercise(
      id: 'ex_struct_${item.id}',
      type: GrammarExerciseType.multipleChoice,
      prompt: 'Chọn cấu trúc câu chính xác cho điểm ngữ pháp:\n"${item.title}"',
      options: options,
      correctAnswerIndex: correctIdx,
      targetSentence: item.structure,
      explanationVi: 'Cấu trúc chuẩn xác: ${item.structure}. ${item.explanationVi}',
    );
  }

  /// 2. Fill in the Blank: Learner inserts the authentic grammatical particle/word
  GrammarExercise? _generateFillInBlankExercise(GrammarItem item) {
    // Pick an example
    for (final ex in item.examples) {
      final text = ex.hanzi;
      if (text.length < 3) continue;

      // Extract candidate keywords to blank out
      final candidates = ['在', '正在', '了', '着', '过', '把', '被', '比', '的', '得', '地', '都', '也', '不', '没', '太', '很', '跟'];
      String? targetWord;
      for (final c in candidates) {
        if (text.contains(c) && (item.title.contains(c) || item.structure.contains(c))) {
          targetWord = c;
          break;
        }
      }

      // If no candidate matched title/structure, check any candidate in text
      if (targetWord == null) {
        for (final c in candidates) {
          if (text.contains(c)) {
            targetWord = c;
            break;
          }
        }
      }

      if (targetWord != null) {
        final sentenceWithBlank = text.replaceFirst(targetWord, ' ( ___ ) ');
        final distractors = candidates.where((c) => c != targetWord).toList()..shuffle(_random);
        final options = [targetWord, ...distractors.take(3)]..shuffle(_random);
        final correctIdx = options.indexOf(targetWord);

        return GrammarExercise(
          id: 'ex_fill_${item.id}',
          type: GrammarExerciseType.fillInBlank,
          prompt: 'Chọn từ hoặc trợ từ thích hợp điền vào chỗ trống:',
          sentenceWithBlank: sentenceWithBlank,
          options: options,
          correctAnswerIndex: correctIdx,
          targetSentence: text,
          explanationVi: 'Câu hoàn chỉnh: "$text" (${ex.pinyin}). Bản dịch: "${ex.translationVi}".',
        );
      }
    }
    return null;
  }

  /// 3. Sentence Unscramble: Reassemble tokens into the authentic sentence
  GrammarExercise? _generateSentenceUnscrambleExercise(GrammarItem item) {
    for (final ex in item.examples) {
      List<String> tokens = [];
      if (ex.chineseSegmented != null && ex.chineseSegmented!.contains(' ')) {
        tokens = ex.chineseSegmented!.split(RegExp(r'\s+')).where((t) => t.trim().isNotEmpty && t != '。' && t != '？' && t != '！').toList();
      } else {
        // Simple 2-3 char chunking
        final cleaned = ex.hanzi.replaceAll(RegExp(r'[。？！，、\s]'), '');
        if (cleaned.length >= 4 && cleaned.length <= 15) {
          int i = 0;
          while (i < cleaned.length) {
            final take = (cleaned.length - i >= 4 && _random.nextBool()) ? 2 : (cleaned.length - i >= 3 ? 2 : 1);
            tokens.add(cleaned.substring(i, min(i + take, cleaned.length)));
            i += take;
          }
        }
      }

      if (tokens.length >= 3 && tokens.length <= 8) {
        final shuffled = List<String>.from(tokens)..shuffle(_random);
        // Ensure not identical to original
        if (shuffled.join('') == tokens.join('')) {
          shuffled.shuffle(_random);
        }

        final target = ex.hanzi.replaceAll(RegExp(r'[。？！\s]'), '');
        return GrammarExercise(
          id: 'ex_reorder_${item.id}',
          type: GrammarExerciseType.reorderWords,
          prompt: 'Sắp xếp các từ thành câu đúng ngữ pháp:\n(${ex.translationVi})',
          shuffledTokens: shuffled,
          targetSentence: target,
          explanationVi: 'Câu hoàn chỉnh: "${ex.hanzi}" (${ex.pinyin}). Nghĩa: "${ex.translationVi}".',
        );
      }
    }
    return null;
  }

  /// 4. Error Recognition: Identify correct vs incorrect grammatical formulation
  GrammarExercise? _generateErrorRecognitionExercise(GrammarItem item) {
    // If contrastive examples exist in item
    if (item.contrastiveExamples.isNotEmpty) {
      final ce = item.contrastiveExamples.first;
      final options = [
        ce.correctSentence,
        ce.incorrectSentence,
      ]..shuffle(_random);
      final correctIdx = options.indexOf(ce.correctSentence);

      return GrammarExercise(
        id: 'ex_error_${item.id}',
        type: GrammarExerciseType.errorRecognition,
        prompt: 'Nhận biết câu nào sau đây ĐÚNG cấu trúc ngữ pháp?',
        options: options,
        correctAnswerIndex: correctIdx,
        targetSentence: ce.correctSentence,
        explanationVi: 'Câu chuẩn: "${ce.correctSentence}". Câu sai: "${ce.incorrectSentence}" (${ce.explanationVi}).',
      );
    }

    // Otherwise use an authentic sentence and contrast with word-order error
    if (item.examples.isNotEmpty) {
      final ex = item.examples.first;
      final correctSentence = ex.hanzi;
      
      // Construct a typical word-order mistake based on the structure
      // For instance, placing the particle or adverb at the end of the sentence
      String faultySentence = correctSentence;
      final particles = ['在', '不', '没', '都', '也', '了', '把', '比'];
      for (final p in particles) {
        if (correctSentence.contains(p) && !correctSentence.endsWith(p)) {
          faultySentence = correctSentence.replaceAll(p, '') + p;
          break;
        }
      }
      if (faultySentence == correctSentence) {
        // Reverse first two words if no particle found
        if (correctSentence.length >= 4) {
          faultySentence = correctSentence.substring(2, 4) + correctSentence.substring(0, 2) + correctSentence.substring(4);
        }
      }

      if (faultySentence != correctSentence) {
        final options = [correctSentence, faultySentence]..shuffle(_random);
        final correctIdx = options.indexOf(correctSentence);

        return GrammarExercise(
          id: 'ex_error_${item.id}',
          type: GrammarExerciseType.errorRecognition,
          prompt: 'Chọn câu diễn đạt CHÍNH XÁC theo quy tắc ngữ pháp:',
          options: options,
          correctAnswerIndex: correctIdx,
          targetSentence: correctSentence,
          explanationVi: 'Câu đúng: "$correctSentence" (${ex.pinyin}). Quy tắc: ${item.structure}. ${item.explanationVi}',
        );
      }
    }
    return null;
  }
}
