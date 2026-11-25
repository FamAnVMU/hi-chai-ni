import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hi_chinese/core/audio/audio.dart';
import 'package:hi_chinese/core/network/ai/ai.dart';
import 'package:hi_chinese/features/dictionary/data/dictionary_repository.dart';
import 'package:hi_chinese/features/dictionary/domain/models/dictionary_models.dart';
import 'package:hi_chinese/features/reading/data/reading_repository.dart';
import 'package:hi_chinese/features/reading/domain/models/reading_models.dart';
import 'package:hi_chinese/features/reading/presentation/screens/reading_detail_screen.dart';

class _RecordingTtsService implements TtsService {
  final List<String> spokenTexts = [];
  int stopCalls = 0;

  @override
  Future<void> speak(
    String text, {
    String language = 'zh-CN',
    double rate = 0.5,
    double pitch = 1.0,
    double volume = 1.0,
    String? voiceName,
  }) async {
    spokenTexts.add(text);
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  Future<bool> isLanguageAvailable(String language) async => true;

  @override
  Future<List<String>> getAvailableVoices() async => const [];

  @override
  void dispose() {}
}

class _NoopAudioPlayer implements AudioPlayerService {
  final _statusCtrl = StreamController<AudioPlaybackStatus>.broadcast();
  final _posCtrl = StreamController<Duration>.broadcast();

  @override
  AudioPlaybackStatus get status => AudioPlaybackStatus.idle;
  @override
  Duration get currentPosition => Duration.zero;
  @override
  Duration get totalDuration => Duration.zero;
  @override
  double get playbackSpeed => 1.0;
  @override
  bool get isLooping => false;
  @override
  Stream<AudioPlaybackStatus> get statusStream => _statusCtrl.stream;
  @override
  Stream<Duration> get positionStream => _posCtrl.stream;
  @override
  Future<void> play(String uri, {double speed = 1.0, bool loop = false, Duration? simulatedDuration}) async {
    throw const AudioPlaybackException('Missing asset');
  }
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setPlaybackSpeed(double speed) async {}
  @override
  Future<void> setLooping(bool loop) async {}
  @override
  void dispose() {
    _statusCtrl.close();
    _posCtrl.close();
  }
}

class _FailingAiReadingRepo implements ReadingRepository {
  final ReadingPassage passage;
  int completedSaves = 0;

  _FailingAiReadingRepo(this.passage);

  @override
  Future<List<ReadingPassage>> getPassages({int? hskLevel}) async => [passage];

  @override
  Future<ReadingPassage?> getPassageById(String id) async => passage;

  @override
  Future<ReadingProgress?> getProgress(String passageId) async => null;

  @override
  Future<void> saveReadingSession({
    required String passageId,
    required int readingTimeSeconds,
    required double lastScrollOffset,
    required Map<String, int> answers,
    required bool isCompleted,
    double? score,
  }) async {
    if (isCompleted) completedSaves++;
  }

  @override
  Future<String> askAiAboutPassage({
    required String passageText,
    required String userQuestion,
    CancelToken? cancelToken,
  }) async {
    throw const AiNetworkException('No internet connection');
  }
}

class _SpyDictionaryRepo implements DictionaryRepository {
  String? lastHanzi;
  String? lastPreferredPinyin;

  @override
  Future<DictionaryEntry?> getWordByExactHanzi(
    String hanzi, {
    String? preferredPinyin,
  }) async {
    lastHanzi = hanzi;
    lastPreferredPinyin = preferredPinyin;
    return DictionaryEntry(
      id: 'VOC_SPY',
      simplified: hanzi,
      pinyin: preferredPinyin ?? 'hǎo',
      hskLevel: 1,
      senses: const [
        DictionarySense(id: 's1', partOfSpeech: 'n', meaningVi: 'nghĩa thử'),
      ],
    );
  }

  @override
  Future<List<DictionaryEntry>> search(String query, {int limit = 30, bool recordHistory = false}) async => [];
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
  Future<String> explainWordWithAi(String word, {String? contextSentence}) async => '';
  @override
  Future<int> ensureDictionarySeedLoaded({
    String? assetPath,
    AssetBundle? bundle,
    String? filePath,
    String? jsonString,
    void Function(int processed, int total)? onProgress,
  }) async => 0;
  @override
  get database => null;
}

void main() {
  test('AUD-014: all 76 graded_reading_passages match 100% Hanzi-to-Pinyin syllables with unique seg IDs', () async {
    final raw = await File('assets/data/graded_reading_passages.json').readAsString();
    final list = json.decode(raw) as List<dynamic>;
    expect(list.length, equals(76));

    final hanziRegex = RegExp(r'[\u4e00-\u9fa5]');
    for (int i = 0; i < list.length; i++) {
      final map = Map<String, dynamic>.from(list[i] as Map);
      final passage = ReadingPassage.fromMap(map);
      final segments = passage.buildRubySegments();

      final hanziSegments = segments.where((s) => hanziRegex.hasMatch(s.text)).toList();
      final expectedHanziCount = hanziRegex.allMatches(passage.contentCn).length;

      expect(
        hanziSegments.length,
        equals(expectedHanziCount),
        reason: 'Passage ${passage.id} index $i Hanzi segment count mismatch',
      );
      expect(
        hanziSegments.every((s) => s.pinyin != null && s.pinyin!.trim().isNotEmpty),
        isTrue,
        reason: 'Passage ${passage.id} has blank trailing Pinyin syllable',
      );

      final ids = hanziSegments.map((s) => s.wordId).whereType<String>().toSet();
      expect(
        ids.length,
        equals(hanziSegments.length),
        reason: 'Passage ${passage.id} has duplicate segment wordIds',
      );
    }
  });

  testWidgets('AUD-015 & RISK-11 & RISK-14: no auto-submit on tap 1, TTS fallback works, AI error closes spinner',
      (tester) async {
    const passage = ReadingPassage(
      id: 'RDG_TEST_71',
      hskLevel: 1,
      titleCn: '测试',
      contentCn: '我是好人。',
      pinyin: 'Wǒ shì hǎorén.',
      translationVi: 'Tôi là người tốt.',
      audioUri: null,
      questions: [
        ReadingQuestion(
          id: 'q1',
          type: ReadingQuestionType.singleChoice,
          question: '我是谁？',
          options: ['好人', '坏人'],
          answerIndex: 0,
          explanationVi: 'Bài nói 好人.',
        ),
        ReadingQuestion(
          id: 'q2',
          type: ReadingQuestionType.trueFalse,
          question: '对吗？',
          options: ['对', '错'],
          answerIndex: 0,
          explanationVi: 'Đúng.',
        ),
      ],
    );

    final repo = _FailingAiReadingRepo(passage);
    final dictRepo = _SpyDictionaryRepo();
    final audio = _NoopAudioPlayer();
    final tts = _RecordingTtsService();
    addTearDown(audio.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: ReadingDetailScreen(
          passage: passage,
          repository: repo,
          dictionaryRepository: dictRepo,
          audioPlayer: audio,
          ttsService: tts,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 1. TTS fallback on passage without MP3 does not throw 'tts:...' error
    await tester.tap(find.byIcon(Icons.play_circle_filled_rounded));
    await tester.pumpAndSettle();
    expect(tts.spokenTexts, equals(['我是好人。']));

    // 2. Word tap passes preferredPinyin for polyphone disambiguation (RISK-11)
    await tester.tap(find.text('好'));
    await tester.pumpAndSettle();
    expect(dictRepo.lastHanzi, equals('好'));
    expect(dictRepo.lastPreferredPinyin, equals('hǎo'));
    // Close bottom sheet
    Navigator.of(tester.element(find.text('nghĩa thử'))).pop();
    await tester.pumpAndSettle();

    // 3. Tapping Question 1 option must NOT auto-submit or reveal answer
    await tester.scrollUntilVisible(
      find.text('好人'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('好人'));
    await tester.pumpAndSettle();
    expect(repo.completedSaves, equals(0));
    expect(find.text('Đáp án chính xác'), findsNothing);

    // 4. Ask AI when network fails closes barrierDismissible loading dialog & shows error SnackBar
    await tester.tap(find.text('Hỏi AI về bài đọc'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Giải thích câu đầu');
    await tester.tap(find.text('Gửi câu hỏi'));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('Không thể kết nối AI Tutor'), findsOneWidget);
  });
}
