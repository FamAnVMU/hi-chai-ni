import '../../../curriculum/presentation/screens/curriculum_syllabus_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../../app_shell/presentation/providers/app_shell_providers.dart';
import '../providers/home_providers.dart';
import '../widgets/home_quick_actions_grid.dart';
import '../widgets/home_recent_activities_card.dart';
import '../widgets/home_lesson_access_card.dart';
import '../widgets/home_skeleton_loading.dart';
import '../widgets/home_srs_due_card.dart';
import '../widgets/home_welcome_streak_card.dart';

/// Tab 0: Home Screen featuring real SQLite metrics: active streak, SRS due cards,
/// curriculum roadmap progress, 4 quick actions, and recent activities summary.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final dashboardAsync = ref.watch(homeDashboardProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('HI Chinese'),
      ),
      body: SafeArea(
        child: dashboardAsync.hasError && !dashboardAsync.hasValue
            ? Center(
                child: SingleChildScrollView(
                  padding: AppSpacing.screenPadding,
                  child: HiErrorState(
                    title: 'Không thể tải dữ liệu trang chủ',
                    message: dashboardAsync.error.toString(),
                    onRetry: () =>
                        ref.read(homeDashboardProvider.notifier).refresh(),
                  ),
                ),
              )
            : dashboardAsync.when(
                loading: () => const HomeSkeletonLoading(),
                error: (error, _) => Center(
                  child: SingleChildScrollView(
                    padding: AppSpacing.screenPadding,
                    child: HiErrorState(
                      title: 'Không thể tải dữ liệu trang chủ',
                      message: error.toString(),
                      onRetry: () =>
                          ref.read(homeDashboardProvider.notifier).refresh(),
                    ),
                  ),
                ),
                data: (data) => RefreshIndicator(
            onRefresh: () =>
                ref.read(homeDashboardProvider.notifier).refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Welcome & Daily Goal / Streak Card
                  HomeWelcomeStreakCard(data: data),
                  const SizedBox(height: AppSpacing.lg),

                  // 2. Lesson Access Card (Truy cập bài học HSK)
                  HomeLessonAccessCard(
                    roadmap: data.roadmap,
                    onNavigateLearning: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CurriculumSyllabusScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 3. Quick Actions Grid (Học tập, Ôn tập, Từ điển, AI Tutor)
                  HomeQuickActionsGrid(
                    hasCompletedLessons: data.hasCompletedLessons,
                    onNavigateLearning: () {
                      ref
                          .read(selectedTabProvider.notifier)
                          .selectTab(AppTab.learning);
                    },
                    onNavigateReview: () {
                      ref
                          .read(selectedTabProvider.notifier)
                          .selectTab(AppTab.review);
                    },
                    onNavigateAiTutor: () {
                      ref
                          .read(selectedTabProvider.notifier)
                          .selectTab(AppTab.aiTutor);
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 4. SRS Due Card (chỉ hiển thị khi có lesson đã hoàn thành)
                  if (data.hasCompletedLessons && data.srsDueCount > 0) ...[
                    HomeSrsDueCard(
                      dueCount: data.srsDueCount,
                      onStartReview: () {
                        ref
                            .read(selectedTabProvider.notifier)
                            .selectTab(AppTab.review);
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],

                  // 5. Recent Learning Activities Summary
                  HomeRecentActivitiesCard(
                    activities: data.recentActivities,
                    onStartLearning: () {
                      ref
                          .read(selectedTabProvider.notifier)
                          .selectTab(AppTab.learning);
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
