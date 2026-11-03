import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/grammar/grammar.dart';

class FakeGrammarRepository implements GrammarRepository {
  final List<GrammarItem> items = GrammarCatalog.items;
  final Map<String, GrammarProgress> progressMap = {};

  @override
  Future<List<GrammarTopic>> getGrammarTopics() async => const [];

  @override
  Future<List<GrammarItem>> getGrammarItems({
    int? hskLevel,
    String? topicCategory,
    String? tag,
    String? query,
  }) async {
    var res = List<GrammarItem>.from(items);
    if (hskLevel != null) {
      res = res.where((i) => i.hskLevel == hskLevel).toList();
    }
    if (topicCategory != null && topicCategory.isNotEmpty) {
      res = res.where((i) => i.topicCategory == topicCategory).toList();
    }
    if (tag != null) {
      res = res.where((i) => i.tags.contains(tag)).toList();
    }
    if (query != null && query.isNotEmpty) {
      res = res.where((i) => i.title.contains(query) || i.structure.contains(query)).toList();
    }
    return res;
  }

  @override
  Future<List<GrammarExample>> getExamplesForGrammar(String grammarId) async {
    try {
      final it = items.firstWhere((i) => i.id == grammarId);
      return it.examples;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> importGrammarDataset(List<Map<String, dynamic>> rawItems) async {}

  @override
  Future<GrammarItem?> getGrammarItemById(String id) async {
    try {
      return items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<GrammarProgress?> getProgress(String grammarId) async {
    return progressMap[grammarId];
  }

  @override
  Future<Map<String, GrammarProgress>> getAllProgressMap() async {
    return progressMap;
  }

  @override
  Future<void> recordStudySession({
    required String grammarId,
    required double score,
    required int durationSeconds,
    required int exercisesCount,
  }) async {
    progressMap[grammarId] = GrammarProgress(
      id: 'p_$grammarId',
      grammarId: grammarId,
      hskLevel: 1,
      status: score >= 0.8 ? GrammarProgressStatus.mastered : GrammarProgressStatus.learning,
      masteryScore: score,
      exercisesCompleted: exercisesCount,
      lastStudiedAt: DateTime.now().toUtc(),
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
  }
}

void main() {
  late FakeGrammarRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeGrammarRepository();
  });

  Widget buildTestableWidget(Widget child) {
    return ProviderScope(
      overrides: [
        grammarRepositoryProvider.overrideWithValue(fakeRepo),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('Grammar Screens & Interactive Exercises Widget Tests', () {
    testWidgets('1. GrammarListScreen renders title, level chips, search bar, and grammar cards', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget(const GrammarListScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Ngữ Pháp Tiếng Hán'), findsOneWidget);
      expect(find.text('Tất cả HSK'), findsOneWidget);
      expect(find.text('HSK 1'), findsWidgets);
      expect(find.text('HSK 2'), findsWidgets);

      // Verify specific grammar cards are listed
      expect(find.text('Câu chữ 是 (Câu phán đoán)'), findsOneWidget);
      expect(find.text('Câu hỏi nghi vấn với trợ từ 吗 (ma)'), findsOneWidget);
    });

    testWidgets('2. GrammarDetailScreen renders 3 tabs: Structure, Examples & Mistakes, Practice', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget(
        const GrammarDetailScreen(grammarId: 'GRM_HSK1_01_SHI'),
      ));
      await tester.pumpAndSettle();

      // App bar and tabs
      expect(find.text('Câu chữ 是 (Câu phán đoán)'), findsWidgets);
      expect(find.text('Cấu trúc'), findsOneWidget);
      expect(find.text('Ví dụ & Lỗi sai'), findsOneWidget);
      expect(find.text('Luyện tập'), findsOneWidget);

      // Tab 1: Structure card
      expect(find.text('Chủ ngữ + 是 + Danh từ / Cụm danh từ'), findsOneWidget);
      expect(find.textContaining('Ý nghĩa:'), findsOneWidget);
      expect(find.textContaining('Vị trí trong câu:'), findsOneWidget);
      expect(find.textContaining('Điều kiện sử dụng:'), findsOneWidget);
    });

    testWidgets('3. Tab 2 displays standard examples and contrastive L1 transfer mistakes', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget(
        const GrammarDetailScreen(grammarId: 'GRM_HSK1_01_SHI'),
      ));
      await tester.pumpAndSettle();

      // Switch to Tab 2
      await tester.tap(find.text('Ví dụ & Lỗi sai'));
      await tester.pumpAndSettle();

      // Standard example
      expect(find.text('我是中国人。'), findsOneWidget);
      expect(find.text('Wǒ shì Zhōngguó rén.'), findsOneWidget);
      expect(find.text('Tôi là người Trung Quốc.'), findsOneWidget);

      // Contrastive example
      expect(find.text('我好。/ 我是好。'), findsOneWidget);
      expect(find.textContaining('Lỗi chuyển di từ tiếng Việt'), findsOneWidget);
    });

    testWidgets('4. Tab 3 allows answering exercises, evaluates with rubric, and records progress', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget(
        const GrammarDetailScreen(grammarId: 'GRM_HSK1_01_SHI'),
      ));
      await tester.pumpAndSettle();

      // Switch to Tab 3
      await tester.tap(find.text('Luyện tập'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Bài Tập Áp Dụng'), findsOneWidget);

      // Select option '是' in multiple choice
      final correctOption = find.text('是');
      expect(correctOption, findsWidgets);
      await tester.tap(correctOption.first);
      await tester.pumpAndSettle();

      // Tap 'Kiểm tra đáp án'
      final checkBtns = find.text('Kiểm tra đáp án');
      expect(checkBtns, findsWidgets);
      await tester.tap(checkBtns.first);
      await tester.pumpAndSettle();

      // Expect evaluation result banner
      expect(find.textContaining('Chính xác (100%)'), findsOneWidget);
      expect(find.text('Tự động đạt chuẩn'), findsOneWidget);

      // Tap 'Hoàn thành bài tập & Lưu tiến độ'
      final saveBtn = find.text('Hoàn thành bài tập & Lưu tiến độ');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verify snackbar feedback
      expect(find.textContaining('Đã lưu tiến độ!'), findsOneWidget);
    });
  });
}
