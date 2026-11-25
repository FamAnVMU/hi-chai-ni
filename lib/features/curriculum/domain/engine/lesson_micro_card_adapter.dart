import 'dart:math' as math;
import '../models/curriculum_models.dart';
import '../models/micro_card_model.dart';
import '../../presentation/widgets/interactive_word_tile_builder.dart';

/// Adapts standard CurriculumLesson content payload into 15–18 micro-learning cards
/// for the GamifiedLessonPlayer (Micro-Learning Journey: 5–7 minutes).
class LessonMicroCardAdapter {
  const LessonMicroCardAdapter();

  /// Default fallback distractors for audio choice when vocabulary has < 4 words
  static const List<String> _fallbackHanziDistractors = [
    '我', '你', '他', '她', '好', '很', '是', '大', '小', '人', '吃', '喝', '看', '说'
  ];

  static const List<String> _fallbackMeaningDistractors = [
    'tôi, mình', 'bạn, anh, chị', 'người', 'rất', 'tốt, đẹp', 'là, phải', 'lớn, to', 'nhỏ, bé'
  ];

  /// Transforms a [CurriculumLesson] into an ordered micro-learning deck.
  List<MicroCardModel> adapt(CurriculumLesson lesson) {
    final segments = lesson.segments;

    // 1. Extract vocabulary words safely
    final vocabSegment = _findSegment(segments, ['vocabulary', 'vocab']);
    final rawWords = vocabSegment?.contentPayload?['words'];
    final words = (rawWords as List<dynamic>?)
            ?.whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList() ??
        [];

    // 2. Extract dialogue lines / sentences safely
    final dialogueSegment = _findSegment(segments, ['dialogue', 'conversation', 'reading']);
    final rawLines = dialogueSegment?.contentPayload?['lines'] ??
        dialogueSegment?.contentPayload?['sentences'];
    final lines = (rawLines as List<dynamic>?)
            ?.whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList() ??
        [];

    // 3. Extract grammar points safely
    final grammarSegment = _findSegment(segments, ['grammar']);
    final rawPoints = grammarSegment?.contentPayload?['points'];
    final grammarPoints = (rawPoints as List<dynamic>?)
            ?.whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList() ??
        [];

    // 4. Extract practice questions safely
    final practiceSegment = _findSegment(segments, ['practice', 'exercises']);
    final rawExercises = practiceSegment?.contentPayload?['exercises'] ??
        practiceSegment?.contentPayload?['questions'];
    final exercises = (rawExercises as List<dynamic>?)
            ?.whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList() ??
        [];

    final List<MicroCardModel> deck = [];

    // --- PHASE 1: REVEAL CARDS (Target: 4–5 cards) ---
    final revealCount = math.min(5, words.isNotEmpty ? words.length : 0);
    for (int i = 0; i < revealCount; i++) {
      final w = words[i];
      final hanzi = (w['simplified'] ?? w['hanzi'] ?? w['zh'] ?? '').toString().trim();
      if (hanzi.isEmpty) continue;

      final pinyin = (w['pinyin'] ?? w['py'] ?? '').toString().trim();
      final meaning = (w['meaning_vi'] ?? w['meaning'] ?? w['vi'] ?? '').toString().trim();
      final hanViet = (w['han_viet'] ?? w['hanviet'] ?? w['hanViet'] ?? '').toString().trim();
      final audioUrl = (w['audio_uri'] ?? w['audio_url'])?.toString();

      String? exampleText;
      if (w['example'] is Map) {
        final ex = w['example'] as Map;
        exampleText = '${ex['chinese'] ?? ex['zh'] ?? ''} - ${ex['meaning'] ?? ex['vi'] ?? ''}';
      } else if (w['example_sentence'] != null) {
        exampleText = w['example_sentence'].toString();
      }

      deck.add(
        MicroCardModel(
          id: '${lesson.id}_rev_$i',
          type: MicroCardType.reveal,
          title: 'Từ mới',
          hanzi: hanzi,
          pinyin: pinyin,
          meaning: meaning,
          hanViet: hanViet.isNotEmpty ? hanViet : null,
          audioText: hanzi,
          audioUrl: audioUrl,
          explanation: exampleText,
          segmentType: 'vocabulary',
        ),
      );
    }

    // --- PHASE 2: AUDIO CHOICE CARDS (Target: 3–4 cards) ---
    final audioCount = math.min(4, words.isNotEmpty ? words.length : 0);
    for (int i = 0; i < audioCount; i++) {
      final w = words[i];
      final targetHanzi = (w['simplified'] ?? w['hanzi'] ?? w['zh'] ?? '').toString().trim();
      if (targetHanzi.isEmpty) continue;

      final pinyin = (w['pinyin'] ?? w['py'] ?? '').toString().trim();
      final meaning = (w['meaning_vi'] ?? w['meaning'] ?? w['vi'] ?? '').toString().trim();

      // Gather distinct distractors
      final optionsSet = <String>{targetHanzi};
      for (final other in words) {
        final otherHanzi = (other['simplified'] ?? other['hanzi'] ?? other['zh'] ?? '').toString().trim();
        if (otherHanzi.isNotEmpty && otherHanzi != targetHanzi) {
          optionsSet.add(otherHanzi);
          if (optionsSet.length >= 4) break;
        }
      }

      // Add fallback distractors if needed
      for (final fallback in _fallbackHanziDistractors) {
        if (optionsSet.length >= 4) break;
        optionsSet.add(fallback);
      }

      final optionsList = optionsSet.toList()..shuffle(math.Random(i + 42));
      final correctIndex = optionsList.indexOf(targetHanzi);

      deck.add(
        MicroCardModel(
          id: '${lesson.id}_aud_$i',
          type: MicroCardType.audioChoice,
          title: 'Nghe & Chọn Hán tự',
          hanzi: targetHanzi,
          pinyin: pinyin,
          audioText: targetHanzi,
          audioUrl: (w['audio_uri'] ?? w['audio_url'])?.toString(),
          prompt: 'Nghe phát âm và chọn chữ Hán chính xác:',
          options: optionsList,
          correctIndex: correctIndex,
          meaning: meaning,
          segmentType: 'vocabulary',
        ),
      );
    }

    // --- PHASE 3: SENTENCE BUILDER CARDS (Target: 2–3 cards) ---
    final candidateSentences = <Map<String, String>>[];

    // Extract from dialogue
    for (final l in lines) {
      final zh = (l['chinese'] ?? l['zh'] ?? l['text_zh'] ?? '').toString().trim();
      final vi = (l['meaning'] ?? l['vi'] ?? l['vietnamese'] ?? l['text_vi'] ?? '').toString().trim();
      if (zh.isNotEmpty && zh.length >= 2) {
        candidateSentences.add({'zh': zh, 'vi': vi});
      }
    }

    // Extract from grammar examples
    if (candidateSentences.length < 3) {
      for (final p in grammarPoints) {
        if (p['positive_example'] is Map) {
          final pos = p['positive_example'] as Map;
          final zh = (pos['chinese'] ?? pos['zh'] ?? pos['sentence_zh'] ?? '').toString().trim();
          final vi = (pos['vietnamese'] ?? pos['vi'] ?? pos['meaning_vi'] ?? '').toString().trim();
          if (zh.isNotEmpty) candidateSentences.add({'zh': zh, 'vi': vi});
        }
        if (p['examples'] is List) {
          for (final ex in (p['examples'] as List).whereType<Map>()) {
            final zh = (ex['chinese'] ?? ex['zh'] ?? ex['sentence_zh'] ?? '').toString().trim();
            final vi = (ex['vietnamese'] ?? ex['vi'] ?? ex['meaning_vi'] ?? '').toString().trim();
            if (zh.isNotEmpty) candidateSentences.add({'zh': zh, 'vi': vi});
          }
        }
      }
    }

    // Fallback: If no candidate sentences found, combine 2-3 vocabulary words
    if (candidateSentences.isEmpty && words.isNotEmpty) {
      final pickedWords = words.take(3).toList();
      final zhParts = pickedWords
          .map((w) => (w['simplified'] ?? w['hanzi'] ?? w['zh'] ?? '').toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final viParts = pickedWords
          .map((w) => (w['meaning_vi'] ?? w['meaning'] ?? w['vi'] ?? '').toString().trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final combinedZh = zhParts.join(' ');
      final combinedVi = viParts.join(', ');
      if (combinedZh.isNotEmpty) {
        candidateSentences.add({'zh': combinedZh, 'vi': combinedVi});
      }
    }

    final knownCompoundWords = <String>{
      for (final w in words)
        if ((w['simplified'] ?? w['hanzi'] ?? w['zh'] ?? '').toString().trim().length >= 2)
          (w['simplified'] ?? w['hanzi'] ?? w['zh'] ?? '').toString().trim(),
      '不是', '没有', '什么', '时候', '喜欢', '认识', '高兴', '工作', '学习', '朋友', '老师', '学生',
    }.toList();

    final sentenceCount = math.min(3, candidateSentences.length);
    for (int i = 0; i < sentenceCount; i++) {
      final s = candidateSentences[i];
      final targetZh = s['zh']!;
      final promptVi = s['vi']!.isNotEmpty ? s['vi']! : 'Ghép các từ thành câu hoàn chỉnh';

      // Tokenize Chinese characters / compound words safely without punctuation chips
      final chips = _tokenizeChineseSentence(targetZh, knownWords: knownCompoundWords);
      if (chips.length >= 2) {
        final shuffledChips = List<String>.from(chips);
        if (shuffledChips.length > 1) {
          shuffledChips.shuffle(math.Random(i + 99));
          if (_listEquals(shuffledChips, chips)) {
            shuffledChips.setAll(0, shuffledChips.reversed.toList());
          }
        }

        deck.add(
          MicroCardModel(
            id: '${lesson.id}_sb_$i',
            type: MicroCardType.sentenceBuilder,
            title: 'Ghép câu hoàn chỉnh',
            prompt: 'Sắp xếp các từ theo câu tiếng Việt:\n"$promptVi"',
            targetSentence: targetZh,
            sentenceChips: shuffledChips,
            segmentType: 'dialogue',
          ),
        );
      }
    }

    // --- PHASE 4: MATCHING PAIRS CARDS (Target: 1–2 cards) ---
    if (words.length >= 4) {
      final pairs1 = <String, String>{};
      for (int i = 0; i < math.min(4, words.length); i++) {
        final zh = (words[i]['simplified'] ?? words[i]['hanzi'] ?? words[i]['zh'] ?? '').toString().trim();
        final vi = (words[i]['meaning_vi'] ?? words[i]['meaning'] ?? words[i]['vi'] ?? '').toString().trim();
        if (zh.isNotEmpty && vi.isNotEmpty) {
          pairs1[zh] = vi;
        }
      }

      if (pairs1.length >= 2) {
        deck.add(
          MicroCardModel(
            id: '${lesson.id}_match_0',
            type: MicroCardType.matchingPairs,
            title: 'Ghép cặp từ Hán - Việt',
            prompt: 'Chạm để nối chữ Hán với nghĩa tiếng Việt tương ứng:',
            pairs: pairs1,
            segmentType: 'vocabulary',
          ),
        );
      }

      if (words.length >= 8) {
        final pairs2 = <String, String>{};
        for (int i = 4; i < math.min(8, words.length); i++) {
          final zh = (words[i]['simplified'] ?? words[i]['hanzi'] ?? words[i]['zh'] ?? '').toString().trim();
          final vi = (words[i]['meaning_vi'] ?? words[i]['meaning'] ?? words[i]['vi'] ?? '').toString().trim();
          if (zh.isNotEmpty && vi.isNotEmpty) {
            pairs2[zh] = vi;
          }
        }

        if (pairs2.length >= 2) {
          deck.add(
            MicroCardModel(
              id: '${lesson.id}_match_1',
              type: MicroCardType.matchingPairs,
              title: 'Ghép cặp từ Hán - Việt',
              prompt: 'Chạm để nối chữ Hán với nghĩa tiếng Việt tương ứng:',
              pairs: pairs2,
              segmentType: 'vocabulary',
            ),
          );
        }
      }
    } else if (words.length >= 2) {
      final pairs = <String, String>{};
      for (final w in words) {
        final zh = (w['simplified'] ?? w['hanzi'] ?? w['zh'] ?? '').toString().trim();
        final vi = (w['meaning_vi'] ?? w['meaning'] ?? w['vi'] ?? '').toString().trim();
        if (zh.isNotEmpty && vi.isNotEmpty) {
          pairs[zh] = vi;
        }
      }
      if (pairs.length >= 2) {
        deck.add(
          MicroCardModel(
            id: '${lesson.id}_match_0',
            type: MicroCardType.matchingPairs,
            title: 'Ghép cặp từ Hán - Việt',
            prompt: 'Chạm để nối chữ Hán với nghĩa tiếng Việt tương ứng:',
            pairs: pairs,
            segmentType: 'vocabulary',
          ),
        );
      }
    }

    // --- PHASE 5: MINI QUIZ CARDS (Target: 3–4 cards) ---
    int quizIndex = 0;
    for (final ex in exercises) {
      if (quizIndex >= 4) break;

      final promptText = (ex['prompt'] ?? ex['question'] ?? '').toString().trim();
      final rawOptions = ex['options'];
      final options = (rawOptions as List<dynamic>?)?.map((o) => o.toString().trim()).toList() ?? [];

      if (promptText.isNotEmpty && options.length >= 2) {
        int correctIdx = 0;
        if (ex['correct_index'] != null) {
          correctIdx = (ex['correct_index'] as num).toInt().clamp(0, options.length - 1);
        } else if (ex['correct_answer'] != null) {
          final ans = ex['correct_answer'].toString().trim();
          final found = options.indexOf(ans);
          if (found != -1) correctIdx = found;
        }
        final String correctValue = options[correctIdx];
        final shuffledOptions = List<String>.from(options)
          ..shuffle(math.Random(Object.hash(lesson.id, quizIndex, 31)));
        final int newCorrectIdx = shuffledOptions.indexOf(correctValue);

        final explanation = (ex['explanation'] ?? ex['explanation_vi'] ?? '').toString();

        deck.add(
          MicroCardModel(
            id: '${lesson.id}_quiz_$quizIndex',
            type: MicroCardType.miniQuiz,
            title: 'Luyện tập trắc nghiệm',
            prompt: promptText,
            options: shuffledOptions,
            correctIndex: newCorrectIdx >= 0 ? newCorrectIdx : 0,
            explanation: explanation.isNotEmpty ? explanation : null,
            segmentType: 'practice',
          ),
        );
        quizIndex++;
      }
    }

    // If practice exercises had fewer than 3 questions, generate synthetic quiz cards from words
    if (quizIndex < 3 && words.isNotEmpty) {
      for (int i = 0; i < words.length && quizIndex < 4; i++) {
        final targetWord = words[i];
        final hanzi = (targetWord['simplified'] ?? targetWord['hanzi'] ?? targetWord['zh'] ?? '').toString().trim();
        final correctMeaning = (targetWord['meaning_vi'] ?? targetWord['meaning'] ?? targetWord['vi'] ?? '').toString().trim();
        if (hanzi.isEmpty || correctMeaning.isEmpty) continue;

        final optionsSet = <String>{correctMeaning};
        for (final other in words) {
          final otherMeaning = (other['meaning_vi'] ?? other['meaning'] ?? other['vi'] ?? '').toString().trim();
          if (otherMeaning.isNotEmpty && otherMeaning != correctMeaning) {
            optionsSet.add(otherMeaning);
            if (optionsSet.length >= 4) break;
          }
        }
        for (final fallback in _fallbackMeaningDistractors) {
          if (optionsSet.length >= 4) break;
          optionsSet.add(fallback);
        }

        final optionsList = optionsSet.toList()..shuffle(math.Random(quizIndex + 77));
        final correctIdx = optionsList.indexOf(correctMeaning);

        deck.add(
          MicroCardModel(
            id: '${lesson.id}_syn_quiz_$quizIndex',
            type: MicroCardType.miniQuiz,
            title: 'Trắc nghiệm từ vựng',
            prompt: 'Chữ Hán "$hanzi" có nghĩa là gì?',
            options: optionsList,
            correctIndex: correctIdx,
            explanation: '"$hanzi" (${targetWord['pinyin'] ?? ''}) có nghĩa là "$correctMeaning".',
            segmentType: 'practice',
          ),
        );
        quizIndex++;
      }
    }

    return deck;
  }

  LessonSegment? _findSegment(List<LessonSegment> segments, List<String> types) {
    for (final t in types) {
      try {
        return segments.firstWhere(
          (s) => s.segmentType.toLowerCase() == t.toLowerCase(),
        );
      } catch (_) {}
    }
    return null;
  }

  List<String> _tokenizeChineseSentence(
    String sentence, {
    List<String> knownWords = const [],
  }) {
    final withoutPunct = sentence
        .replaceAll(RegExp(r'[。，！？、；：“”‘’（）\(\)\[\]《》〈〉\.,!?;:"\x27]'), ' ')
        .trim();
    if (withoutPunct.isEmpty) return [];

    // Preserve explicit word spacing if already provided; otherwise apply compound tokenization
    if (withoutPunct.contains(RegExp(r'\s+'))) {
      final parts = withoutPunct
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .toList();
      if (parts.length >= 2) return parts;
      final singleWord = parts.first;
      return InteractiveWordTileBuilder.tokenizePreservingCompounds(
        singleWord,
        knownWords: knownWords,
      );
    }

    var tokens = InteractiveWordTileBuilder.tokenizePreservingCompounds(
      withoutPunct,
      knownWords: knownWords,
    );

    if (tokens.length < 2 && withoutPunct.runes.length >= 2) {
      tokens = withoutPunct.runes
          .map((r) => String.fromCharCode(r))
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    return tokens;
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
