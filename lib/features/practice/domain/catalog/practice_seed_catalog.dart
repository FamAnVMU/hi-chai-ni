import '../models/practice_models.dart';

/// Authentic curated practice exercise seeds across all 7 types and multiple skills
class PracticeSeedCatalog {
  PracticeSeedCatalog._();

  static List<ExerciseDefinition> get items => [
        // 1. Multiple Choice (Vocabulary)
        ExerciseDefinition(
          id: 'EX_MC_VOCAB_01',
          type: ExerciseType.multipleChoice,
          skill: 'vocabulary',
          hskLevel: 1,
          prompt: 'Chọn từ thích hợp để hoàn thành câu: "我喝 ___。"',
          options: const ['茶', '书', '看', '在'],
          correctOptionIndex: 0,
          explanationVi: 'Động từ "喝" (hē - uống) đi kèm danh từ đồ uống như "茶" (chá - trà).',
          createdAt: DateTime.utc(2026, 11, 1),
          updatedAt: DateTime.utc(2026, 11, 1),
        ),

        // 2. Select Meaning or Pinyin (Vocabulary)
        ExerciseDefinition(
          id: 'EX_PINYIN_VOCAB_02',
          type: ExerciseType.selectMeaningOrPinyin,
          skill: 'vocabulary',
          hskLevel: 1,
          prompt: 'Chọn phiên âm Pinyin chính xác của chữ Hán sau:',
          stimulus: '苹果',
          options: const ['píngguǒ', 'xīguā', 'mángguǒ', 'xiāngjiāo'],
          correctOptionIndex: 0,
          explanationVi: '"苹果" đọc là píngguǒ, nghĩa là "quả táo".',
          createdAt: DateTime.utc(2026, 11, 1),
          updatedAt: DateTime.utc(2026, 11, 1),
        ),

        // 3. Matching Pairs (Vocabulary/Meaning)
        ExerciseDefinition(
          id: 'EX_MATCH_VOCAB_03',
          type: ExerciseType.matchingPairs,
          skill: 'vocabulary',
          hskLevel: 1,
          prompt: 'Nối các từ tiếng Trung với ý nghĩa tiếng Việt tương ứng:',
          matchingPairs: const {
            '你好': 'Xin chào',
            '谢谢': 'Cảm ơn',
            '再见': 'Tạm biệt',
            '对不起': 'Xin lỗi',
          },
          explanationVi: 'Các câu chào hỏi và xã giao cơ bản trong HSK 1.',
          createdAt: DateTime.utc(2026, 11, 1),
          updatedAt: DateTime.utc(2026, 11, 1),
        ),

        // 4. Fill In The Blank (Grammar)
        ExerciseDefinition(
          id: 'EX_BLANK_GRAMMAR_04',
          type: ExerciseType.fillInTheBlank,
          skill: 'grammar',
          hskLevel: 1,
          prompt: 'Điền từ thích hợp vào chỗ trống trong câu:',
          sentenceWithBlank: '我 ___ 中国人。',
          blankAnswer: '是',
          blankOptions: const ['是', '在', '有', '去'],
          acceptableAnswers: const ['是'],
          explanationVi: 'Câu phán đoán khẳng định "A là B" sử dụng hệ từ "是" (shì).',
          createdAt: DateTime.utc(2026, 11, 1),
          updatedAt: DateTime.utc(2026, 11, 1),
        ),

        // 5. Reorder Words (Grammar)
        ExerciseDefinition(
          id: 'EX_REORDER_GRAMMAR_05',
          type: ExerciseType.reorderWords,
          skill: 'grammar',
          hskLevel: 1,
          prompt: 'Sắp xếp các từ sau thành một câu hoàn chỉnh:',
          tokens: const ['喜欢', '中国菜', '我', '吃'],
          targetSentence: '我喜欢吃中国菜。',
          acceptableAnswers: const ['我喜欢吃中国菜', '我喜欢吃中国菜。'],
          explanationVi: 'Trật tự cú pháp tiếng Hán: Chủ ngữ (我) + Trợ động từ (喜欢) + Động từ (吃) + Tân ngữ (中国菜).',
          createdAt: DateTime.utc(2026, 11, 1),
          updatedAt: DateTime.utc(2026, 11, 1),
        ),

        // 6. True/False or Error Detection (Reading & Grammar)
        ExerciseDefinition(
          id: 'EX_ERROR_DETECT_06',
          type: ExerciseType.trueFalseOrErrorDetection,
          skill: 'grammar',
          hskLevel: 1,
          prompt: 'Tìm từ bị dùng sai trong câu sau:',
          stimulus: '他在学校学中文在。',
          tokens: const ['他', '在', '学校', '学', '中文', '在', '。'],
          errorToken: '在',
          errorCorrection: '',
          explanationVi: 'Giới từ chỉ địa điểm "在学校" đã đứng trước động từ "学", không được lặp lại "在" ở cuối câu.',
          createdAt: DateTime.utc(2026, 11, 1),
          updatedAt: DateTime.utc(2026, 11, 1),
        ),

        // 7. Short Answer with Rubric (Writing/Translation)
        ExerciseDefinition(
          id: 'EX_SHORT_ANSWER_07',
          type: ExerciseType.shortAnswer,
          skill: 'writing',
          hskLevel: 2,
          prompt: 'Dịch câu so sánh sau sang tiếng Trung: "Hôm nay lạnh hơn hôm qua."',
          targetSentence: '今天比昨天冷。',
          rubricKeywords: const ['今天', '比', '昨天', '冷'],
          acceptableAnswers: const ['今天比昨天冷', '今天比昨天冷。'],
          explanationVi: 'Cấu trúc so sánh hơn chữ 比: A + 比 + B + Tính từ.',
          createdAt: DateTime.utc(2026, 11, 1),
          updatedAt: DateTime.utc(2026, 11, 1),
        ),
      ];
}
