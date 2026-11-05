import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/app_database.dart';
import 'package:hi_chinese/core/database/dao/learner_evidence_dao.dart';
import 'package:hi_chinese/core/network/ai/ai_service.dart';
import 'package:hi_chinese/core/network/ai/models/ai_model_config.dart';
import 'package:hi_chinese/core/network/ai/providers/mock_ai_provider.dart';
import 'package:hi_chinese/core/network/ai/security/ai_credential_storage.dart';
import 'package:hi_chinese/features/ai_tutor/ai_tutor.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('TutorSystemPromptBuilder Tests', () {
    test('1. Includes core bilingual persona and pedagogical role', () {
      final prompt = TutorSystemPromptBuilder.build(
        const TutorPromptOptions(
          persona: TutorPersonas.qiaoqiao,
          scenario: TutorScenarios.restaurant,
          learnerHskLevel: 2,
          learnerName: 'Nguyễn Văn A',
        ),
      );

      expect(prompt, contains('Gia Sư Tiếng Trung AI'));
      expect(prompt, contains('乔乔老师'));
      expect(prompt, contains('餐厅点餐'));
      expect(prompt, contains('Nguyễn Văn A'));
      expect(prompt, contains('HSK 2'));
    });

    test('2. Enforces strict Anti-Hypercorrection guardrails', () {
      final prompt = TutorSystemPromptBuilder.build(
        const TutorPromptOptions(
          persona: TutorPersonas.laowang,
        ),
      );

      expect(prompt, contains('CHỐNG SỬA NHẦM CÂU ĐÚNG (ANTI-HYPERCORRECTION)'));
      expect(prompt, contains('TUYỆT ĐỐI KHÔNG ĐƯỢC CỐ TÌNH BỚI LÔNG TÌM VẾT'));
      expect(prompt, contains('is_correct: true'));
      expect(prompt, contains('error_category: "none"'));
    });

    test('3. Enforces 3-step pedagogical error correction loop', () {
      final prompt = TutorSystemPromptBuilder.build(
        const TutorPromptOptions(),
      );

      expect(prompt, contains('NGUYÊN TẮC SƯ PHẠM 3 BƯỚC'));
      expect(prompt, contains('Bước 1 (Khích lệ)'));
      expect(prompt, contains('Bước 2 (Phân tích chi tiết kèm Pinyin)'));
      expect(prompt, contains('Bước 3 (Mẫu câu chuẩn tự nhiên)'));
    });

    test('4. Injects SRS active recall vocabulary into prompt', () {
      final prompt = TutorSystemPromptBuilder.build(
        const TutorPromptOptions(
          weakSrsWords: ['苹果', '多少钱', '好吃'],
        ),
      );

      expect(prompt, contains('SRS VOCABULARY INJECTION'));
      expect(prompt, contains('苹果, 多少钱, 好吃'));
      expect(prompt, contains('HÃY KHÉO LÉO LỒNG GHÉP 1-2 TỪ NÀY'));
    });

    test('5. Supports different personas (Qiaoqiao, Lao Wang, Xiao Ming)', () {
      final p1 = TutorSystemPromptBuilder.build(
        const TutorPromptOptions(persona: TutorPersonas.qiaoqiao),
      );
      final p2 = TutorSystemPromptBuilder.build(
        const TutorPromptOptions(persona: TutorPersonas.laowang),
      );
      final p3 = TutorSystemPromptBuilder.build(
        const TutorPromptOptions(persona: TutorPersonas.xiaoming),
      );

      expect(p1, contains('乔乔老师'));
      expect(p2, contains('老王老师'));
      expect(p3, contains('小明'));
      expect(p2, contains('thành ngữ thường dùng (成语)'));
      expect(p3, contains('khẩu ngữ đời sống thực tế (口语)'));
    });

    test('6. Forbids placement test suggestions in normal conversation (T3-1)', () {
      final prompt = TutorSystemPromptBuilder.build(
        const TutorPromptOptions(),
      );

      expect(prompt, contains('# QUAN TRỌNG – VỀ BÀI KIỂM TRA NĂNG LỰC:'));
      expect(
        prompt,
        contains(
          '- Không gợi ý người dùng "làm bài kiểm tra năng lực đầu vào" hay "placement test" trong quá trình hội thoại thông thường.',
        ),
      );
      expect(
        prompt,
        contains(
          '- Bài kiểm tra năng lực chỉ được thực hiện một lần duy nhất khi lần đầu khởi động ứng dụng.',
        ),
      );
      expect(
        prompt,
        contains(
          '- Nếu người dùng hỏi về trình độ của mình, hãy dựa vào thông tin HSK level hiện tại được cung cấp trong context.',
        ),
      );
    });

    test('7. Injects learning path context (comprehensive vs focused) (T3-1)', () {
      final promptComp = TutorSystemPromptBuilder.build(
        const TutorPromptOptions(
          learningPathType: 'comprehensive',
        ),
      );
      expect(
        promptComp,
        contains(
          'Người dùng đang theo lộ trình Toàn Diện – học đều tất cả 6 kỹ năng.',
        ),
      );

      final promptFocused = TutorSystemPromptBuilder.build(
        const TutorPromptOptions(
          learningPathType: 'focused',
          focusSkill: 'reading',
        ),
      );
      expect(
        promptFocused,
        contains(
          'Người dùng đang tập trung vào kỹ năng: reading.',
        ),
      );
    });

    test('8. Guards brand new learners from SRS and prompts first lesson (T3-1)', () {
      final prompt = TutorSystemPromptBuilder.build(
        const TutorPromptOptions(
          hasCompletedLessons: false,
          weakSrsWords: ['苹果', '多少钱'],
        ),
      );

      expect(prompt, contains('# HƯỚNG DẪN DÀNH CHO NGƯỜI HỌC MỚI BẮT ĐẦU'));
      expect(
        prompt,
        contains('Bắt đầu bài học đầu tiên của bạn – Bài 1 HSK 1 đang chờ bạn!'),
      );
      expect(prompt, contains('Tuyệt đối KHÔNG đề xuất ôn tập từ vựng'));
      expect(prompt, isNot(contains('SRS VOCABULARY INJECTION')));
    });
  });

  group('TutorContextBuilder Tests', () {
    const builder = TutorContextBuilder(maxHistoryTurns: 4);

    test('1. Prunes historical turns according to sliding window bound', () {
      final rawHistory = [
        {'role': 'user', 'content': 'Turn 1'},
        {'role': 'assistant', 'content': 'Turn 2'},
        {'role': 'user', 'content': 'Turn 3'},
        {'role': 'assistant', 'content': 'Turn 4'},
        {'role': 'user', 'content': 'Turn 5'},
        {'role': 'assistant', 'content': 'Turn 6'},
      ];

      final request = builder.buildRequest(
        userInput: 'Turn 7',
        rawDbHistory: rawHistory,
      );

      // maxHistoryTurns is 4, plus current turn 7 = 5 contents
      expect(request.contents.length, 5);
      expect(request.contents.first.parts.first.text, 'Turn 3');
      expect(request.contents.last.parts.first.text, 'Turn 7');
      expect(request.contents.last.role, 'user');
    });

    test('2. Maps SQLite roles properly to Gemini user and model', () {
      final rawHistory = [
        {'role': 'user', 'content': '你好'},
        {'role': 'assistant', 'content': '你好！请问有什么我可以帮您的？'},
      ];

      final request = builder.buildRequest(
        userInput: '我想学汉语',
        rawDbHistory: rawHistory,
      );

      expect(request.contents[0].role, 'user');
      expect(request.contents[1].role, 'model');
      expect(request.contents[2].role, 'user');
    });

    test('3. Ensures history does not start with model turn', () {
      final rawHistory = [
        {'role': 'assistant', 'content': 'Leading assistant turn'},
        {'role': 'user', 'content': 'User response'},
      ];

      final request = builder.buildRequest(
        userInput: 'Next user turn',
        rawDbHistory: rawHistory,
      );

      expect(request.contents.first.role, 'user');
      expect(request.contents.first.parts.first.text, 'User response');
    });
  });

  group('TutorResponseParser Tests', () {
    test('1. Parses valid clean JSON with correct student sentence (Anti-hypercorrection)', () {
      const jsonText = '''
{
  "reply_zh": "太好了！我也很喜欢中国菜。你最喜欢吃什么？",
  "reply_pinyin": "Tài hǎo le! Wǒ yě hěn xǐhuan Zhōngguó cài. Nǐ zuì xǐhuan chī shénme?",
  "reply_vi": "Tuyệt quá! Tôi cũng rất thích món ăn Trung Quốc. Bạn thích ăn món gì nhất?",
  "evaluation": {
    "is_correct": true,
    "original_text": "我很喜欢中国菜",
    "corrected_text": null,
    "pinyin": "Wǒ hěn xǐhuan Zhōngguó cài",
    "explanation_vi": "Câu của bạn rất chuẩn và tự nhiên!",
    "error_category": "none"
  },
  "follow_up_suggestions": [
    "我最喜欢吃北京烤鸭 (Wǒ zuì xǐhuan chī Běijīng kǎoyā)",
    "我喜欢吃饺子 (Wǒ xǐhuan chī jiǎozi)"
  ],
  "target_vocabulary": ["中国菜", "喜欢"]
}
''';

      final response = TutorResponseParser.parse(jsonText);

      expect(response.replyZh, '太好了！我也很喜欢中国菜。你最喜欢吃什么？');
      expect(response.replyPinyin, contains('Tài hǎo le'));
      expect(response.replyVi, contains('Tuyệt quá'));
      expect(response.evaluation, isNotNull);
      expect(response.evaluation!.isCorrect, isTrue);
      expect(response.evaluation!.correctedText, isNull);
      expect(response.evaluation!.errorCategory, TutorErrorCategory.none);
      expect(response.followUpSuggestions.length, 2);
      expect(response.targetVocabulary, contains('中国菜'));
    });

    test('2. Parses markdown fenced JSON with 3-step error correction', () {
      const markdownJson = '''
Here is the feedback:
```json
{
  "reply_zh": "没关系，慢慢学。你想喝点什么？",
  "reply_pinyin": "Méi guānxi, mànmàn xué. Nǐ xiǎng hē diǎn shénme?",
  "reply_vi": "Không sao đâu, học từ từ nhé. Bạn muốn uống gì nào?",
  "evaluation": {
    "is_correct": false,
    "original_text": "我想买一书",
    "corrected_text": "我想买一本书",
    "pinyin": "Wǒ xiǎng mǎi yì běn shū",
    "explanation_vi": "1. Bạn diễn đạt rất rõ ý định muốn mua sách!\\n2. Trong tiếng Trung, khi đếm danh từ bắt buộc phải có lượng từ ở giữa. Với sách báo (书), lượng từ chuẩn là '本' (běn), không được nói '一书'.\\n3. Câu chuẩn tự nhiên: '我想买一本书' (Wǒ xiǎng mǎi yì běn shū).",
    "error_category": "missing_component"
  },
  "follow_up_suggestions": [
    "我想喝茶 (Wǒ xiǎng hē chá)",
    "给我一杯水 (Gěi wǒ yì bēi shuǐ)"
  ],
  "target_vocabulary": ["本", "书"]
}
```
''';

      final response = TutorResponseParser.parse(markdownJson);

      expect(response.replyZh, '没关系，慢慢学。你想喝点什么？');
      expect(response.evaluation, isNotNull);
      expect(response.evaluation!.isCorrect, isFalse);
      expect(response.evaluation!.correctedText, '我想买一本书');
      expect(response.evaluation!.errorCategory, TutorErrorCategory.missingComponent);
      expect(response.evaluation!.explanationVi, contains('1. Bạn diễn đạt'));
    });

    test('3. Falls back gracefully to unstructured text output', () {
      const unstructuredText = '''
你好！欢迎来到中国！
Nǐ hǎo! Huānyíng lái dào Zhōngguó!
Xin chào! Hoan nghênh bạn đến Trung Quốc!
''';

      final response = TutorResponseParser.parse(unstructuredText);

      expect(response.replyZh, contains('你好！欢迎来到中国！'));
      expect(response.replyPinyin, contains('Nǐ hǎo!'));
      expect(response.replyVi, contains('Xin chào!'));
      expect(response.evaluation, isNull);
    });
  });

  group('AiTutorRepository SQLite & AI Engine Tests', () {
    late Directory tempDir;
    late String dbPath;
    late AppDatabase appDatabase;
    late MockAiProvider mockAiProvider;
    late AiService aiService;
    late AiTutorRepository repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hi_chinese_tutor_test_');
      dbPath = '${tempDir.path}/test_tutor.db';

      appDatabase = AppDatabase.instance;
      await appDatabase.open(customPath: dbPath);

      mockAiProvider = MockAiProvider();
      aiService = AiService(
        provider: mockAiProvider,
        credentialStorage: AiCredentialStorage.inMemory(initialApiKey: 'test_key'),
        modelRegistry: AiModelRegistry(),
      );

      repository = AiTutorRepositoryImpl(
        database: appDatabase,
        aiService: aiService,
      );
    });

    tearDown(() async {
      await appDatabase.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('1. createSession creates session record and initial scenario greeting', () async {
      final sessionId = await repository.createSession(
        title: 'Bữa trưa tại nhà hàng',
        scenarioCode: 'restaurant',
      );

      expect(sessionId, startsWith('chat_session_'));

      final turns = await repository.getSessionTurns(sessionId);
      expect(turns.length, 1);
      expect(turns.first.role, 'assistant');
      expect(turns.first.content, TutorScenarios.restaurant.initialAiGreetingZh);
      expect(turns.first.translationVi, TutorScenarios.restaurant.initialAiGreetingVi);
    });

    test('2. sendMessage inserts user turn, calls AI, saves assistant turn, and records evidence for errors', () async {
      final sessionId = await repository.createSession(
        title: 'Luyện ngữ pháp',
        scenarioCode: 'free_chat',
      );

      // Configure Mock AI Provider with structured error correction JSON
      mockAiProvider.customTextResponse = '''
{
  "reply_zh": "我知道你想喝水。下次记得加上量词哦！",
  "reply_pinyin": "Wǒ zhīdào nǐ xiǎng hē shuǐ. Xià cì jìde jiā shàng liàngcí ó!",
  "reply_vi": "Tôi biết bạn muốn uống nước. Lần sau nhớ thêm lượng từ nhé!",
  "evaluation": {
    "is_correct": false,
    "original_text": "我想喝一水",
    "corrected_text": "我想喝一杯水",
    "pinyin": "Wǒ xiǎng hē yì bēi shuǐ",
    "explanation_vi": "1. Bạn nói rất dễ hiểu!\\n2. Cần lượng từ 杯 (bēi - cốc/ly) trước nước.\\n3. Câu chuẩn: 我想喝一杯水。",
    "error_category": "missing_component"
  },
  "follow_up_suggestions": [
    "谢谢老师 (Xièxie lǎoshī)",
    "我明白了 (Wǒ míngbai le)"
  ],
  "target_vocabulary": ["杯", "水"]
}
''';

      final response = await repository.sendMessage(
        sessionId: sessionId,
        userText: '我想喝一水',
      );

      expect(response.replyZh, contains('我知道你想喝水'));
      expect(response.evaluation, isNotNull);
      expect(response.evaluation!.isCorrect, isFalse);
      expect(response.evaluation!.correctedText, '我想喝一杯水');

      // Verify SQLite state
      final turns = await repository.getSessionTurns(sessionId);
      // 1 initial greeting + 1 user turn + 1 assistant turn = 3 turns
      expect(turns.length, 3);
      expect(turns[1].role, 'user');
      expect(turns[1].content, '我想喝一水');
      expect(turns[2].role, 'assistant');
      expect(turns[2].content, contains('我知道你想喝水'));

      // Verify that learner evidence was recorded in SQLite
      final db = appDatabase.database;
      final evidenceDao = LearnerEvidenceDao(db);
      final evidence = await evidenceDao.getRecentEvidence();
      expect(evidence.isNotEmpty, isTrue);
      expect(evidence.first['source'], 'ai_tutor');
      expect(evidence.first['score'], 0.0); // Marked 0.0 because isCorrect = false
    });

    test('3. sendMessageStream streams tokens and persists complete turn', () async {
      final sessionId = await repository.createSession(
        title: 'Hội thoại nhanh',
        scenarioCode: 'free_chat',
      );

      mockAiProvider.customStreamChunks = [
        '{\n',
        '  "reply_zh": "你好呀！",\n',
        '  "reply_pinyin": "Nǐ hǎo ya!",\n',
        '  "reply_vi": "Chào bạn nha!",\n',
        '  "evaluation": {\n',
        '    "is_correct": true,\n',
        '    "original_text": "你好",\n',
        '    "corrected_text": null,\n',
        '    "pinyin": "Nǐ hǎo",\n',
        '    "explanation_vi": "Chào hỏi rất tự nhiên!",\n',
        '    "error_category": "none"\n',
        '  },\n',
        '  "follow_up_suggestions": ["最近好吗？ (Zuìjìn hǎo ma?)"],\n',
        '  "target_vocabulary": ["你好"]\n',
        '}'
      ];

      final streamedTokens = <String>[];
      TutorResponse? completedResponse;

      final stream = repository.sendMessageStream(
        sessionId: sessionId,
        userText: '你好',
        onComplete: (res) {
          completedResponse = res;
        },
      );

      await for (final token in stream) {
        streamedTokens.add(token);
      }

      expect(streamedTokens.length, 15);
      expect(completedResponse, isNotNull);
      expect(completedResponse!.replyZh, '你好呀！');
      expect(completedResponse!.evaluation!.isCorrect, isTrue);

      // Verify that the assistant message was persisted into SQLite
      final turns = await repository.getSessionTurns(sessionId);
      expect(turns.length, 3);
      expect(turns.last.content, '你好呀！');
      expect(turns.last.role, 'assistant');
    });
  });
}
