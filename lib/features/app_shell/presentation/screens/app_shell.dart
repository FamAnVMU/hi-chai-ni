import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/startup/app_startup_provider.dart';
import '../../../../core/theme/theme.dart';
import '../../../ai_tutor/presentation/screens/ai_tutor_tab_screen.dart';
import '../../../home/presentation/screens/home_screen.dart';
import '../../../learning/presentation/screens/learning_screen.dart';
import '../../../profile/presentation/screens/profile_screen.dart';
import '../../../review/presentation/screens/review_screen.dart';
import '../providers/app_shell_providers.dart';
import '../widgets/hi_bottom_nav_bar.dart';

/// The Root Application Shell for HI Chinese containing:
/// 1. App Startup & SQLite DB readiness handling.
/// 2. 5-tab IndexedStack preserving state and scroll position.
/// 3. Prominent center AI Tutor action tab.
/// 4. Android back button navigation with PopScope and unsaved changes confirmation.
class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startupState = ref.watch(appStartupProvider);

    // 1. Initializing / Loading state
    if (startupState.isInitializing) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.translate_rounded,
                size: 64,
                color: AppColors.limeGreen,
              ),
              const SizedBox(height: AppSpacing.lg),
              HiLoadingIndicator(
                message: startupState.statusMessage,
              ),
            ],
          ),
        ),
      );
    }

    // 2. Startup Error state
    if (startupState.error != null) {
      return Scaffold(
        body: HiErrorState(
          title: 'Khởi động ứng dụng thất bại',
          message: startupState.error,
          retryText: 'Thử lại kết nối',
          onRetry: () {
            ref.read(appStartupProvider.notifier).initialize();
          },
        ),
      );
    }

    // 3. Main 5-Tab Shell
    final currentTab = ref.watch(selectedTabProvider);
    final hasUnsavedChanges = ref.watch(hasUnsavedChangesProvider);

    return PopScope(
      canPop: false, // Intercept Android system back button
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // A. If child screen has unsaved edits, confirm before leaving
        if (hasUnsavedChanges) {
          final shouldLeave = await HiDialog.show<bool>(
            context: context,
            title: 'Chưa lưu thay đổi',
            message: 'Bạn có dữ liệu chưa lưu. Bạn có chắc chắn muốn thoát không?',
            confirmText: 'Rời khỏi',
            cancelText: 'Ở lại',
            isDestructive: true,
            onConfirm: () => Navigator.of(context).pop(true),
          );

          if (shouldLeave != true) return;
        }

        // B. If not on Home tab, back button returns to Home tab first
        if (currentTab != AppTab.home) {
          ref.read(selectedTabProvider.notifier).selectTab(AppTab.home);
          return;
        }

        // C. On Home tab and confirmed safe to pop -> exit app
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: currentTab.index,
          children: const [
            HomeScreen(),
            LearningScreen(),
            AiTutorTabScreen(),
            ReviewScreen(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: HiBottomNavBar(
          currentTab: currentTab,
          onTabSelected: (tab) {
            ref.read(selectedTabProvider.notifier).selectTab(tab);
          },
        ),
      ),
    );
  }
}
