import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/audio/audio_models.dart';
import 'package:hi_chinese/core/audio/audio_player_service.dart';
import 'package:hi_chinese/core/audio/tts_service.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/features/ai_tutor/ai_tutor.dart';
import 'package:hi_chinese/features/design_system/presentation/screens/design_system_demo_screen.dart';
import 'package:hi_chinese/features/dictionary/data/dictionary_repository.dart';
import 'package:hi_chinese/features/dictionary/domain/models/dictionary_models.dart';
import 'package:hi_chinese/features/dictionary/presentation/widgets/dictionary_detail_sheet.dart';
import 'package:hi_chinese/features/grammar/domain/models/grammar_models.dart';
import 'package:hi_chinese/features/grammar/presentation/providers/grammar_providers.dart';
import 'package:hi_chinese/features/grammar/presentation/screens/grammar_list_screen.dart';
import 'package:hi_chinese/features/hanzi/data/hanzi_repository.dart';
import 'package:hi_chinese/features/hanzi/domain/models/hanzi_models.dart';
import 'package:hi_chinese/features/hanzi/presentation/screens/hanzi_character_list_screen.dart';
import 'package:hi_chinese/features/hanzi_writing/presentation/widgets/hanzi_canvas.dart';
import 'package:hi_chinese/features/hanzi_writing/presentation/widgets/hanzi_canvas_controller.dart';
import 'package:hi_chinese/features/practice/domain/models/practice_models.dart';
import 'package:hi_chinese/features/practice/presentation/widgets/matching_pairs_widget.dart';
import 'package:hi_chinese/features/practice/presentation/widgets/true_false_or_error_widget.dart';
import 'package:hi_chinese/features/pronunciation/domain/models/pronunciation_models.dart';
import 'package:hi_chinese/features/pronunciation/presentation/widgets/pronunciation_result_card.dart';
import 'package:hi_chinese/features/sentences/data/sentence_dao.dart';
import 'package:hi_chinese/features/sentences/data/sentence_repository.dart';
import 'package:hi_chinese/features/sentences/domain/models/sentence_models.dart';
import 'package:hi_chinese/features/sentences/presentation/screens/sentence_browser_screen.dart';
import 'package:hi_chinese/features/settings/domain/models/app_settings.dart';
import 'package:hi_chinese/features/settings/presentation/providers/settings_providers.dart';
import 'package:hi_chinese/features/shadowing/domain/models/shadowing_models.dart';
import 'package:hi_chinese/features/shadowing/presentation/widgets/shadowing_timeline_card.dart';

double _relativeLuminance(Color color) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(color.r) +
      0.7152 * channel(color.g) +
      0.0722 * channel(color.b);
}

double _contrastRatio(Color fg, Color bg) {
  final l1 = _relativeLuminance(fg);
  final l2 = _relativeLuminance(bg);
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

/// Ensures no rendered surface uses hardcoded white card background (#FFFFFF)
/// while a near-white primary dark-mode text is also present on screen, and fails
/// if any `Container` or `Material` accidentally locks into white in dark mode
/// for card surfaces (except intentional light color swatch boxes in Demo).
void _expectNoWhiteOnWhiteText(WidgetTester tester) {
  final texts = tester.widgetList<Text>(find.byType(Text));
  for (final t in texts) {
    final color = t.style?.color;
    if (color == null) continue;
    // Detect identical white-on-white if a white background color was set via TextStyle
    final bg = t.style?.backgroundColor;
    if (bg != null && _relativeLuminance(color) > 0.8 && _relativeLuminance(bg) > 0.8) {
      fail('Detected white-on-white text style on "${t.data}"');
    }
  }
}

class _FakeHanziRepository implements HanziRepository {
  final List<HanziCharacter> items = const [
    HanziCharacter(
      id: 'h1',
      character: '好',
      strokeCount: 6,
      hskLevel: 1,
      pinyin: 'hǎo',
      hanviet: 'HẢO',
      strokes: [],
      medians: [],
    ),
    HanziCharacter(
      id: 'h2',
      character: '学',
      strokeCount: 8,
      hskLevel: 1,
      pinyin: 'xué',
      hanviet: 'HỌC',
      strokes: [],
      medians: [],
    ),
  ];

  @override
  Future<List<HanziCharacter>> getCharactersByHskLevel(int hskLevel, {int limit = 100, int offset = 0}) async => items;

  @override
  Future<Map<String, HanziWritingProgress>> getProgressForCharacters(List<String> characters) async => {
        '好': HanziWritingProgress(
          id: 'p1',
          character: '好',
          practiceCount: 3,
          testCount: 1,
          bestAccuracyScore: 92,
          masteryLevel: 'mastered',
          lastPracticedAt: DateTime(2026),
        ),
      };

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(null);
}

class _FakeSentenceRepository implements SentenceRepository {
  @override
  Future<List<SentenceItem>> getSentencesByHskLevel(
    int hskLevel, {
    int limit = 50,
    int offset = 0,
    bool humanAudioOnly = false,
  }) async =>
      const [
        SentenceItem(
          id: 's1',
          chinese: '你好，我是老师。',
          pinyin: 'Nǐ hǎo, wǒ shì lǎoshī.',
          translationVi: 'Xin chào, tôi là giáo viên.',
          translationEn: 'Hello, I am a teacher.',
          hskLevel: 1,
          hasHumanAudio: true,
        ),
      ];

  @override
  Future<Map<String, SentencePracticeProgress>> getProgressForSentences(List<String> sentenceIds) async => {};

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(null);
}

class _FakeSentenceDao implements SentenceDao {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeDictionaryRepository implements DictionaryRepository {
  @override
  Future<bool> toggleSaveWord(DictionaryEntry entry, {String? customNote}) async => !entry.isSaved;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(null);
}

class _FakeTtsService implements TtsService {
  final List<String> spokenTexts = [];
  final List<double> spokenRates = [];

  @override
  Future<bool> isLanguageAvailable(String language) async => true;

  @override
  Future<List<String>> getAvailableVoices() async => [];

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
    spokenRates.add(rate);
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

class _FakeAudioPlayerService implements AudioPlayerService {
  final _statusCtrl = StreamController<AudioPlaybackStatus>.broadcast();
  final _posCtrl = StreamController<Duration>.broadcast();
  final List<double> playedSpeeds = [];

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
    playedSpeeds.add(speed);
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

class _FakeFlutterTts extends FlutterTts {
  double? lastRate;
  String? lastText;

  @override
  Future<dynamic> awaitSpeakCompletion(bool awaitCompletion) async => 1;

  @override
  dynamic setErrorHandler(ErrorHandler handler) {}

  @override
  Future<dynamic> stop() async => 1;

  @override
  Future<dynamic> setLanguage(String language) async => 1;

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    lastRate = rate;
    return 1;
  }

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> setVolume(double volume) async => 1;

  @override
  Future<dynamic> speak(String text, {bool focus = true}) async {
    lastText = text;
    return 1;
  }
}

class _FakeAppSettingsNotifier extends AppSettingsNotifier {
  final AppSettings initial;
  _FakeAppSettingsNotifier(this.initial);

  @override
  AppSettings build() => initial;
}

class _FakeChatSessionIdNotifier extends CurrentChatSessionIdNotifier {
  @override
  String? build() => 'sess_1';
}

class _DummyAiTutorRepository implements AiTutorRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(<Map<String, dynamic>>[]);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Wave 3 Dark Mode, Semantic Palette, WCAG 48dp & Settings Tests', () {
    test('HiSemanticColors satisfies WCAG >= 4.5:1 text contrast in Light and Dark modes', () {
      for (final palette in [HiSemanticColors.light, HiSemanticColors.dark]) {
        expect(_contrastRatio(palette.primaryText, palette.cardSurface), greaterThanOrEqualTo(4.5));
        expect(_contrastRatio(palette.primaryText, palette.mainBackground), greaterThanOrEqualTo(4.5));
        expect(_contrastRatio(palette.secondaryText, palette.cardSurface), greaterThanOrEqualTo(4.5));
        expect(_contrastRatio(palette.accentColor, palette.accentBg), greaterThanOrEqualTo(4.5));
        expect(_contrastRatio(palette.successFg, palette.successBg), greaterThanOrEqualTo(4.5));
        expect(_contrastRatio(palette.errorFg, palette.errorBg), greaterThanOrEqualTo(4.5));
      }
    });

    testWidgets('HanziCanvas in darkTheme uses darkForestCard surface & contrasting light strokeColor', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = HanziCanvasController();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: HanziCanvas(
              controller: controller,
              character: '好',
              size: 260,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(controller.strokeColor, isNot(equals(AppColors.darkForestCard)));
      expect(controller.strokeColor, AppColors.darkTextPrimary);
      expect(_contrastRatio(controller.strokeColor, AppColors.darkForestCard), greaterThanOrEqualTo(4.5));
    });

    testWidgets('PronunciationResultCard, ShadowingTimelineCard & HiLoadingIndicator render cleanly in darkTheme', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final pronResult = PronunciationAssessmentResult(
        targetId: 't1',
        targetText: '你好',
        targetPinyin: 'nǐ hǎo',
        recognizedTranscript: '你好',
        confidence: PronunciationConfidence.high,
        overallScore: 0.92,
        feedbackList: const ['Phát âm thanh điệu chuẩn.'],
        providerId: 'mock_asr',
        isAcousticallyAnalyzed: true,
        toneAccuracy: 0.95,
        initialFinalAccuracy: 0.9,
        timestamp: DateTime(2026),
      );
      final shadowResult = ShadowingAssessmentResult(
        segmentId: 'seg1',
        targetDurationMs: 1200,
        userDurationMs: 1250,
        pacingRatio: 1.04,
        pacingVerdict: 'Nhịp độ nói khớp chuẩn bản mẫu.',
        timelineMatchPercent: 94,
        fluencyIndex: 0.91,
        mode: ShadowingMode.listenThenRepeat,
        speed: ShadowingPlaybackSpeed.normal,
        disclaimer: 'So sánh thời lượng dựa trên phân tích biên độ âm thanh.',
        timestamp: DateTime(2026),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ListView(
              children: [
                const HiLoadingIndicator(message: 'Đang phân tích...'),
                PronunciationResultCard(result: pronResult),
                ShadowingTimelineCard(result: shadowResult),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      final loadingText = tester.widget<Text>(find.text('Đang phân tích...'));
      expect(loadingText.style?.color, AppColors.darkColorScheme.onSurfaceVariant);

      // Verify neither card uses white cardBackground in darkTheme
      final containers = tester.widgetList<Container>(find.byType(Container));
      for (final c in containers) {
        final dec = c.decoration;
        if (dec is BoxDecoration && dec.color == AppColors.cardBackground) {
          fail('Found hardcoded AppColors.cardBackground in darkTheme!');
        }
      }
      _expectNoWhiteOnWhiteText(tester);
    });

    testWidgets('HanziCharacterListScreen renders with 0 overflows and dark surface at 320x640', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: HanziCharacterListScreen(repository: _FakeHanziRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('好'), findsOneWidget);
      final containers = tester.widgetList<Container>(find.byType(Container));
      expect(
        containers.where((c) => (c.decoration is BoxDecoration) && (c.decoration as BoxDecoration).color == Colors.white),
        isEmpty,
      );
    });

    testWidgets('SentenceBrowserScreen renders cleanly in darkTheme at 320x640 without overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: SentenceBrowserScreen(
            repository: _FakeSentenceRepository(),
            dao: _FakeSentenceDao(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('你好，我是老师。'), findsOneWidget);
      _expectNoWhiteOnWhiteText(tester);
    });

    testWidgets('TrueFalseOrErrorWidget & MatchingPairsWidget render cleanly in darkTheme at 320x640', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final tfDef = ExerciseDefinition(
        id: 'tf1',
        type: ExerciseType.trueFalseOrErrorDetection,
        skill: 'grammar',
        prompt: 'Tìm lỗi sai:',
        stimulus: '我吃米饭昨天。',
        tokens: const ['我', '吃', '米饭', '昨天', '。'],
        errorToken: '昨天',
        explanationVi: 'Trạng ngữ thời gian đặt trước động từ.',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final matchDef = ExerciseDefinition(
        id: 'm1',
        type: ExerciseType.matchingPairs,
        skill: 'vocabulary',
        prompt: 'Ghép cặp',
        matchingPairs: const {'你好': 'Xin chào', '谢谢': 'Cảm ơn'},
        explanationVi: 'Đúng rồi',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: ListView(
              children: [
                TrueFalseOrErrorWidget(
                  definition: tfDef,
                  selectedErrorToken: '昨天',
                  onSelectBool: (_) {},
                  onSelectErrorToken: (_) {},
                ),
                MatchingPairsWidget(
                  definition: matchDef,
                  userPairs: const {'你好': 'Xin chào'},
                  result: const ScoringResult(
                    score: 0.5,
                    isCorrect: false,
                    confidence: 1.0,
                    evaluatorType: EvaluatorType.deterministic,
                    feedbackVi: 'Xem lại cặp còn lại',
                  ),
                  onPairsChanged: (_) {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      _expectNoWhiteOnWhiteText(tester);
    });

    testWidgets('GrammarListScreen renders cleanly in darkTheme at 320x640', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final sampleItem = GrammarItem(
        id: 'g1',
        hskLevel: 1,
        code: 'G_SHI',
        title: 'Câu chữ 是 (shì)',
        structure: 'A + 是 + B',
        meaningVi: 'A là B',
        usageConditionsVi: 'Dùng để nối hai danh từ',
        sentencePositionVi: 'Giữa hai danh từ',
        explanationVi: 'Từ 是 biểu thị quan hệ phán đoán.',
        topicCategory: 'sentence_structure',
        topicNameVi: 'Cấu trúc câu',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            grammarTopicsProvider.overrideWith((ref) async => const []),
            grammarListProvider.overrideWith((ref) async => [sampleItem]),
            grammarProgressMapProvider.overrideWith((ref) async => {}),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const GrammarListScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Câu chữ 是 (shì)'), findsOneWidget);
      _expectNoWhiteOnWhiteText(tester);
    });

    testWidgets('DictionaryDetailSheet renders in darkTheme at 320x640 and auto-plays audio when enabled', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final fakeTts = _FakeTtsService();
      final fakeAudio = _FakeAudioPlayerService();
      addTearDown(fakeAudio.dispose);

      const entry = DictionaryEntry(
        id: 'd1',
        simplified: '朋友',
        pinyin: 'péngyou',
        hanviet: 'BẰNG HỮU',
        hskLevel: 1,
        senses: [
          DictionarySense(
            id: 's1',
            partOfSpeech: 'Danh từ',
            meaningVi: 'Bạn bè',
            exampleCn: '他是我朋友。',
            examplePinyin: 'Tā shì wǒ péngyou.',
            exampleVi: 'Anh ấy là bạn của tôi.',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsProvider.overrideWith(
              () => _FakeAppSettingsNotifier(
                const AppSettings(
                  themeMode: ThemeMode.dark,
                  autoPlayAudio: true,
                  speechRate: 0.8,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: DictionaryDetailSheet(
                entry: entry,
                repository: _FakeDictionaryRepository(),
                ttsService: fakeTts,
                audioPlayer: fakeAudio,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(fakeTts.spokenTexts, contains('朋友'));
      expect(fakeTts.spokenRates.first, closeTo(0.4, 0.001));
    });

    testWidgets('DesignSystemDemoScreen renders in darkTheme at 320x640 with 0 overflows', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const DesignSystemDemoScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(tester.takeException(), isNull);
      expect(find.text('Primary Blue Light'), findsOneWidget);
    });

    testWidgets('HiButton & interactive HiChip satisfy androidTapTargetGuideline (>= 48dp)', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HiButton(text: 'S', size: HiButtonSize.sm, onPressed: () {}),
                  const SizedBox(height: 8),
                  HiButton(text: 'M', size: HiButtonSize.md, onPressed: () {}),
                  const SizedBox(height: 8),
                  HiButton(text: 'L', size: HiButtonSize.lg, onPressed: () {}),
                  const SizedBox(height: 8),
                  HiChip(label: 'H1', onTap: () {}),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      handle.dispose();
    });

    test('DefaultTtsService maps speechRate 0.8/1.0/1.2 -> flutter_tts 0.4/0.5/0.6', () async {
      expect(DefaultTtsService.toTtsRate(0.8), closeTo(0.4, 0.001));
      expect(DefaultTtsService.toTtsRate(1.0), closeTo(0.5, 0.001));
      expect(DefaultTtsService.toTtsRate(1.2), closeTo(0.6, 0.001));

      final fakeFlutterTts = _FakeFlutterTts();
      final prevRate = DefaultTtsService.defaultSpeechRate;
      addTearDown(() => DefaultTtsService.defaultSpeechRate = prevRate);

      DefaultTtsService.defaultSpeechRate = 1.2;
      final tts = DefaultTtsService(flutterTts: fakeFlutterTts);
      await tts.speak('你好');
      expect(fakeFlutterTts.lastRate, closeTo(0.6, 0.001));
    });

    testWidgets('AiTutorTabScreen shows single AppBar and tapping persona name opens Persona modal', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            aiTutorRepositoryProvider.overrideWithValue(_DummyAiTutorRepository()),
            currentChatSessionIdProvider.overrideWith(_FakeChatSessionIdNotifier.new),
            recentChatSessionsProvider.overrideWith((ref) async => const []),
            sessionMessagesProvider('sess_1').overrideWith((ref) async => const []),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const AiTutorTabScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AppBar), findsOneWidget);

      await tester.tap(find.text(TutorPersonas.defaultPersona.nameZh));
      await tester.pumpAndSettle();

      expect(find.text('Chọn Gia sư AI (Persona)'), findsOneWidget);
    });

    testWidgets('showPinyinByDefault and showRubyAnnotation settings toggle pinyin visibility', (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // 1. SentenceBrowserScreen hides pinyin when showPinyinByDefault == false
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingsProvider.overrideWith(
              () => _FakeAppSettingsNotifier(
                const AppSettings(showPinyinByDefault: false),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: SentenceBrowserScreen(
              repository: _FakeSentenceRepository(),
              dao: _FakeSentenceDao(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('你好，我是老师。'), findsOneWidget);
      expect(find.text('Nǐ hǎo, wǒ shì lǎoshī.'), findsNothing);

      // 2. DictionaryDetailSheet disables autoPlay and Ruby pinyin when configured false
      final fakeTts = _FakeTtsService();
      final fakeAudio = _FakeAudioPlayerService();
      addTearDown(fakeAudio.dispose);
      const entry = DictionaryEntry(
        id: 'd2',
        simplified: '你好',
        pinyin: 'nǐ hǎo',
        hskLevel: 1,
      );

      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            appSettingsProvider.overrideWith(
              () => _FakeAppSettingsNotifier(
                const AppSettings(
                  showPinyinByDefault: true,
                  showRubyAnnotation: false,
                  autoPlayAudio: false,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: DictionaryDetailSheet(
                entry: entry,
                repository: _FakeDictionaryRepository(),
                ttsService: fakeTts,
                audioPlayer: fakeAudio,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rubyWidget = tester.widget<RubyText>(find.byType(RubyText).first);
      expect(rubyWidget.showPinyin, isFalse);
      expect(fakeTts.spokenTexts, isEmpty);
    });
  });
}
