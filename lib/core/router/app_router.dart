import 'package:flutter/material.dart';
import '../../features/app_shell/presentation/providers/app_shell_providers.dart';
import '../../features/app_shell/presentation/screens/app_shell.dart';
import '../../features/design_system/presentation/screens/design_system_demo_screen.dart';
import '../../features/onboarding/presentation/providers/onboarding_providers.dart';
import '../../features/onboarding/presentation/screens/onboarding_flow_screen.dart';
import '../../features/settings/presentation/screens/ai_settings_screen.dart';
import 'app_routes.dart';

enum RouteGuardAction {
  allow,
  redirectToOnboarding,
  redirectToHome,
}

class AppRouteGuard {
  AppRouteGuard._();

  static RouteGuardAction evaluate({
    required String path,
    required bool isOnboardingCompleted,
  }) {
    final normalized = AppRouter.normalizeRouteName(path);

    if (!isOnboardingCompleted) {
      if (normalized == AppRoutes.onboarding) {
        return RouteGuardAction.allow;
      }
      return RouteGuardAction.redirectToOnboarding;
    }

    if (normalized == AppRoutes.onboarding) {
      return RouteGuardAction.redirectToHome;
    }

    return RouteGuardAction.allow;
  }
}

class AppRouter {
  AppRouter._();

  static String normalizeRouteName(String? raw) {
    if (raw == null || raw.isEmpty) return AppRoutes.root;
    final uri = Uri.tryParse(raw);
    if (uri != null) {
      if (uri.scheme == 'hichinese') {
        final host = uri.host;
        final path = uri.path;
        final combined = '/$host$path'.replaceAll(RegExp(r'/+'), '/');
        return combined.isEmpty ? AppRoutes.root : combined;
      }
      if (uri.path.isNotEmpty) {
        return uri.path;
      }
    }
    return raw;
  }

  static Route<dynamic> onGenerateRoute(RouteSettings settings, dynamic ref) {
    final routeName = normalizeRouteName(settings.name);
    final onboardingState = ref.read(onboardingProvider);
    final isCompleted = onboardingState.isCompleted;

    final guardAction = AppRouteGuard.evaluate(
      path: routeName,
      isOnboardingCompleted: isCompleted,
    );

    switch (guardAction) {
      case RouteGuardAction.redirectToOnboarding:
        return MaterialPageRoute(
          settings: const RouteSettings(name: AppRoutes.onboarding),
          builder: (_) => const AppShell(),
        );

      case RouteGuardAction.redirectToHome:
        return MaterialPageRoute(
          settings: const RouteSettings(name: AppRoutes.home),
          builder: (_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(selectedTabProvider.notifier).selectTab(AppTab.home);
            });
            return const AppShell();
          },
        );

      case RouteGuardAction.allow:
        break;
    }

    if (routeName == AppRoutes.onboarding) {
      return MaterialPageRoute(
        settings: settings,
        builder: (_) => OnboardingFlowScreen(
          onOnboardingComplete: () {
            ref.read(selectedTabProvider.notifier).selectTab(AppTab.home);
          },
        ),
      );
    }

    switch (routeName) {
      case AppRoutes.root:
      case AppRoutes.home:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(selectedTabProvider.notifier).selectTab(AppTab.home);
            });
            return const AppShell();
          },
        );
      case AppRoutes.learning:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(selectedTabProvider.notifier).selectTab(AppTab.learning);
            });
            return const AppShell();
          },
        );
      case AppRoutes.aiTutor:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(selectedTabProvider.notifier).selectTab(AppTab.aiTutor);
            });
            return const AppShell();
          },
        );
      case AppRoutes.review:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(selectedTabProvider.notifier).selectTab(AppTab.review);
            });
            return const AppShell();
          },
        );
      case AppRoutes.profile:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(selectedTabProvider.notifier).selectTab(AppTab.profile);
            });
            return const AppShell();
          },
        );
      case AppRoutes.designSystem:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const DesignSystemDemoScreen(),
        );
      case AppRoutes.aiSettings:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AiSettingsScreen(),
        );
      default:
        return MaterialPageRoute(
          settings: settings,
          builder: (_) => const AppShell(),
        );
    }
  }
}
