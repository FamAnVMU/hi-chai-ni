import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/dao/activity_dao.dart';
import '../../../../core/database/dao/learner_evidence_dao.dart';
import '../../../../core/database/dao/reading_dao.dart';
import '../../../../core/network/ai/ai.dart';
import '../../../../core/utils/app_clock.dart';
import '../domain/models/reading_models.dart';

abstract class ReadingRepository {
  Future<List<ReadingPassage>> getPassages({int? hskLevel});
  Future<ReadingPassage?> getPassageById(String id);
  Future<ReadingProgress?> getProgress(String passageId);
  Future<void> saveReadingSession({
    required String passageId,
    required int readingTimeSeconds,
    required double lastScrollOffset,
    required Map<String, int> answers,
    required bool isCompleted,
    double? score,
  });
  Future<String> askAiAboutPassage({
    required String passageText,
    required String userQuestion,
    CancelToken? cancelToken,
  });
}

class DefaultReadingRepository implements ReadingRepository {
  final Database _db;
  final AiService _aiService;
  late final ReadingDao _readingDao;
  late final LearnerEvidenceDao _evidenceDao;
  late final ActivityDao _activityDao;

  DefaultReadingRepository(
    this._db, {
    AiService? aiService,
  })  : _aiService = aiService ??
            AiService(
              provider: GeminiRestAiProvider(
                credentialStorage: AiCredentialStorage(),
              ),
              credentialStorage: AiCredentialStorage(),
              modelRegistry: AiModelRegistry(),
            ) {
    _readingDao = ReadingDao(_db);
    _evidenceDao = LearnerEvidenceDao(_db);
    _activityDao = ActivityDao(_db);
  }

  @override
  Future<List<ReadingPassage>> getPassages({int? hskLevel}) async {
    List<Map<String, dynamic>> rows;
    if (hskLevel != null) {
      rows = await _readingDao.getPassagesByHsk(hskLevel);
    } else {
      rows = await _readingDao.getAllPassages();
    }

    if (rows.isEmpty) {
      // Fallback curated passages for initial seed / unit test scenarios
      return _fallbackPassages
          .where((p) => hskLevel == null || p.hskLevel == hskLevel)
          .toList();
    }

    return rows.map((r) => ReadingPassage.fromMap(r)).toList();
  }

  @override
  Future<ReadingPassage?> getPassageById(String id) async {
    final row = await _readingDao.getPassageById(id);
    if (row != null) {
      return ReadingPassage.fromMap(row);
    }

    // Check fallback
    final matches = _fallbackPassages.where((p) => p.id == id);
    if (matches.isNotEmpty) return matches.first;

    return null;
  }

  @override
  Future<ReadingProgress?> getProgress(String passageId) async {
    final row = await _readingDao.getProgressByPassageId(passageId);
    if (row == null) return null;
    return ReadingProgress.fromMap(row);
  }

  @override
  Future<void> saveReadingSession({
    required String passageId,
    required int readingTimeSeconds,
    required double lastScrollOffset,
    required Map<String, int> answers,
    required bool isCompleted,
    double? score,
  }) async {
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final progressId = 'prog_${passageId}_${DateTime.now().millisecondsSinceEpoch}';

    await _db.transaction((txn) async {
      // 1. Upsert reading progress
      await txn.insert(
        'reading_progress',
        {
          'id': progressId,
          'passage_id': passageId,
          'last_scroll_offset': lastScrollOffset,
          'is_completed': isCompleted ? 1 : 0,
          'reading_time_seconds': readingTimeSeconds,
          'answers_json': json.encode(answers),
          'score': score,
          'completed_at': isCompleted ? nowUtc : null,
          'created_at': nowUtc,
          'updated_at': nowUtc,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. If completed, persist to learner_evidence and feed daily streak
      if (isCompleted) {
        final evidenceId = 'ev_rdg_${DateTime.now().microsecondsSinceEpoch}';
        await _evidenceDao.appendEvidence(
          {
            'id': evidenceId,
            'content_id': passageId,
            'content_type': 'reading',
            'source': 'reading_comprehension',
            'score': (score ?? 100.0) / 100.0,
            'duration_ms': readingTimeSeconds * 1000,
            'metadata_json': json.encode({
              'reading_time_seconds': readingTimeSeconds,
              'answers': answers,
              'score_percent': score,
            }),
            'created_at': nowUtc,
          },
          txn: txn,
        );

        final activityId = 'act_rdg_${DateTime.now().microsecondsSinceEpoch}';
        await _activityDao.logActivity(
          {
            'id': activityId,
            'activity_type': 'reading',
            'duration_seconds': readingTimeSeconds,
            'items_count': 1,
            'activity_date': AppClock.todayLocalDateString(),
            'created_at': nowUtc,
            'timezone_offset_minutes': AppClock.currentOffset.inMinutes,
          },
          txn: txn,
        );
      }
    });
  }

  @override
  Future<String> askAiAboutPassage({
    required String passageText,
    required String userQuestion,
    CancelToken? cancelToken,
  }) async {
    final trimmedQuestion = userQuestion.trim();
    if (trimmedQuestion.isEmpty) {
      throw const AiValidationException('Câu hỏi không được để trống.');
    }

    final systemPrompt = '''
Bạn là Gia Sư Tiếng Trung AI Kiên Nhẫn & Tận Tâm trong ứng dụng "HI Chinese", hỗ trợ người học đọc hiểu văn bản tiếng Trung Quốc.

# ĐOẠN VĂN GỐC CẦN PHÂN TÍCH:
"""
$passageText
"""

# NGUYÊN TẮC SƯ PHẠM KHI TRẢ LỜI CÂU HỎI:
1. **Dựa trên bài đọc**: Câu trả lời PHẢI dựa trực tiếp trên nội dung đoạn văn trên. Trích dẫn câu văn gốc trong bài (kèm Pinyin và nghĩa tiếng Việt) làm bằng chứng luận điểm.
2. **Giải thích ngữ pháp & từ vựng**: Chỉ ra các cấu trúc ngữ pháp, từ nối hoặc thành ngữ xuất hiện trong đoạn văn liên quan đến câu hỏi của người học.
3. **Phương pháp sư phạm gợi mở (Scaffolding)**: Không chỉ đưa ra đáp án cụt lủn, hãy giải thích logic suy luận từng bước để người học hiểu lý do vì sao lại như vậy và phát triển tư duy đọc hiểu.
4. **Không gợi ý bài kiểm tra năng lực**: Tuyệt đối KHÔNG gợi ý người học làm bài kiểm tra năng lực đầu vào (placement test).

# ĐỊNH DẠNG TRẢ LỜI:
- Trình bày bằng tiếng Việt rõ ràng, sư phạm, thân thiện.
- Sử dụng Markdown có phân mục, in đậm các từ khóa tiếng Trung và có Pinyin hỗ trợ người học.
''';

    final request = AiPromptRequest.singlePrompt(
      trimmedQuestion,
      systemInstruction: systemPrompt,
      temperature: 0.5,
      taskId: 'reading_passage_qa',
    );

    final response = await _aiService.generateText(
      request,
      taskType: AiTaskType.readingComprehension,
      cancelToken: cancelToken,
    );

    return response.text.trim();
  }

  static final List<ReadingPassage> _fallbackPassages = [
    ReadingPassage(
      id: 'RDG_1_reading_hsk1_friend',
      hskLevel: 1,
      titleCn: '我的中国朋友',
      contentCn: '我有一个好朋友，他叫李明。他是中国人，今年二十岁。李明很喜欢学习英语，我也喜欢学习汉语。我们常常一起去图书馆看书，一起喝茶。',
      pinyin: 'wǒ yǒu yí gè hǎo péng yǒu tā jiào lǐ míng tā shì zhōng guó rén jīn nián èr shí suì lǐ míng hěn xǐ huān xué xí yīng yǔ wǒ yě xǐ huān xué xí hàn yǔ wǒ men cháng cháng yì qǐ qù tú shū guǎn kàn shū yì qǐ hē chá',
      translationVi: 'Tôi có một người bạn tốt, anh ấy tên là Lý Minh. Anh ấy là người Trung Quốc, năm nay hai mươi tuổi. Lý Minh rất thích học tiếng Anh, tôi cũng thích học tiếng Trung. Chúng tôi thường cùng nhau đến thư viện đọc sách, cùng nhau uống trà.',
      audioUri: 'assets/audio/reading/rdg_hsk1_friend.mp3',
      topic: 'Đời sống',
      estimatedMinutes: 2,
      questions: [
        const ReadingQuestion(
          id: 'q_hsk1_friend_1',
          type: ReadingQuestionType.singleChoice,
          question: '李明今年多大？(Lý Minh năm nay bao nhiêu tuổi?)',
          options: ['十八岁 (18 tuổi)', '二十岁 (20 tuổi)', '二十二岁 (22 tuổi)', '三十岁 (30 tuổi)'],
          answerIndex: 1,
          explanationVi: 'Trong bài có câu: "他是中国人，今年二十岁。" nên đáp án là 20 tuổi.',
          citationText: '他是中国人，今年二十岁。',
        ),
        const ReadingQuestion(
          id: 'q_hsk1_friend_2',
          type: ReadingQuestionType.trueFalse,
          question: '李明不喜欢学习英语。(Lý Minh không thích học tiếng Anh.)',
          options: ['Đúng (正确)', 'Sai (错误)'],
          answerIndex: 1,
          explanationVi: 'Bài nêu rõ: "李明很喜欢学习英语", do đó nhận định này là Sai.',
          citationText: '李明很喜欢学习英语',
        ),
      ],
    ),
    ReadingPassage(
      id: 'RDG_2_reading_hsk2_restaurant',
      hskLevel: 2,
      titleCn: '在饭馆点菜',
      contentCn: '今天晚上我和家人一起去中国饭馆吃饭。服务员很热情，给我们介绍了几个特色菜。我们点了宫保鸡丁、西红柿炒鸡蛋和两碗米饭。菜的味道非常好，我们吃得很高兴。',
      pinyin: 'jīn tiān wǎn shàng wǒ hé jiā rén yì qǐ qù zhōng guó fàn guǎn chī fàn fú wù yuán hěn rè qíng gěi wǒ men jiè shào le jǐ gè tè sè cài wǒ men diǎn le gōng bǎo jī dīng xī hóng shì chǎo jī dàn hé liǎng wǎn mǐ fàn cài de wèi dào fēi cháng hǎo wǒ men chī de hěn gāo xìng',
      translationVi: 'Tối nay tôi cùng gia đình đến một nhà hàng Trung Quốc dùng bữa. Nhân viên phục vụ rất nhiệt tình, giới thiệu cho chúng tôi vài món đặc sắc. Chúng tôi gọi gà Cung Bảo, trứng xào cà chua và hai bát cơm trắng. Hương vị món ăn rất ngon, chúng tôi ăn uống rất vui vẻ.',
      audioUri: 'assets/audio/reading/rdg_hsk2_restaurant.mp3',
      topic: 'Ẩm thực',
      estimatedMinutes: 3,
      questions: [
        const ReadingQuestion(
          id: 'q_hsk2_rest_1',
          type: ReadingQuestionType.singleChoice,
          question: '他们点了什么菜？(Họ đã gọi những món gì?)',
          options: [
            '北京烤鸭和面条',
            '宫保鸡丁和西红柿炒鸡蛋',
            '鱼香肉丝和青菜',
            '包子和饺子',
          ],
          answerIndex: 1,
          explanationVi: 'Bài đọc viết: "我们点了宫保鸡丁、西红柿炒鸡蛋和两碗米饭。"',
          citationText: '我们点了宫保鸡丁、西红柿炒鸡蛋和两碗米饭。',
        ),
      ],
    ),
  ];
}
