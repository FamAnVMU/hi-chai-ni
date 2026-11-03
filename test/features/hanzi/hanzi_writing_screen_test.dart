import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/hanzi/data/hanzi_repository.dart';
import 'package:hi_chinese/features/hanzi/domain/models/hanzi_models.dart';
import 'package:hi_chinese/features/hanzi/presentation/screens/hanzi_character_list_screen.dart';
import 'package:hi_chinese/features/hanzi/presentation/screens/hanzi_writing_screen.dart';

class FakeHanziRepository implements HanziRepository {
  final Map<String, HanziCharacter> _chars = {};
  final Map<String, HanziWritingProgress> _progress = {};

  FakeHanziRepository() {
    _chars['你'] = HanziCharacter(
      id: 'hanzi_4f60',
      character: '你',
      strokeCount: 7,
      hskLevel: 1,
      pinyin: 'nǐ',
      hanviet: 'nhĩ',
      meaningVi: 'bạn, anh, chị',
      definitionEn: 'you',
      radical: '人',
      decomposition: '⿰亻尔',
      strokes: [
        'M 272 567 Q 306 613 342 669 Z',
        'M 241 527 Q 262 506 258 375 Z',
      ],
      medians: [
        [const Point2D(317, 812), const Point2D(68, 367)],
        [const Point2D(273, 558), const Point2D(260, 41)],
      ],
      sampleWords: [
        const HanziSampleWord(id: 'vocab_nihao', word: '你好', pinyin: 'nǐ hǎo', meaningVi: 'xin chào'),
      ],
    );
  }

  @override
  Future<HanziCharacter?> getCharacter(String character) async => _chars[character];

  @override
  Future<HanziCharacter?> getCharacterById(String id) async =>
      _chars.values.firstWhere((c) => c.id == id);

  @override
  Future<List<HanziCharacter>> getCharactersByHskLevel(int hskLevel, {int limit = 100, int offset = 0}) async =>
      _chars.values.where((c) => c.hskLevel == hskLevel).toList();

  @override
  Future<List<HanziCharacter>> searchCharacters(String query, {int limit = 50}) async =>
      _chars.values.where((c) => c.character.contains(query) || c.pinyin.contains(query)).toList();

  @override
  Future<HanziWritingProgress?> getProgress(String character) async => _progress[character];

  @override
  Future<void> recordPracticeAttempt({
    required String character,
    required double accuracy,
    required int mistakes,
    required int strokeOrderErrors,
    required bool isTestMode,
  }) async {
    _progress[character] = HanziWritingProgress(
      id: 'progress_$character',
      character: character,
      lastAccuracyScore: accuracy,
      bestAccuracyScore: accuracy,
      practiceCount: 1,
    );
  }

  @override
  Future<List<HanziWritingProgress>> getCharactersNeedingReview({int limit = 50}) async =>
      _progress.values.toList();

  @override
  Future<List<HanziWritingProgress>> getRecentPracticed({int limit = 20}) async =>
      _progress.values.toList();

  @override
  Future<int> ensureSeedLoaded({String assetPath = ''}) async => _chars.length;
}

void main() {
  group('HanziWritingScreen & HanziCharacterListScreen Widgets', () {
    late FakeHanziRepository fakeRepo;

    setUp(() {
      fakeRepo = FakeHanziRepository();
    });

    testWidgets('HanziWritingScreen renders character glyph, pinyin, and mode tabs', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HanziWritingScreen(
            initialCharacter: '你',
            wordCharacters: const ['你', '好'],
            wordTitle: '你好',
            repository: fakeRepo,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify header contents
      expect(find.text('你'), findsWidgets);
      expect(find.text('nǐ'), findsOneWidget);
      expect(find.text('(nhĩ)'), findsOneWidget);
      expect(find.text('HSK 1'), findsOneWidget);

      // Verify mode tabs
      expect(find.text('Học viết'), findsOneWidget);
      expect(find.text('Luyện tập'), findsOneWidget);
      expect(find.text('Kiểm tra'), findsOneWidget);

      // Switch to Practice Mode
      await tester.tap(find.text('Luyện tập'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Gợi ý nét'), findsOneWidget);
      expect(find.byTooltip('Xóa nét trước'), findsOneWidget);
      expect(find.byTooltip('Viết lại từ đầu'), findsOneWidget);
    });

    testWidgets('HanziCharacterListScreen displays character card and search input', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: HanziCharacterListScreen(
            repository: fakeRepo,
            initialHskLevel: 1,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Kho chữ Hán & Luyện viết'), findsOneWidget);
      expect(find.text('HSK 1'), findsOneWidget);
      expect(find.text('你'), findsOneWidget);
      expect(find.text('nǐ'), findsOneWidget);
    });
  });
}
