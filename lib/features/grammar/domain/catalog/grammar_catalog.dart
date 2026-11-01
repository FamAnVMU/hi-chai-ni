import '../models/grammar_models.dart';

/// Authentic curated catalog of Chinese grammar points based on HSK Standard Course (BLCU)
class GrammarCatalog {
  GrammarCatalog._();

  static final List<GrammarItem> items = [
    // 1. GRM_HSK1_01_SHI
    GrammarItem(
      id: 'GRM_HSK1_01_SHI',
      hskLevel: 1,
      code: 'grm_hsk1_shi_copula',
      title: 'Câu chữ 是 (Câu phán đoán)',
      structure: 'Chủ ngữ + 是 + Danh từ / Cụm danh từ',
      meaningVi: 'Biểu thị sự phán đoán khẳng định "A là B" (thân phận, quốc tịch, nghề nghiệp, định nghĩa).',
      usageConditionsVi: 'Không được đặt phó từ mức độ "很" trước "是". Thể phủ định dùng "不是", tuyệt đối không dùng "没有".',
      sentencePositionVi: 'Đứng trực tiếp giữa Chủ ngữ và Tân ngữ danh từ đóng vai trò vị ngữ.',
      explanationVi: 'Trong tiếng Hán, động từ "是" (shì) tương đương với "là" trong tiếng Việt. Khi muốn nói ai là ai hoặc cái gì là cái gì, ta dùng mẫu câu này.',
      source: 'HSK Standard Course 1 - Bài 1',
      tags: ['câu_phán_đoán', 'động_từ_thì_hiện_tại', 'hsk1_cơ_bản'],
      relatedVocabIds: ['VOCAB_001_NIHAO'],
      relatedGrammarIds: ['GRM_HSK1_02_MA'],
      prerequisiteGrammarIds: [],
      examples: const [
        GrammarExample(
          hanzi: '我是中国人。',
          pinyin: 'Wǒ shì Zhōngguó rén.',
          translationVi: 'Tôi là người Trung Quốc.',
          breakdown: '我 (Tôi) + 是 (là) + 中国人 (người Trung Quốc)',
        ),
        GrammarExample(
          hanzi: '他是我们的汉语老师。',
          pinyin: 'Tā shì wǒmen de Hànyǔ lǎoshī.',
          translationVi: 'Thầy ấy là giáo viên tiếng Hán của chúng tôi.',
          breakdown: '他 (Thầy ấy) + 是 (là) + 我们的汉语老师 (giáo viên tiếng Hán của chúng tôi)',
        ),
      ],
      contrastiveExamples: const [
        ContrastiveExample(
          incorrectSentence: '我好。/ 我是好。',
          correctSentence: '我很好。 (Wǒ hěn hǎo.)',
          explanationVi: 'Lỗi chuyển di từ tiếng Việt: Trong tiếng Hán, vị ngữ tính từ không dùng "是", mà dùng phó từ "很" liên kết.',
          errorType: 'copula_with_adjective',
        ),
        ContrastiveExample(
          incorrectSentence: '我没有老师。 (trong ngữ cảnh phán đoán)',
          correctSentence: '我不是老师。 (Wǒ bú shì lǎoshī.)',
          explanationVi: 'Phủ định của câu phán đoán "是" bắt buộc là "不是", không dùng "没有" (chỉ sở hữu/quá khứ).',
          errorType: 'negation_error',
        ),
      ],
      exercises: const [
        GrammarExercise(
          id: 'EX_SHI_01_MC',
          type: GrammarExerciseType.multipleChoice,
          prompt: 'Chọn từ thích hợp điền vào chỗ trống:',
          sentenceWithBlank: '李明 ___ 我的中国朋友。',
          options: ['是', '在', '有', '很'],
          correctAnswerIndex: 0,
          targetSentence: '李明是我的中国朋友。',
          explanationVi: 'Phán đoán mối quan hệ thân phận "Lý Minh là bạn của tôi" bắt buộc dùng "是".',
        ),
        GrammarExercise(
          id: 'EX_SHI_02_REORDER',
          type: GrammarExerciseType.reorderWords,
          prompt: 'Sắp xếp các từ sau thành câu phán đoán đúng:',
          shuffledTokens: ['老师', '不', '是', '他'],
          targetSentence: '他不是老师。',
          acceptableAnswers: ['他不是老师', '他不是老师。'],
          explanationVi: 'Phó từ phủ định "不" luôn đứng trước động từ "是": Chủ ngữ (他) + 不 + 是 + Tân ngữ (老师).',
        ),
        GrammarExercise(
          id: 'EX_SHI_03_OPEN',
          type: GrammarExerciseType.openTranslation,
          prompt: 'Dịch câu sau sang tiếng Trung: "Cô ấy là bác sĩ."',
          targetSentence: '她是医生。',
          acceptableAnswers: ['她是医生', '她是医生。', '她是大夫', '她是大夫。'],
          rubricKeywords: ['她是', '医生'],
          explanationVi: 'Cô ấy (她) + là (是) + bác sĩ (医生).',
        ),
      ],
      createdAt: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 11, 1),
    ),

    // 2. GRM_HSK1_02_MA
    GrammarItem(
      id: 'GRM_HSK1_02_MA',
      hskLevel: 1,
      code: 'grm_hsk1_ma_question',
      title: 'Câu hỏi nghi vấn với trợ từ 吗 (ma)',
      structure: 'Câu trần thuật + 吗?',
      meaningVi: 'Dùng để biến câu khẳng định/phủ định thành câu hỏi Có/Không (Yes/No Question).',
      usageConditionsVi: 'Khi câu đã có đại từ nghi vấn (gì - 什么, ai - 谁, đâu - 哪儿) thì TUYỆT ĐỐI không được thêm "吗".',
      sentencePositionVi: 'Luôn đứng ở vị trí cuối cùng của câu hỏi.',
      explanationVi: 'Chỉ cần thêm "吗" vào sau bất kỳ câu trần thuật nào là tạo thành câu hỏi nghi vấn.',
      source: 'HSK Standard Course 1 - Bài 2',
      tags: ['câu_hỏi', 'trợ_từ_ngữ_khí', 'hsk1_cơ_bản'],
      relatedVocabIds: ['VOCAB_001_NIHAO'],
      relatedGrammarIds: ['GRM_HSK1_01_SHI'],
      prerequisiteGrammarIds: ['GRM_HSK1_01_SHI'],
      examples: const [
        GrammarExample(
          hanzi: '你是学生吗？',
          pinyin: 'Nǐ shì xuésheng ma?',
          translationVi: 'Bạn có phải là học sinh không?',
          breakdown: '你是学生 (Bạn là học sinh) + 吗 (không?)',
        ),
        GrammarExample(
          hanzi: '今天冷吗？',
          pinyin: 'Jīntiān lěng ma?',
          translationVi: 'Hôm nay có lạnh không?',
          breakdown: '今天冷 (Hôm nay lạnh) + 吗 (không?)',
        ),
      ],
      contrastiveExamples: const [
        ContrastiveExample(
          incorrectSentence: '他是谁吗？',
          correctSentence: '他是谁？ (Tā shì shéi?)',
          explanationVi: 'Câu đã có đại từ nghi vấn "谁" (ai) thì không được dùng thêm trợ từ ngữ khí "吗".',
          errorType: 'redundant_question_particle',
        ),
      ],
      exercises: const [
        GrammarExercise(
          id: 'EX_MA_01_MC',
          type: GrammarExerciseType.multipleChoice,
          prompt: 'Chọn trợ từ thích hợp biến câu sau thành câu hỏi:',
          sentenceWithBlank: '你喜欢喝茶 ___？',
          options: ['吗', '呢', '的', '了'],
          correctAnswerIndex: 0,
          targetSentence: '你喜欢喝茶吗？',
          explanationVi: 'Hỏi có/không cho câu trần thuật dùng trợ từ "吗" ở cuối câu.',
        ),
        GrammarExercise(
          id: 'EX_MA_02_REORDER',
          type: GrammarExerciseType.reorderWords,
          prompt: 'Sắp xếp các từ thành câu hỏi hoàn chỉnh:',
          shuffledTokens: ['忙', '吗', '今天', '你'],
          targetSentence: '你今天忙吗？',
          acceptableAnswers: ['你今天忙吗', '你今天忙吗？', '今天你忙吗', '今天你忙吗？'],
          explanationVi: 'Trợ từ "吗" luôn đặt ở cuối câu hỏi.',
        ),
      ],
      createdAt: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 11, 1),
    ),

    // 3. GRM_HSK1_03_ZAI_PLACE
    GrammarItem(
      id: 'GRM_HSK1_03_ZAI_PLACE',
      hskLevel: 1,
      code: 'grm_hsk1_zai_preposition',
      title: 'Giới từ 在 chỉ địa điểm thực hiện hành động',
      structure: 'Chủ ngữ + 在 + Địa điểm + Động từ + (Tân ngữ)',
      meaningVi: 'Biểu thị hành động diễn ra ở đâu: "Ở [địa điểm] làm [việc gì]".',
      usageConditionsVi: 'Ngược lại với tiếng Việt, cụm giới từ chỉ địa điểm "在 + nơi chốn" bắt buộc phải đứng TRƯỚC động từ chính.',
      sentencePositionVi: 'Nằm giữa Chủ ngữ và Động từ chính của câu.',
      explanationVi: 'Một trong những điểm ngữ pháp gây sai sót nhiều nhất cho người Việt Nam: người Việt thường nói "học ở trường", nhưng tiếng Trung bắt buộc phải nói "ở trường học" (在学校学习).',
      source: 'HSK Standard Course 1 - Bài 9',
      tags: ['giới_từ_địa_điểm', 'trật_tự_từ', 'hsk1_cơ_bản'],
      relatedVocabIds: [],
      relatedGrammarIds: [],
      prerequisiteGrammarIds: ['GRM_HSK1_01_SHI'],
      examples: const [
        GrammarExample(
          hanzi: '我在家看书。',
          pinyin: 'Wǒ zài jiā kàn shū.',
          translationVi: 'Tôi đọc sách ở nhà.',
          breakdown: '我 (Tôi) + 在家 (ở nhà) + 看书 (đọc sách)',
        ),
        GrammarExample(
          hanzi: '爸爸在医院工作。',
          pinyin: 'Bàba zài yīyuàn gōngzuò.',
          translationVi: 'Bố làm việc ở bệnh viện.',
          breakdown: '爸爸 (Bố) + 在医院 (ở bệnh viện) + 工作 (làm việc)',
        ),
      ],
      contrastiveExamples: const [
        ContrastiveExample(
          incorrectSentence: '我看书在家。 / 爸爸工作在医院。',
          correctSentence: '我在家看书。 / 爸爸在医院工作。',
          explanationVi: 'Lỗi dịch từng từ tiếng Việt sang: Tiếng Trung quy định trạng ngữ chỉ nơi chốn phải đứng trước hành động.',
          errorType: 'word_order_locative',
        ),
      ],
      exercises: const [
        GrammarExercise(
          id: 'EX_ZAI_01_REORDER',
          type: GrammarExerciseType.reorderWords,
          prompt: 'Sắp xếp trật tự từ đúng ngữ pháp tiếng Trung:',
          shuffledTokens: ['看书', '在', '学校', '我们'],
          targetSentence: '我们在学校看书。',
          acceptableAnswers: ['我们在学校看书', '我们在学校看书。'],
          explanationVi: 'Trạng ngữ nơi chốn "在学校" phải đứng trước hành động "看书".',
        ),
        GrammarExercise(
          id: 'EX_ZAI_02_OPEN',
          type: GrammarExerciseType.openTranslation,
          prompt: 'Dịch câu sau: "Họ ăn cơm ở nhà hàng."',
          targetSentence: '他们在饭馆吃饭。',
          acceptableAnswers: ['他们在饭馆吃饭', '他们在饭馆吃饭。', '他们在餐厅吃饭', '他们在餐厅吃饭。'],
          rubricKeywords: ['在', '饭馆', '吃饭'],
          explanationVi: 'Họ (他们) + ở nhà hàng (在饭馆) + ăn cơm (吃饭).',
        ),
      ],
      createdAt: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 11, 1),
    ),

    // 4. GRM_HSK1_04_DE_POSSESSIVE
    GrammarItem(
      id: 'GRM_HSK1_04_DE_POSSESSIVE',
      hskLevel: 1,
      code: 'grm_hsk1_de_structural',
      title: 'Trợ từ kết cấu 的 biểu thị sở hữu',
      structure: 'Định ngữ (Chủ sở hữu) + 的 + Trung tâm ngữ (Đối tượng)',
      meaningVi: 'Biểu thị mối quan hệ sở hữu "của" hoặc quan hệ định danh bổ nghĩa.',
      usageConditionsVi: 'Khi đối tượng là người thân trong gia đình hoặc đơn vị thân thuộc (nhà tôi, mẹ tôi), có thể lược bỏ 的 (我妈妈, 我家).',
      sentencePositionVi: 'Đứng ngay sau từ/cụm từ đóng vai trò bổ nghĩa (định ngữ).',
      explanationVi: 'Trợ từ "的" là một trong những từ phổ biến nhất trong tiếng Trung. Quy tắc vàng: Thành phần bổ nghĩa đứng trước 的, vật/người được bổ nghĩa đứng sau 的.',
      source: 'HSK Standard Course 1 - Bài 3',
      tags: ['trợ_từ_kết_cấu', 'sở_hữu', 'hsk1_cơ_bản'],
      relatedVocabIds: [],
      relatedGrammarIds: [],
      prerequisiteGrammarIds: [],
      examples: const [
        GrammarExample(
          hanzi: '这是我的汉语书。',
          pinyin: 'Zhè shì wǒ de Hànyǔ shū.',
          translationVi: 'Đây là sách tiếng Hán của tôi.',
          breakdown: '这 (Đây) + 是 (là) + 我的 (của tôi) + 汉语书 (sách tiếng Hán)',
        ),
      ],
      contrastiveExamples: const [
        ContrastiveExample(
          incorrectSentence: '书的我',
          correctSentence: '我的书 (Wǒ de shū)',
          explanationVi: 'Tiếng Trung ngược tiếng Việt: Người sở hữu đứng trước, đồ vật đứng sau 的.',
          errorType: 'word_order_modifier',
        ),
      ],
      exercises: const [
        GrammarExercise(
          id: 'EX_DE_01_MC',
          type: GrammarExerciseType.multipleChoice,
          prompt: 'Chọn đáp án đúng điền vào chỗ trống:',
          sentenceWithBlank: '这是李老师 ___ 电脑。',
          options: ['的', '得', '地', '了'],
          correctAnswerIndex: 0,
          targetSentence: '这是李老师的电脑。',
          explanationVi: 'Nối người sở hữu (李老师) với danh từ (电脑) dùng trợ từ kết cấu "的".',
        ),
      ],
      createdAt: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 11, 1),
    ),

    // 5. GRM_HSK2_01_BI_COMPARISON
    GrammarItem(
      id: 'GRM_HSK2_01_BI_COMPARISON',
      hskLevel: 2,
      code: 'grm_hsk2_bi_comparative',
      title: 'Câu so sánh hơn với chữ 比 (bǐ)',
      structure: 'A + 比 + B + Tính từ (+ Số lượng / 多了)',
      meaningVi: 'Biểu thị sự so sánh hơn: "A ... hơn B".',
      usageConditionsVi: 'KHÔNG được dùng các phó từ mức độ như "很", "非常", "真" trước tính từ sau 比. Muốn biểu thị hơn nhiều dùng "多了" hoặc "得多" ở sau tính từ.',
      sentencePositionVi: 'Cụm "比 + B" đặt trực tiếp trước tính từ vị ngữ.',
      explanationVi: 'Câu chữ 比 là cấu trúc so sánh cơ bản nhất trong HSK 2.',
      source: 'HSK Standard Course 2 - Bài 10',
      tags: ['câu_so_sánh', 'hsk2_nâng_cao'],
      relatedVocabIds: [],
      relatedGrammarIds: [],
      prerequisiteGrammarIds: ['GRM_HSK1_01_SHI'],
      examples: const [
        GrammarExample(
          hanzi: '哥哥比我高。',
          pinyin: 'Gēge bǐ wǒ gāo.',
          translationVi: 'Anh trai cao hơn tôi.',
          breakdown: '哥哥 (Anh trai) + 比我 (so với tôi) + 高 (cao)',
        ),
        GrammarExample(
          hanzi: '今天比昨天冷得多。',
          pinyin: 'Jīntiān bǐ zuótiān lěng de duō.',
          translationVi: 'Hôm nay lạnh hơn hôm qua rất nhiều.',
          breakdown: '今天 (Hôm nay) + 比昨天 (so với hôm qua) + 冷得多 (lạnh hơn nhiều)',
        ),
      ],
      contrastiveExamples: const [
        ContrastiveExample(
          incorrectSentence: '哥哥比我很高。 / 今天比昨天非常冷。',
          correctSentence: '哥哥比我高。 / 今天比昨天冷得多。',
          explanationVi: 'Trong câu chữ 比 tuyệt đối không đặt "很", "非常" trước tính từ, vì bản thân "比" đã mang ý nghĩa so sánh mức độ.',
          errorType: 'prohibited_degree_adverb',
        ),
      ],
      exercises: const [
        GrammarExercise(
          id: 'EX_BI_01_MC',
          type: GrammarExerciseType.multipleChoice,
          prompt: 'Chọn câu viết đúng ngữ pháp so sánh:',
          sentenceWithBlank: '西瓜 ___ 苹果大。',
          options: ['比', '跟', '有', '像'],
          correctAnswerIndex: 0,
          targetSentence: '西瓜比苹果大。',
          explanationVi: 'Cấu trúc so sánh hơn dùng chữ "比": A 比 B + Tính từ.',
        ),
        GrammarExercise(
          id: 'EX_BI_02_REORDER',
          type: GrammarExerciseType.reorderWords,
          prompt: 'Sắp xếp câu so sánh đúng:',
          shuffledTokens: ['大', '弟弟', '比', '我'],
          targetSentence: '我比弟弟大。',
          acceptableAnswers: ['我比弟弟大', '我比弟弟大。', '弟弟比我大', '弟弟比我大。'],
          explanationVi: 'A 比 B + Tính từ (Tôi lớn tuổi hơn em trai).',
        ),
      ],
      createdAt: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 11, 1),
    ),

    // 6. GRM_HSK2_02_BA_SENTENCE
    GrammarItem(
      id: 'GRM_HSK2_02_BA_SENTENCE',
      hskLevel: 2,
      code: 'grm_hsk2_ba_disposal',
      title: 'Câu chữ 把 (bǎ) cơ bản',
      structure: 'Chủ ngữ + 把 + Tân ngữ + Động từ + Thành phần khác (了/bổ ngữ)',
      meaningVi: 'Biểu thị sự xử lý, tác động làm thay đổi vị trí hoặc trạng thái của đối tượng.',
      usageConditionsVi: '1. Tân ngữ sau 把 phải là đối tượng xác định (đã biết).\n2. Động từ không được đứng trơ trọi một mình, bắt buộc phải có thành phần khác như "了", lặp lại động từ hoặc bổ ngữ.',
      sentencePositionVi: 'Cụm "把 + Tân ngữ" đứng trước động từ chính.',
      explanationVi: 'Câu chữ 把 là câu đặc trưng quan trọng nhất trong ngữ pháp tiếng Hán.',
      source: 'HSK Standard Course 3 / HSK 2 Mở rộng',
      tags: ['câu_chữ_bả', 'câu_xử_lý', 'hsk2_nâng_cao'],
      relatedVocabIds: [],
      relatedGrammarIds: [],
      prerequisiteGrammarIds: ['GRM_HSK1_03_ZAI_PLACE'],
      examples: const [
        GrammarExample(
          hanzi: '请把门关上。',
          pinyin: 'Qǐng bǎ mén guān shàng.',
          translationVi: 'Xin hãy đóng cửa lại.',
          breakdown: '请 (Xin) + 把门 (đem cửa) + 关上 (đóng lại)',
        ),
      ],
      contrastiveExamples: const [
        ContrastiveExample(
          incorrectSentence: '请把门关。',
          correctSentence: '请把门关上。 (Qǐng bǎ mén guān shàng.)',
          explanationVi: 'Động từ "关" không được đứng đơn độc, phải có bổ ngữ kết quả/xu hướng "上" đi kèm.',
          errorType: 'bare_verb_in_ba_construction',
        ),
      ],
      exercises: const [
        GrammarExercise(
          id: 'EX_BA_01_REORDER',
          type: GrammarExerciseType.reorderWords,
          prompt: 'Sắp xếp câu chữ 把 hoàn chỉnh:',
          shuffledTokens: ['把', '喝了', '他', '水'],
          targetSentence: '他把水喝了。',
          acceptableAnswers: ['他把水喝了', '他把水喝了。'],
          explanationVi: 'Chủ ngữ (他) + 把 + Tân ngữ (水) + Động từ kèm thành phần khác (喝了).',
        ),
      ],
      createdAt: DateTime.utc(2026, 11, 1),
      updatedAt: DateTime.utc(2026, 11, 1),
    ),
  ];

  static GrammarItem? findById(String id) {
    try {
      return items.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<GrammarItem> getByLevel(int level) {
    return items.where((item) => item.hskLevel == level).toList();
  }
}
