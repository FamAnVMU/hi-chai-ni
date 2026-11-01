import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../../app_shell/presentation/providers/app_shell_providers.dart';
import '../../../design_system/presentation/screens/design_system_demo_screen.dart';
import '../../../settings/presentation/screens/ai_settings_screen.dart';
import '../providers/home_providers.dart';
import '../widgets/home_quick_actions_grid.dart';
import '../widgets/home_recent_activities_card.dart';
import '../widgets/home_roadmap_card.dart';
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
        actions: [
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Design System Showcase',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DesignSystemDemoScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Cài Đặt AI & Kết Nối',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
              );
            },
          ),
        ],
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

                  // 2. SRS Review Due Alert Card
                  HomeSrsDueCard(
                    dueCount: data.srsDueCount,
                    onStartReview: () {
                      ref
                          .read(selectedTabProvider.notifier)
                          .selectTab(AppTab.review);
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 3. Quick Actions Grid (Học tập, Ôn tập, Từ điển, AI Tutor)
                  HomeQuickActionsGrid(
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

                  // 4. Curriculum Roadmap Progress Card
                  HomeRoadmapCard(
                    roadmap: data.roadmap,
                    onContinueLesson: () {
                      ref
                          .read(selectedTabProvider.notifier)
                          .selectTab(AppTab.learning);
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),

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
