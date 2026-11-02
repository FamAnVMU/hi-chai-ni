/// Comprehension question for a Chinese listening lesson.
class ListeningQuestion {
  final String id;
  final String prompt;
  final List<String> options;
  final int correctOptionIndex;
  final String explanationVi;

  const ListeningQuestion({
    required this.id,
    required this.prompt,
    required this.options,
    required this.correctOptionIndex,
    required this.explanationVi,
  });

  bool isCorrect(int selectedIndex) => selectedIndex == correctOptionIndex;
}

/// A structured Chinese listening comprehension lesson.
class ListeningLesson {
  final String id;
  final int hskLevel;
  final String title;
  final String description;
  final String audioUrl;
  final int durationSeconds;
  final String transcriptZh;
  final String transcriptPinyin;
  final String transcriptVi;
  final List<ListeningQuestion> questions;

  const ListeningLesson({
    required this.id,
    required this.hskLevel,
    required this.title,
    required this.description,
    required this.audioUrl,
    required this.durationSeconds,
    required this.transcriptZh,
    required this.transcriptPinyin,
    required this.transcriptVi,
    required this.questions,
  });

  static List<ListeningLesson> get defaultLessons => const [
        ListeningLesson(
          id: 'LIS_HSK1_01_GREETING',
          hskLevel: 1,
          title: 'Chào hỏi và làm quen (HSK 1)',
          description: 'Hội thoại ngắn giữa hai sinh viên mới gặp nhau trong trường đại học.',
          audioUrl: 'asset:///assets/audio/listening_hsk1_01.mp3',
          durationSeconds: 24,
          transcriptZh: '男：你好！请问你叫什么名字？\n女：你好！我叫王丽。你呢？\n男：我叫李明。很高兴认识你！\n女：我也很高兴认识你！',
          transcriptPinyin: 'Nán: Nǐ hǎo! Qǐngwèn nǐ jiào shénme míngzi?\nNǚ: Nǐ hǎo! Wǒ jiào Wáng Lì. Nǐ ne?\nNán: Wǒ jiào Lǐ Míng. Hěn gāoxìng rènshi nǐ!\nNǚ: Wǒ yě hěn gāoxìng rènshi nǐ!',
          transcriptVi: 'Nam: Xin chào! Cho hỏi bạn tên là gì?\nNữ: Xin chào! Tôi tên là Vương Lệ. Còn bạn?\nNam: Tôi tên là Lý Minh. Rất vui được quen biết bạn!\nNữ: Tôi cũng rất vui được quen biết bạn!',
          questions: [
            ListeningQuestion(
              id: 'q1',
              prompt: 'Cô gái trong đoạn hội thoại tên là gì?',
              options: ['Vương Lệ', 'Lý Minh', 'Trương Hoa', 'Tiểu Vũ'],
              correctOptionIndex: 0,
              explanationVi: 'Cô gái nói: "我叫王丽 (Tôi tên là Vương Lệ)".',
            ),
            ListeningQuestion(
              id: 'q2',
              prompt: 'Tâm trạng của chàng trai khi gặp cô gái thế nào?',
              options: ['Tức giận', 'Lo lắng', 'Rất vui mừng', 'Mệt mỏi'],
              correctOptionIndex: 2,
              explanationVi: 'Chàng trai nói: "很高兴认识你 (Rất vui được quen biết bạn)".',
            ),
          ],
        ),
        ListeningLesson(
          id: 'LIS_HSK2_01_SHOPPING',
          hskLevel: 2,
          title: 'Hỏi giá và mua trái cây (HSK 2)',
          description: 'Hội thoại mua táo và dưa hấu tại quầy hoa quả chợ truyền thống.',
          audioUrl: 'asset:///assets/audio/listening_hsk2_01.mp3',
          durationSeconds: 32,
          transcriptZh: '顾客：老板，这苹果多少钱一斤？\n老板：五块钱一斤。西瓜便宜，三块钱一斤。\n顾客：来两斤苹果和一个西瓜，一共多少钱？\n老板：一共二十块钱。',
          transcriptPinyin: 'Gùkè: Lǎobǎn, zhè píngguǒ duōshao qián yì jīn?\nLǎobǎn: Wǔ kuài qián yì jīn. Xīguā piányi, sān kuài qián yì jīn.\nGùkè: Lái liǎng jīn píngguǒ hé yí gè xīguā, yígòng duōshao qián?\nLǎobǎn: Yígòng èrshí kuài qián.',
          transcriptVi: 'Khách: Ông chủ, táo này bao nhiêu tiền một cân?\nChủ: Năm đồng một cân. Dưa hấu rẻ hơn, ba đồng một cân.\nKhách: Cho tôi hai cân táo và một quả dưa hấu, tổng cộng bao nhiêu tiền?\nChủ: Tổng cộng hai mươi đồng.',
          questions: [
            ListeningQuestion(
              id: 'q1',
              prompt: 'Táo có giá bao nhiêu một cân?',
              options: ['3 đồng', '5 đồng', '10 đồng', '20 đồng'],
              correctOptionIndex: 1,
              explanationVi: 'Chủ quán trả lời: "五块钱一斤 (Năm đồng một cân)".',
            ),
            ListeningQuestion(
              id: 'q2',
              prompt: 'Khách hàng đã mua tổng cộng hết bao nhiêu tiền?',
              options: ['15 đồng', '18 đồng', '20 đồng', '25 đồng'],
              correctOptionIndex: 2,
              explanationVi: 'Chủ quán tính tổng: "一共二十块钱 (Tổng cộng hai mươi đồng)".',
            ),
          ],
        ),
      ];
}
