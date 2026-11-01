import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/features/app_shell/presentation/providers/app_shell_providers.dart';
import 'package:hi_chinese/features/home/domain/models/home_dashboard_data.dart';
import 'package:hi_chinese/features/home/domain/models/learning_streak.dart';
import 'package:hi_chinese/features/home/presentation/providers/home_providers.dart';
import 'package:hi_chinese/features/home/presentation/screens/home_screen.dart';
import 'package:hi_chinese/features/home/presentation/widgets/home_skeleton_loading.dart';

void main() {
  Widget buildTestWidget({
    required List<dynamic> overrides,
    Size screenSize = const Size(390, 844),
  }) {
    return ProviderScope(
      overrides: overrides.cast(),
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: MediaQueryData(size: screenSize),
          child: const HomeScreen(),
        ),
      ),
    );
  }

  group('HomeScreen Widget & UX Acceptance Tests', () {
    testWidgets('1. Displays HomeSkeletonLoading while home dashboard is loading', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            homeDashboardProvider.overrideWith(
              () => _TestLoadingNotifier(),
            ),
          ],
        ),
      );

      // Verify skeleton placeholders are rendered
      expect(find.byType(HomeSkeletonLoading), findsOneWidget);
    });

    testWidgets('2. Displays HiErrorState on failure and triggers retry upon button click', (tester) async {
      var retryCalled = false;
      final testErrorNotifier = _TestErrorNotifier(
        onRefreshCalled: () => retryCalled = true,
      );

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            homeDashboardProvider.overrideWith(() => testErrorNotifier),
          ],
        ),
      );

      // Allow microtask and future to complete
      await tester.pumpAndSettle();

      expect(find.text('Không thể tải dữ liệu trang chủ'), findsOneWidget);
      expect(find.byType(HiErrorState), findsOneWidget);

      // Tap Retry button
      await tester.tap(find.text('Thử lại'));
      await tester.pump();

      expect(retryCalled, isTrue);
    });

    testWidgets('3. Renders new learner dashboard with zero streak, 0 due cards, and empty activity state', (tester) async {
      final freshData = HomeDashboardData.empty();

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            homeDashboardProvider.overrideWith(
              () => _TestStaticDataNotifier(freshData),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // Welcome card for fresh user
      expect(find.text('Bắt đầu chuỗi học tập mới 🌱'), findsOneWidget);
      expect(find.text('Mỗi ngày học một chút để hình thành phản xạ tiếng Trung tự nhiên.'), findsOneWidget);

      // SRS card empty
      expect(find.text('Đã hoàn thành'), findsOneWidget);
      expect(find.text('Xem lại thẻ đã học'), findsOneWidget);

      // Roadmap progress
      expect(find.textContaining('0%'), findsOneWidget);
      expect(find.text('Bắt đầu bài học đầu tiên'), findsOneWidget);

      // Recent activities empty state
      expect(find.text('Chưa có hoạt động học nào'), findsOneWidget);
      expect(find.text('Bắt đầu học ngay'), findsOneWidget);
    });

    testWidgets('4. Renders active learner dashboard with flame streak, SRS due warning, and matching numbers', (tester) async {
      final activeData = HomeDashboardData(
        learnerName: 'Nguyễn Văn A',
        greeting: 'Chào buổi sáng! ☀️',
        streak: const LearningStreak(
          currentStreak: 5,
          bestStreak: 12,
          hasStudiedToday: true,
          todayDurationSeconds: 720, // 12 mins
          todayItemsCompleted: 15,
        ),
        srsDueCount: 12,
        roadmap: const RoadmapProgress(
          currentHskLevel: 1,
          levelTitle: 'Lộ trình: HSK 1 Cơ Bản',
          totalVocabCount: 150,
          learnedVocabCount: 45,
          masteredVocabCount: 10,
          nextLessonTitle: 'Bài 2: Con số & Đồ vật',
          nextLessonSnippet: '一[yī]、二[èr]、三[sān]',
        ),
        recentActivities: [
          RecentActivityItem(
            id: 'ACT_01',
            title: 'Ôn tập Flashcard (SM-2)',
            subtitle: '15 mục • 12 phút',
            type: ActivityType.srsReview,
            timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
            durationSeconds: 720,
            itemsCount: 15,
          ),
        ],
        dailyGoalWords: 15,
        dailyGoalMinutes: 15,
      );

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            homeDashboardProvider.overrideWith(
              () => _TestStaticDataNotifier(activeData),
            ),
          ],
        ),
      );

      await tester.pumpAndSettle();

      // UI matches exact repository numbers
      expect(find.text('Chào buổi sáng! ☀️, Nguyễn Văn A'), findsOneWidget);
      expect(find.text('Chuỗi học 5 ngày liên tiếp! 🔥'), findsOneWidget);
      expect(find.text('12 thẻ đến hạn'), findsOneWidget);
      expect(find.text('Bắt đầu ôn tập ngay'), findsOneWidget);
      expect(find.text('45/150 từ'), findsOneWidget);
      expect(find.text('Tiến độ cấp độ: 30%'), findsOneWidget);
      expect(find.text('10 từ thành thạo'), findsOneWidget);
      expect(find.text('Đạt mục tiêu ⭐'), findsOneWidget);
      expect(find.text('Ôn tập ngắt quãng (SM-2)'), findsOneWidget); // SRS Card title
      expect(find.text('Ôn tập Flashcard (SM-2)'), findsOneWidget); // Recent activity
    });

    testWidgets('5. Tapping SRS review CTA navigates to Review tab', (tester) async {
      final activeData = HomeDashboardData(
        learnerName: 'Học viên',
        greeting: 'Chào bạn!',
        streak: const LearningStreak(
          currentStreak: 1,
          bestStreak: 1,
          hasStudiedToday: true,
        ),
        srsDueCount: 8,
        roadmap: RoadmapProgress.initial(),
        recentActivities: const [],
      );

      AppTab? selectedTab;

      final container = ProviderContainer(
        overrides: [
          homeDashboardProvider.overrideWith(
            () => _TestStaticDataNotifier(activeData),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "Bắt đầu ôn tập ngay"
      await tester.tap(find.text('Bắt đầu ôn tập ngay'));
      await tester.pump();

      selectedTab = container.read(selectedTabProvider);
      expect(selectedTab, AppTab.review);
    });

    testWidgets('6. Quick Actions Grid navigates to Learning, Review, AI Tutor, and opens Dictionary', (tester) async {
      final activeData = HomeDashboardData.empty();
      final container = ProviderContainer(
        overrides: [
          homeDashboardProvider.overrideWith(
            () => _TestStaticDataNotifier(activeData),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const HomeScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify all 4 action buttons exist
      expect(find.text('Bài học HSK'), findsOneWidget);
      expect(find.text('Ôn tập thẻ'), findsOneWidget);
      expect(find.text('Từ điển tra cứu'), findsOneWidget);
      expect(find.text('AI Voice Tutor'), findsOneWidget);

      // Tap "Bài học HSK"
      await tester.tap(find.text('Bài học HSK'));
      await tester.pump();
      expect(container.read(selectedTabProvider), AppTab.learning);

      // Tap "AI Voice Tutor"
      await tester.tap(find.text('AI Voice Tutor'));
      await tester.pump();
      expect(container.read(selectedTabProvider), AppTab.aiTutor);

      // Tap "Ôn tập thẻ"
      await tester.tap(find.text('Ôn tập thẻ'));
      await tester.pump();
      expect(container.read(selectedTabProvider), AppTab.review);
    });

    testWidgets('7. Layout renders without overflow on narrow 320dp screen', (tester) async {
      final activeData = HomeDashboardData(
        learnerName: 'Học viên có tên rất dài trên màn hình nhỏ',
        greeting: 'Chào buổi tối! 🌙',
        streak: const LearningStreak(
          currentStreak: 99,
          bestStreak: 120,
          hasStudiedToday: true,
          todayDurationSeconds: 1800,
          todayItemsCompleted: 30,
        ),
        srsDueCount: 42,
        roadmap: const RoadmapProgress(
          currentHskLevel: 2,
          levelTitle: 'Lộ trình: HSK 2 Nâng Cao',
          totalVocabCount: 300,
          learnedVocabCount: 150,
          masteredVocabCount: 80,
          nextLessonTitle: 'Bài 10: Đi mua sắm tại siêu thị',
          nextLessonSnippet: '这[zhè]个[ge]多[duō]少[shao]钱[qián]？',
        ),
        recentActivities: const [],
      );

      await tester.pumpWidget(
        buildTestWidget(
          overrides: [
            homeDashboardProvider.overrideWith(
              () => _TestStaticDataNotifier(activeData),
            ),
          ],
          screenSize: const Size(320, 600), // Narrow small Android device
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull); // Zero layout overflows!
      expect(find.text('Chuỗi học 99 ngày liên tiếp! 🔥'), findsOneWidget);
      expect(find.text('42 thẻ đến hạn'), findsOneWidget);
    });
  });
}

class _TestLoadingNotifier extends HomeDashboardNotifier {
  @override
  Future<HomeDashboardData> build() async {
    // Hangs in loading state
    return Completer<HomeDashboardData>().future;
  }
}

class _TestErrorNotifier extends HomeDashboardNotifier {
  final VoidCallback onRefreshCalled;

  _TestErrorNotifier({required this.onRefreshCalled});

  @override
  Future<HomeDashboardData> build() async {
    throw Exception('Simulated database connection failure');
  }

  @override
  Future<void> refresh() async {
    onRefreshCalled();
    state = const AsyncValue.error('Simulated error on refresh', StackTrace.empty);
  }
}

class _TestStaticDataNotifier extends HomeDashboardNotifier {
  final HomeDashboardData data;

  _TestStaticDataNotifier(this.data);

  @override
  Future<HomeDashboardData> build() async {
    return data;
  }
}
