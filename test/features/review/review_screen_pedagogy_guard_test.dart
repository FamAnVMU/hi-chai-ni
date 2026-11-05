import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/app_shell/presentation/providers/app_shell_providers.dart';
import 'package:hi_chinese/features/curriculum/presentation/providers/curriculum_providers.dart';
import 'package:hi_chinese/features/home/domain/models/home_dashboard_data.dart';
import 'package:hi_chinese/features/home/domain/models/learning_streak.dart';
import 'package:hi_chinese/features/home/presentation/providers/home_providers.dart';
import 'package:hi_chinese/features/home/presentation/screens/home_screen.dart';
import 'package:hi_chinese/features/home/presentation/widgets/home_quick_actions_grid.dart';
import 'package:hi_chinese/features/home/presentation/widgets/home_srs_due_card.dart';
import 'package:hi_chinese/features/review/presentation/screens/review_screen.dart';
import 'package:hi_chinese/features/vocabulary_srs/vocabulary_srs.dart';

class _TestSrsStudySessionNotifier extends SrsStudySessionNotifier {
  final SrsStudySession _session;
  _TestSrsStudySessionNotifier(this._session);

  @override
  Future<SrsStudySession> build() async => _session;
}

class _TestSrsDueCountNotifier extends SrsDueCountNotifier {
  final int _count;
  _TestSrsDueCountNotifier(this._count);

  @override
  Future<int> build() async => _count;
}

class _TestStaticHomeNotifier extends HomeDashboardNotifier {
  final HomeDashboardData _data;
  _TestStaticHomeNotifier(this._data);

  @override
  Future<HomeDashboardData> build() async => _data;
}

void main() {
  group('Task T2-2: Logic Ôn Tập – Block/Ẩn Khi Chưa Học Gì', () {
    testWidgets('1. ReviewScreen: Displays NoLessonsYetState when user has completed 0 lessons', (tester) async {
      final container = ProviderContainer(
        overrides: [
          hasCompletedLessonsProvider.overrideWith((ref) => Future.value(false)),
          srsStudySessionProvider.overrideWith(
            () => _TestSrsStudySessionNotifier(const SrsStudySession(queue: [])),
          ),
          srsDueCountProvider.overrideWith(() => _TestSrsDueCountNotifier(0)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ReviewScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Must NOT display "Xuất Sắc! Hoàn Thành Ôn Tập"
      expect(find.text('Xuất Sắc! Hoàn Thành Ôn Tập'), findsNothing);
      expect(find.text('Không còn thẻ nào đến hạn hôm nay.'), findsNothing);

      // Must display NoLessonsYetState
      expect(find.text('Bắt đầu học trước nhé!'), findsOneWidget);
      expect(
        find.text('Bạn chưa hoàn thành bài học nào. Hãy vào phần Bài Học và học ít nhất 1 bài để có thể ôn tập.'),
        findsOneWidget,
      );
      expect(find.text('Đến Bài Học ngay'), findsOneWidget);
      expect(find.byIcon(Icons.menu_book_rounded), findsOneWidget);

      // Tapping "Đến Bài Học ngay" switches selectedTab to learning
      await tester.tap(find.text('Đến Bài Học ngay'));
      await tester.pumpAndSettle();

      expect(container.read(selectedTabProvider), AppTab.learning);
    });

    testWidgets('2. ReviewScreen: Displays FlashcardEmptyState when user has completed lessons and queue is empty', (tester) async {
      final container = ProviderContainer(
        overrides: [
          hasCompletedLessonsProvider.overrideWith((ref) => Future.value(true)),
          srsStudySessionProvider.overrideWith(
            () => _TestSrsStudySessionNotifier(
              const SrsStudySession(
                queue: [],
                completedReviewsCount: 10,
                correctReviewsCount: 9,
              ),
            ),
          ),
          srsDueCountProvider.overrideWith(() => _TestSrsDueCountNotifier(0)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ReviewScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Must display FlashcardEmptyState
      expect(find.text('Xuất Sắc! Hoàn Thành Ôn Tập'), findsOneWidget);
      expect(find.text('Bắt đầu học trước nhé!'), findsNothing);
    });

    testWidgets('3. HomeScreen: Hides HomeSrsDueCard and displays first lesson prompt when hasCompletedLessons is false', (tester) async {
      final freshData = HomeDashboardData(
        learnerName: 'Học viên',
        greeting: 'Chào mừng bạn!',
        streak: LearningStreak.empty(),
        srsDueCount: 0,
        roadmap: RoadmapProgress.initial(),
        recentActivities: const [],
        studyStats: const StudyTimeStats(),
        hasCompletedLessons: false,
      );

      final container = ProviderContainer(
        overrides: [
          homeDashboardProvider.overrideWith(() => _TestStaticHomeNotifier(freshData)),
          hasCompletedLessonsProvider.overrideWith((ref) => Future.value(false)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // HomeSrsDueCard should NOT be shown
      expect(find.byType(HomeSrsDueCard), findsNothing);
      expect(find.text('Xem lại thẻ đã học'), findsNothing);

      // First lesson card prompt should be shown
      expect(find.text('Bắt đầu bài học đầu tiên'), findsWidgets);
      expect(find.text('Khởi đầu mới'), findsOneWidget);
      expect(find.text('Đến bài học ngay'), findsOneWidget);

      // Tapping "Đến bài học ngay" navigates to learning tab
      await tester.tap(find.text('Đến bài học ngay'));
      await tester.pumpAndSettle();

      expect(container.read(selectedTabProvider), AppTab.learning);
    });

    testWidgets('4. HomeQuickActionsGrid: Blocks review tab navigation and shows SnackBar when hasCompletedLessons is false', (tester) async {
      final container = ProviderContainer(
        overrides: [
          hasCompletedLessonsProvider.overrideWith((ref) => Future.value(false)),
        ],
      );

      var navigatedToReview = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: HomeQuickActionsGrid(
                hasCompletedLessons: false,
                onNavigateLearning: () {},
                onNavigateReview: () => navigatedToReview = true,
                onNavigateAiTutor: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "Ôn tập thẻ"
      await tester.tap(find.text('Ôn tập thẻ'));
      await tester.pump();

      // Navigation should be blocked
      expect(navigatedToReview, isFalse);

      // SnackBar message displayed
      expect(find.text('Hãy hoàn thành ít nhất 1 bài học trước khi ôn tập!'), findsOneWidget);
    });

    testWidgets('5. HomeQuickActionsGrid: Allows review navigation when hasCompletedLessons is true', (tester) async {
      final container = ProviderContainer(
        overrides: [
          hasCompletedLessonsProvider.overrideWith((ref) => Future.value(true)),
        ],
      );

      var navigatedToReview = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: HomeQuickActionsGrid(
                hasCompletedLessons: true,
                onNavigateLearning: () {},
                onNavigateReview: () => navigatedToReview = true,
                onNavigateAiTutor: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "Ôn tập thẻ"
      await tester.tap(find.text('Ôn tập thẻ'));
      await tester.pump();

      // Navigation should be permitted
      expect(navigatedToReview, isTrue);
    });
  });
}
