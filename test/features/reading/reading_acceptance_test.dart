import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:hi_chinese/core/audio/audio.dart';
import 'package:hi_chinese/core/network/ai/ai.dart';
import 'package:hi_chinese/core/theme/components/ruby_text/ruby_text.dart';
import 'package:hi_chinese/features/dictionary/data/dictionary_repository.dart';
import 'package:hi_chinese/features/dictionary/domain/models/dictionary_models.dart';
import 'package:hi_chinese/features/reading/data/reading_repository.dart';
import 'package:hi_chinese/features/reading/domain/models/reading_models.dart';
import 'package:hi_chinese/features/reading/presentation/screens/reading_detail_screen.dart';
import 'package:hi_chinese/features/reading/presentation/screens/reading_passage_list_screen.dart';
import 'package:hi_chinese/features/reading/presentation/widgets/reading_questions_section.dart';

/// Fake AudioPlayerService for deterministic unit & acceptance tests.
class FakeAudioPlayerService implements AudioPlayerService {
  AudioPlaybackStatus _status = AudioPlaybackStatus.idle;
  Duration _position = const Duration(seconds: 10);
  final Duration _totalDuration = const Duration(seconds: 120);
  double _speed = 1.0;
  bool _looping = false;

  final StreamController<AudioPlaybackStatus> _statusCtrl =
      StreamController<AudioPlaybackStatus>.broadcast();
  final StreamController<Duration> _posCtrl =
      StreamController<Duration>.broadcast();

  String? lastPlayedUri;
  Duration? lastSeekPosition;
  int playCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;

  @override
  AudioPlaybackStatus get status => _status;

  @override
  Duration get currentPosition => _position;

  @override
  Duration get totalDuration => _totalDuration;

  @override
  double get playbackSpeed => _speed;

  @override
  bool get isLooping => _looping;

  @override
  Stream<AudioPlaybackStatus> get statusStream => _statusCtrl.stream;

  @override
  Stream<Duration> get positionStream => _posCtrl.stream;

  @override
  Future<void> play(String uri, {double speed = 1.0, bool loop = false, Duration? simulatedDuration}) async {
    lastPlayedUri = uri;
    playCalls++;
    _speed = speed;
    _looping = loop;
    _status = AudioPlaybackStatus.playing;
    _statusCtrl.add(_status);
  }

  @override
  Future<void> pause() async {
    pauseCalls++;
    _status = AudioPlaybackStatus.paused;
    _statusCtrl.add(_status);
  }

  @override
  Future<void> resume() async {
    resumeCalls++;
    _status = AudioPlaybackStatus.playing;
    _statusCtrl.add(_status);
  }

  @override
  Future<void> stop() async {
    _status = AudioPlaybackStatus.stopped;
    _statusCtrl.add(_status);
  }

  @override
  Future<void> seek(Duration position) async {
    lastSeekPosition = position;
    _position = position;
    _posCtrl.add(_position);
  }

  @override
  Future<void> setPlaybackSpeed(double speed) async {
    _speed = speed;
  }

  @override
  Future<void> setLooping(bool loop) async {
    _looping = loop;
  }

  @override
  void dispose() {
    _statusCtrl.close();
    _posCtrl.close();
  }
}

/// Fake ReadingRepository providing test passages with varying HSK levels, topics, and progress.
class FakeReadingRepository implements ReadingRepository {
  final List<ReadingPassage> passages;
  final Map<String, ReadingProgress> progressMap;

  FakeReadingRepository({
    required this.passages,
    Map<String, ReadingProgress>? progress,
  }) : progressMap = progress ?? {};

  @override
  Future<List<ReadingPassage>> getPassages({int? hskLevel}) async {
    if (hskLevel == null) return passages;
    return passages.where((p) => p.hskLevel == hskLevel).toList();
  }

  @override
  Future<ReadingPassage?> getPassageById(String id) async {
    try {
      return passages.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ReadingProgress?> getProgress(String passageId) async {
    return progressMap[passageId];
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
    progressMap[passageId] = ReadingProgress(
      id: 'prog_$passageId',
      passageId: passageId,
      isCompleted: isCompleted,
      score: score,
      answers: answers,
      readingTimeSeconds: readingTimeSeconds,
      updatedAt: DateTime.now(),
      lastScrollOffset: lastScrollOffset,
    );
  }

  @override
  Future<String> askAiAboutPassage({
    required String passageText,
    required String userQuestion,
    CancelToken? cancelToken,
  }) async {
    return 'Phản hồi từ AI Tutor: Giải thích ngữ pháp "$userQuestion" trong văn cảnh bài đọc.';
  }
}

/// Fake DictionaryRepository for offline tap-to-lookup tests.
class FakeDictionaryRepository implements DictionaryRepository {
  final Map<String, DictionaryEntry> entries;

  FakeDictionaryRepository({this.entries = const {}});

  @override
  Future<int> ensureDictionarySeedLoaded({
    String? assetPath,
    AssetBundle? bundle,
    String? filePath,
    String? jsonString,
    void Function(int processed, int total)? onProgress,
  }) async {
    return entries.length;
  }

  @override
  Future<DictionaryEntry?> getWordByExactHanzi(String hanzi) async {
    return entries[hanzi];
  }

  @override
  Future<List<DictionaryEntry>> search(String query, {int limit = 30}) async {
    final res = entries.values.where((e) => e.simplified.contains(query)).take(limit).toList();
    return res;
  }

  @override
  Future<DictionaryEntry?> getWordById(String id) async => null;

  @override
  Future<bool> toggleSaveWord(DictionaryEntry entry, {String? customNote}) async => true;

  @override
  Future<void> updateWordNote(String vocabularyId, String? note) async {}

  @override
  Future<List<UserSavedWord>> getSavedWords() async => [];

  @override
  Future<List<DictionaryHistoryItem>> getRecentSearches({int limit = 20}) async => [];

  @override
  Future<void> clearSearchHistory() async {}

  @override
  Future<String> explainWordWithAi(String word, {String? contextSentence}) async => 'Giải thích AI cho từ $word';

  @override
  Database? get database => null;
}

void main() {
  final samplePassage1 = ReadingPassage(
    id: 'RDG_01',
    hskLevel: 1,
    topic: 'Đời sống',
    titleCn: '我的朋友',
    translationVi: 'Người bạn của tôi',
    contentCn: '我有一个好朋友，他叫李明。他是中国人。',
    pinyin: 'Wǒ yǒu yí gè hǎo péngyou, tā jiào Lǐ Míng. Tā shì Zhōngguó rén.',
    audioUri: 'https://cdn.example.com/audio/hsk1_friend.mp3',
    questions: const [
      ReadingQuestion(
        id: 'q1',
        type: ReadingQuestionType.singleChoice,
        question: '李明是哪国人？',
        options: ['中国人', '美国人', '英国人'],
        answerIndex: 0,
        explanationVi: 'Trong bài có câu "他是中国人", chứng minh Lý Minh là người Trung Quốc.',
        citationText: '他是中国人。',
      ),
    ],
  );

  final samplePassage2 = ReadingPassage(
    id: 'RDG_02',
    hskLevel: 2,
    topic: 'Du lịch',
    titleCn: '去北京旅游',
    translationVi: 'Đi du lịch Bắc Kinh',
    contentCn: '去年秋天，我和家人一起去北京旅游。',
    pinyin: 'Qùnián qiūtiān, wǒ hé jiārén yìqǐ qù Běijīng lǚyóu.',
    audioUri: null,
    questions: const [],
  );

  final samplePassage3 = ReadingPassage(
    id: 'RDG_03',
    hskLevel: 4,
    topic: 'Văn hóa',
    titleCn: '中秋节的传说',
    translationVi: 'Truyền thuyết Tết Trung Thu',
    contentCn: '中秋节是中国传统节日之一，人们在这一天赏月、吃月饼。',
    pinyin: 'Zhōngqiūjié shì Zhōngguó chuántǒng jiérì zhīyī...',
    audioUri: 'https://cdn.example.com/audio/mid_autumn.mp3',
    questions: const [],
  );

  group('Task 4.1 Acceptance: ReadingPassageListScreen (Graded Reader UI & Multi-topic Filter)', () {
    testWidgets('Displays segmented tabs, modern passage card, word count, estimated minutes, and badges', (tester) async {
      final fakeRepo = FakeReadingRepository(
        passages: [samplePassage1, samplePassage2, samplePassage3],
        progress: {
          'RDG_01': ReadingProgress(
            id: 'p1',
            passageId: 'RDG_01',
            isCompleted: true,
            score: 100,
            answers: const {'q1': 0},
            readingTimeSeconds: 120,
            updatedAt: DateTime.now(),
          ),
          'RDG_02': ReadingProgress(
            id: 'p2',
            passageId: 'RDG_02',
            isCompleted: false,
            score: null,
            answers: const {},
            readingTimeSeconds: 45,
            updatedAt: DateTime.now(),
            lastScrollOffset: 150.0,
          ),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReadingPassageListScreen(repository: fakeRepo),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Level filter row
      expect(find.widgetWithText(FilterChip, 'Tất cả'), findsWidgets);
      expect(find.widgetWithText(FilterChip, 'HSK 1'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'HSK 2'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'HSK 3'), findsOneWidget);
      expect(find.widgetWithText(FilterChip, 'HSK 4+'), findsOneWidget);

      // 2. Verify Topic filter chips (ActionChip)
      expect(find.widgetWithText(ActionChip, 'Đời sống'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Du lịch'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Văn hóa'), findsOneWidget);

      // 3. Verify Passage Cards render bilingual titles
      expect(find.text('我的朋友'), findsOneWidget);
      expect(find.text('Người bạn của tôi'), findsOneWidget);
      expect(find.text('去北京旅游'), findsOneWidget);
      expect(find.text('Đi du lịch Bắc Kinh'), findsOneWidget);

      // 4. Verify Badges: word count & estimated minutes
      expect(find.text('${samplePassage1.wordCount} chữ Hán'), findsOneWidget);
      expect(find.text('${samplePassage1.estimatedMinutes} phút'), findsWidgets);

      // 5. Verify Progress indicators
      expect(find.textContaining('Đã đọc xong'), findsOneWidget); // For RDG_01
      expect(find.byType(LinearProgressIndicator), findsOneWidget); // For RDG_02

      // 6. Verify Direct Audio Play button for passages with audio
      expect(find.text('Nghe bài đọc'), findsWidgets);
    });

    testWidgets('Filters passages accurately when tapping Level and Topic tabs', (tester) async {
      final fakeRepo = FakeReadingRepository(
        passages: [samplePassage1, samplePassage2, samplePassage3],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReadingPassageListScreen(repository: fakeRepo),
        ),
      );
      await tester.pumpAndSettle();

      // All 3 passages visible initially
      expect(find.text('我的朋友'), findsOneWidget);
      expect(find.text('去北京旅游'), findsOneWidget);
      expect(find.text('中秋节的传说'), findsOneWidget);

      // Tap 'HSK 1'
      await tester.tap(find.widgetWithText(FilterChip, 'HSK 1'));
      await tester.pumpAndSettle();

      expect(find.text('我的朋友'), findsOneWidget);
      expect(find.text('去北京旅游'), findsNothing);
      expect(find.text('中秋节的传说'), findsNothing);

      // Tap 'Tất cả' in Level row to reset
      await tester.tap(find.widgetWithText(FilterChip, 'Tất cả').first);
      await tester.pumpAndSettle();

      // Filter by Topic 'Văn hóa'
      await tester.tap(find.widgetWithText(ActionChip, 'Văn hóa'));
      await tester.pumpAndSettle();

      expect(find.text('我的朋友'), findsNothing);
      expect(find.text('去北京旅游'), findsNothing);
      expect(find.text('中秋节的传说'), findsOneWidget);
    });

    testWidgets('Audio button triggers playback service', (tester) async {
      final fakeAudio = FakeAudioPlayerService();
      final fakeRepo = FakeReadingRepository(
        passages: [samplePassage1],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReadingPassageListScreen(
            repository: fakeRepo,
            audioPlayer: fakeAudio,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Nghe bài đọc'
      await tester.tap(find.text('Nghe bài đọc'));
      await tester.pumpAndSettle();

      expect(fakeAudio.playCalls, equals(1));
      expect(fakeAudio.lastPlayedUri, equals(samplePassage1.audioUri));
    });
  });

  group('Task 4.2 Acceptance: ReadingDetailScreen (4 Modes, Slow Audio Player, Tap-to-Lookup)', () {
    testWidgets('Switches smoothly between 4 reading modes', (tester) async {
      final fakeRepo = FakeReadingRepository(passages: [samplePassage1]);
      final fakeAudio = FakeAudioPlayerService();
      final fakeDict = FakeDictionaryRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: ReadingDetailScreen(
            passage: samplePassage1,
            repository: fakeRepo,
            dictionaryRepository: fakeDict,
            audioPlayer: fakeAudio,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mode 1: 'Đầy đủ' (Default) - Shows RubyText with Pinyin enabled and translation
      expect(find.text('Đầy đủ'), findsOneWidget);
      expect(find.byType(RubyText), findsOneWidget);
      expect(tester.widget<RubyText>(find.byType(RubyText)).showPinyin, isTrue);
      expect(find.text(samplePassage1.translationVi), findsOneWidget);

      // Mode 2: Switch to 'Chữ + Pinyin' - Pinyin enabled, translation is hidden
      await tester.tap(find.text('Chữ + Pinyin'));
      await tester.pumpAndSettle();
      expect(tester.widget<RubyText>(find.byType(RubyText)).showPinyin, isTrue);
      expect(find.text(samplePassage1.translationVi), findsNothing);

      // Mode 3: Switch to 'Chỉ Chữ Hán' - Pinyin disabled, translation hidden
      await tester.tap(find.text('Chỉ Chữ Hán'));
      await tester.pumpAndSettle();
      expect(tester.widget<RubyText>(find.byType(RubyText)).showPinyin, isFalse);
      expect(find.text(samplePassage1.translationVi), findsNothing);

      // Mode 4: Switch to 'Luyện dịch' - Pinyin disabled, translation shown
      await tester.tap(find.text('Luyện dịch'));
      await tester.pumpAndSettle();
      expect(tester.widget<RubyText>(find.byType(RubyText)).showPinyin, isFalse);
      expect(find.text(samplePassage1.translationVi), findsOneWidget);
    });

    testWidgets('Audio Player Bar allows play, pause, rewind 5s, and 0.75x speed toggle', (tester) async {
      final fakeRepo = FakeReadingRepository(passages: [samplePassage1]);
      final fakeAudio = FakeAudioPlayerService();
      final fakeDict = FakeDictionaryRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: ReadingDetailScreen(
            passage: samplePassage1,
            repository: fakeRepo,
            dictionaryRepository: fakeDict,
            audioPlayer: fakeAudio,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Verify Audio bar exists with rewind, play, and speed button
      expect(find.byIcon(Icons.replay_5_rounded), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_filled_rounded), findsOneWidget);
      expect(find.text('1.0x'), findsOneWidget);

      // 2. Tap Play button
      await tester.tap(find.byIcon(Icons.play_circle_filled_rounded));
      await tester.pumpAndSettle();
      expect(fakeAudio.playCalls, equals(1));

      // 3. Tap Rewind 5s button
      await tester.tap(find.byIcon(Icons.replay_5_rounded));
      await tester.pumpAndSettle();
      expect(fakeAudio.lastSeekPosition, isNotNull);

      // 4. Tap Speed button (1.0x -> 0.75x)
      await tester.tap(find.text('1.0x'));
      await tester.pumpAndSettle();
      expect(fakeAudio.playbackSpeed, equals(0.75));
      expect(find.text('0.75x'), findsOneWidget);

      // 5. Tap Speed button again (0.75x -> 1.0x)
      await tester.tap(find.text('0.75x'));
      await tester.pumpAndSettle();
      expect(fakeAudio.playbackSpeed, equals(1.0));
      expect(find.text('1.0x'), findsOneWidget);
    });

    testWidgets('Tap-to-Lookup opens dictionary detail without crashing', (tester) async {
      final fakeRepo = FakeReadingRepository(passages: [samplePassage1]);
      final fakeAudio = FakeAudioPlayerService();
      final fakeDict = FakeDictionaryRepository(
        entries: {
          '李': const DictionaryEntry(
            id: 'VOCAB_LI',
            simplified: '李',
            pinyin: 'lǐ',
            hskLevel: 1,
            senses: [
              DictionarySense(
                id: 's1',
                partOfSpeech: 'Danh từ',
                meaningVi: 'Họ Lý, quả mận',
              ),
            ],
            examples: [],
          ),
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ReadingDetailScreen(
            passage: samplePassage1,
            repository: fakeRepo,
            dictionaryRepository: fakeDict,
            audioPlayer: fakeAudio,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on word segment in RubyText
      await tester.tap(find.text('李'));
      await tester.pumpAndSettle();

      // Verify Dictionary detail is shown
      expect(find.text('Họ Lý, quả mận'), findsOneWidget);
    });
  });

  group('Task 4.3 Acceptance: ReadingQuestionsSection (Instant Grading & C3 Explanation)', () {
    testWidgets('Instant grading on tap: correct answer shows green container with checkmark', (tester) async {
      final questions = [
        const ReadingQuestion(
          id: 'q1',
          type: ReadingQuestionType.singleChoice,
          question: '李明是哪国人？',
          options: ['中国人', '美国人', '英国人'],
          answerIndex: 0,
          explanationVi: 'Trong bài có câu "他是中国人", chứng minh Lý Minh là người Trung Quốc.',
          citationText: '他是中国人。',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReadingQuestionsSection(
                questions: questions,
                onSubmitted: (ans, score) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap option '中国人' (Correct answer, index 0)
      await tester.tap(find.text('中国人'));
      await tester.pumpAndSettle();

      // Verify checkmark icon is displayed for correct answer (both in option and explanation box)
      expect(find.byIcon(Icons.check_circle_rounded), findsAtLeastNWidgets(1));

      // Verify Explanation box appears with citation highlighted
      expect(find.text('Trích dẫn: "他是中国人。"'), findsOneWidget);
      expect(find.text('Trong bài có câu "他是中国人", chứng minh Lý Minh là người Trung Quốc.'), findsOneWidget);

      // Verify AI Tutor action button exists
      expect(find.text('Hỏi AI Tutor về câu này'), findsOneWidget);
    });

    testWidgets('Instant grading on tap: incorrect answer shows red with cross icon and highlights correct answer', (tester) async {
      final questions = [
        const ReadingQuestion(
          id: 'q1',
          type: ReadingQuestionType.singleChoice,
          question: '李明是哪国人？',
          options: ['中国人', '美国人', '英国人'],
          answerIndex: 0,
          explanationVi: 'Trong bài có câu "他是中国人", chứng minh Lý Minh là người Trung Quốc.',
          citationText: '他是中国人。',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReadingQuestionsSection(
                questions: questions,
                onSubmitted: (ans, score) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap option '美国人' (Incorrect answer, index 1)
      await tester.tap(find.text('美国人'));
      await tester.pumpAndSettle();

      // Verify cancel/cross icon is displayed for wrong answer
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);

      // Verify check icon is displayed for the correct answer to guide the learner
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      // Verify Explanation box is revealed immediately
      expect(find.text('Trích dẫn: "他是中国人。"'), findsOneWidget);
      expect(find.text('Trong bài có câu "他是中国人", chứng minh Lý Minh là người Trung Quốc.'), findsOneWidget);
    });

    testWidgets('Tapping "Hỏi AI Tutor về câu này" opens the AI Explanation Dialog', (tester) async {
      final questions = [
        const ReadingQuestion(
          id: 'q1',
          type: ReadingQuestionType.singleChoice,
          question: '李明是哪国人？',
          options: ['中国人', '美国人'],
          answerIndex: 0,
          explanationVi: 'Trong bài có câu "他是中国人".',
          citationText: '他是中国人。',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ReadingQuestionsSection(
                questions: questions,
                onSubmitted: (ans, score) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap an answer to reveal explanation and AI Tutor button
      await tester.tap(find.text('中国人'));
      await tester.pumpAndSettle();

      // Tap 'Hỏi AI Tutor về câu này'
      await tester.tap(find.text('Hỏi AI Tutor về câu này'));
      await tester.pumpAndSettle();

      // Verify dialog appears
      expect(find.text('Trợ Lý AI Đọc Hiểu'), findsOneWidget);
      expect(find.text('Đã hiểu'), findsOneWidget);
    });
  });
}
