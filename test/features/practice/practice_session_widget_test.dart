import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/practice/practice.dart';

class FakePracticeRepository implements PracticeRepository {
  final List<ExerciseDefinition> exercises = PracticeSeedCatalog.items.take(2).toList();
  final Map<String, PracticeSession> sessions = {};
  final List<ExerciseAttempt> attempts = [];

  @override
  Future<List<ExerciseDefinition>> getExercises({String? skill, int? hskLevel, ExerciseType? type}) async {
    return exercises;
  }

  @override
  Future<ExerciseDefinition?> getExerciseById(String id) async {
    try {
      return exercises.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveExercise(ExerciseDefinition def) async {}

  @override
  Future<PracticeSession> createSession({
    required String title,
    required String skill,
    int hskLevel = 1,
    required List<String> exerciseIds,
  }) async {
    final s = PracticeSession(
      id: 'fake_session_1',
      title: title,
      skill: skill,
      hskLevel: hskLevel,
      exerciseIds: exerciseIds,
      currentIndex: 0,
      attempts: const [],
      status: PracticeSessionStatus.inProgress,
      startedAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
    sessions[s.id] = s;
    return s;
  }

  @override
  Future<PracticeSession?> getActiveSession({String? skill}) async {
    for (final s in sessions.values) {
      if (s.status == PracticeSessionStatus.inProgress) {
        return s;
      }
    }
    return null;
  }

  @override
  Future<PracticeSession?> getSessionById(String sessionId) async {
    return sessions[sessionId];
  }

  @override
  Future<void> updateSessionProgress(String sessionId, {required int currentIndex}) async {
    final s = sessions[sessionId];
    if (s != null) {
      sessions[sessionId] = s.copyWith(currentIndex: currentIndex);
    }
  }

  @override
  Future<ExerciseAttempt> recordAttempt({
    required String sessionId,
    required ExerciseAttempt attempt,
  }) async {
    attempts.add(attempt);
    final s = sessions[sessionId];
    if (s != null) {
      sessions[sessionId] = s.copyWith(
        attempts: List.from(s.attempts)..add(attempt),
      );
    }
    return attempt;
  }

  @override
  Future<PracticeSession> completeSession({
    required String sessionId,
    required int totalDurationMs,
  }) async {
    final s = sessions[sessionId]!;
    final completed = s.copyWith(
      status: PracticeSessionStatus.completed,
      score: 1.0,
      completedAt: DateTime.now().toUtc(),
    );
    sessions[sessionId] = completed;
    return completed;
  }

  @override
  Future<List<ExerciseAttempt>> getAttemptHistory(String exerciseId) async {
    return attempts.where((a) => a.exerciseId == exerciseId).toList();
  }
}

void main() {
  late FakePracticeRepository fakeRepo;

  setUp(() {
    fakeRepo = FakePracticeRepository();
  });

  Widget buildTestableWidget(Widget child) {
    return ProviderScope(
      overrides: [
        practiceRepositoryProvider.overrideWithValue(fakeRepo),
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('PracticeSessionScreen Widget & UX Acceptance Tests', () {
    testWidgets('1. Renders session screen, title, progress, and question counter', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget(const PracticeSessionScreen(skill: 'vocabulary')));
      await tester.pumpAndSettle();

      expect(find.textContaining('Luyện tập VOCABULARY'), findsOneWidget);
      expect(find.text('Câu 1 / 2'), findsOneWidget);
      expect(find.text('Trắc nghiệm'), findsOneWidget);
      expect(find.text('Kiểm tra đáp án'), findsOneWidget);
    });

    testWidgets('2. Answering question triggers evaluation, result banner, and transitions button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget(const PracticeSessionScreen(skill: 'vocabulary')));
      await tester.pumpAndSettle();

      // Tap Option A ('茶')
      final optionA = find.text('茶');
      expect(optionA, findsOneWidget);
      await tester.tap(optionA);
      await tester.pumpAndSettle();

      // Tap 'Kiểm tra đáp án'
      final checkBtn = find.text('Kiểm tra đáp án');
      expect(checkBtn, findsOneWidget);
      await tester.tap(checkBtn);
      await tester.pumpAndSettle();

      // Verify result banner appears
      expect(find.textContaining('Chính xác (100%)'), findsOneWidget);
      expect(find.textContaining('Động từ "喝"'), findsOneWidget);

      // Verify button transforms to 'Câu tiếp theo'
      expect(find.text('Câu tiếp theo'), findsOneWidget);
      expect(find.text('Kiểm tra đáp án'), findsNothing);
    });

    testWidgets('3. Progressing through all questions completes session and shows summary dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(500, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget(const PracticeSessionScreen(skill: 'vocabulary')));
      await tester.pumpAndSettle();

      // Question 1: Select '茶' and submit
      await tester.tap(find.text('茶'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kiểm tra đáp án'));
      await tester.pumpAndSettle();

      // Go to Question 2
      await tester.tap(find.text('Câu tiếp theo'));
      await tester.pumpAndSettle();

      // Verify Question 2 is rendered
      expect(find.text('Câu 2 / 2'), findsOneWidget);
      expect(find.text('Chọn nghĩa / Pinyin'), findsOneWidget);

      // Question 2: Select 'píngguǒ' and submit
      await tester.tap(find.text('píngguǒ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kiểm tra đáp án'));
      await tester.pumpAndSettle();

      // Button should now be 'Hoàn thành phiên'
      final finishBtn = find.text('Hoàn thành phiên');
      expect(finishBtn, findsOneWidget);
      await tester.tap(finishBtn);
      await tester.pumpAndSettle();

      // Verify Completion Dialog
      expect(find.text('Hoàn Thành Luyện Tập!'), findsOneWidget);
      expect(find.textContaining('Điểm số đạt được:'), findsOneWidget);
      expect(find.textContaining('Bằng chứng học tập đã được lưu tự động'), findsOneWidget);
    });
  });
}
