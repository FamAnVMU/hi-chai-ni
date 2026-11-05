import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/sentences/data/audio_pack_manager.dart';
import 'package:hi_chinese/features/sentences/data/sentence_dao.dart';
import 'package:hi_chinese/features/sentences/data/sentence_repository.dart';
import 'package:hi_chinese/features/sentences/domain/models/sentence_models.dart';
import 'package:hi_chinese/features/sentences/presentation/screens/audio_pack_manager_screen.dart';
import 'package:hi_chinese/features/sentences/presentation/screens/sentence_browser_screen.dart';
import 'package:hi_chinese/features/sentences/presentation/screens/sentence_listening_screen.dart';
import 'package:hi_chinese/features/sentences/presentation/screens/sentence_reading_screen.dart';
import 'package:hi_chinese/features/sentences/presentation/screens/sentence_shadowing_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FakeSentenceRepository implements SentenceRepository {
  final Map<String, SentenceItem> _sentences = {};
  final Map<String, SentencePracticeProgress> _progress = {};

  FakeSentenceRepository() {
    _sentences['tat_1'] = const SentenceItem(
      id: 'tat_1',
      chinese: '老师，您好！',
      pinyin: 'lǎo shī nín hǎo',
      translationVi: 'Chào thầy cô!',
      translationEn: 'Hello, teacher!',
      hskLevel: 1,
      hasHumanAudio: true,
      tokens: [
        SentenceToken(word: '老师', pinyin: 'lǎo shī', meaningVi: 'thầy cô', hskLevel: 1),
        SentenceToken(word: '您好', pinyin: 'nín hǎo', meaningVi: 'chào', hskLevel: 1),
      ],
      grammarTags: ['您 (polite you)'],
      audios: [
        SentenceAudio(
          id: 'audio_1',
          sentenceId: 'tat_1',
          audioType: AudioType.humanRecording,
          speakerName: 'LeviHighway',
          urlRemote: 'https://tatoeba.org/audio/download/1',
        ),
      ],
    );
  }

  @override
  Future<SentenceItem?> getSentenceById(String id) async => _sentences[id];

  @override
  Future<List<SentenceItem>> getSentencesByHskLevel(
    int hskLevel, {
    int limit = 50,
    int offset = 0,
    bool humanAudioOnly = false,
  }) async {
    return _sentences.values.where((s) {
      if (s.hskLevel != hskLevel) return false;
      if (humanAudioOnly && !s.hasHumanAudio) return false;
      return true;
    }).toList();
  }

  @override
  Future<List<SentenceItem>> searchSentences(String query, {int limit = 30}) async {
    return _sentences.values.where((s) => s.chinese.contains(query)).toList();
  }

  @override
  Future<SentencePracticeProgress?> getProgress(String sentenceId) async => _progress[sentenceId];

  @override
  Future<Map<String, SentencePracticeProgress>> getProgressForSentences(List<String> sentenceIds) async {
    final map = <String, SentencePracticeProgress>{};
    for (final id in sentenceIds) {
      if (_progress.containsKey(id)) {
        map[id] = _progress[id]!;
      }
    }
    return map;
  }

  @override
  Future<List<SentenceItem>> getSentencesByIds(List<String> sentenceIds) async {
    return _sentences.values.where((s) => sentenceIds.contains(s.id)).toList();
  }

  @override
  Future<void> recordPracticeAttempt({
    required String sentenceId,
    required String practiceType,
    required double score,
    String? recordedAudioPath,
  }) async {
    _progress[sentenceId] = SentencePracticeProgress(
      id: 'prog_$sentenceId',
      sentenceId: sentenceId,
      listeningAttempts: 1,
      lastScore: score,
    );
  }

  @override
  Future<List<SentencePracticeProgress>> getSentencesNeedingReview({int limit = 50}) async =>
      _progress.values.toList();

  @override
  Future<int> ensureSeedLoaded({String assetPath = ''}) async => _sentences.length;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Sentence UI Screens Widget Tests', () {
    late FakeSentenceRepository fakeRepo;
    late Database mockDb;
    late SentenceDao mockDao;

    setUp(() async {
      fakeRepo = FakeSentenceRepository();
      mockDb = await databaseFactory.openDatabase(inMemoryDatabasePath);
      mockDao = SentenceDao(mockDb);
    });

    tearDown(() async {
      await mockDb.close();
    });

    testWidgets('SentenceBrowserScreen renders filters, search bar and sentence cards', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SentenceBrowserScreen(
            repository: fakeRepo,
            dao: mockDao,
            initialHskLevel: 1,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Kho Câu & Luyện Nghe'), findsOneWidget);
      expect(find.text('HSK 1'), findsWidgets);
      expect(find.text('Giọng người thật'), findsOneWidget);
      expect(find.text('老师，您好！'), findsOneWidget);
      expect(find.text('Luyện nghe'), findsOneWidget);
      expect(find.text('Shadowing'), findsOneWidget);
      expect(find.text('Luyện đọc'), findsOneWidget);
    });

    testWidgets('SentenceListeningScreen displays audio badge, options and reveal buttons', (tester) async {
      final sample = await fakeRepo.getSentenceById('tat_1');

      await tester.pumpWidget(
        MaterialApp(
          home: SentenceListeningScreen(
            sentence: sample!,
            sentenceList: [sample],
            repository: fakeRepo,
            autoPlay: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Luyện nghe HSK 1'), findsOneWidget);
      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
      expect(find.text('Hiện chữ Hán'), findsOneWidget);
      expect(find.text('Chọn ý nghĩa đúng của câu bạn vừa nghe:'), findsOneWidget);
    });

    testWidgets('SentenceReadingScreen displays tokenized Hanzi and grammar tags', (tester) async {
      final sample = await fakeRepo.getSentenceById('tat_1');

      await tester.pumpWidget(
        MaterialApp(
          home: SentenceReadingScreen(
            sentence: sample!,
            repository: fakeRepo,
            minReadingDuration: Duration.zero,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Luyện đọc & Phân tích câu'), findsOneWidget);
      expect(find.text('老师'), findsWidgets);
      expect(find.text('您好'), findsWidgets);
      expect(find.text('Ngữ pháp trong câu:'), findsOneWidget);
      expect(find.text('您 (polite you)'), findsOneWidget);

      // Verify that score is NOT auto-recorded on initial screen load
      expect(await fakeRepo.getProgress('tat_1'), isNull);

      // Scroll to button and tap to complete reading
      final completeButton = find.byKey(const Key('complete_reading_button'));
      await tester.ensureVisible(completeButton);
      await tester.tap(completeButton);
      await tester.pumpAndSettle();

      expect(find.text('Đã ghi nhận hoàn thành'), findsOneWidget);
      final progress = await fakeRepo.getProgress('tat_1');
      expect(progress, isNotNull);
      expect(progress!.lastScore, 50.0);
    });

    testWidgets('SentenceShadowingScreen displays model sentence and mic button', (tester) async {
      final sample = await fakeRepo.getSentenceById('tat_1');

      await tester.pumpWidget(
        MaterialApp(
          home: SentenceShadowingScreen(
            sentence: sample!,
            repository: fakeRepo,
            autoPlay: false,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Luyện Shadowing (Nhại giọng)'), findsOneWidget);
      expect(find.text('老师，您好！'), findsOneWidget);
      expect(find.text('Nghe câu mẫu'), findsOneWidget);
      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('AudioPackManagerScreen lists HSK packs and download buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AudioPackManagerScreen(
            packManager: AudioPackManager(mockDao),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Quản lý Gói Âm Thanh'), findsOneWidget);
      expect(find.text('Gói âm thanh người thật HSK 1'), findsOneWidget);
      expect(find.text('Tải về máy'), findsWidgets);
    });
  });
}
