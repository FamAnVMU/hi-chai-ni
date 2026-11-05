import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/ai/models/ai_model_config.dart';
import '../../../../core/network/ai/security/ai_credential_storage.dart';
import '../../../../core/theme/theme.dart';
import '../../../placement_test/presentation/screens/placement_test_intro_screen.dart';
import '../providers/onboarding_providers.dart';
import 'onboarding_api_key_screen.dart';
import 'onboarding_personalization_screen.dart';

class OnboardingFlowScreen extends ConsumerWidget {
  final VoidCallback onOnboardingComplete;
  final AiCredentialStorage? credentialStorageOverride;

  const OnboardingFlowScreen({
    super.key,
    required this.onOnboardingComplete,
    this.credentialStorageOverride,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingState = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    ref.listen<String?>(
      onboardingProvider.select((s) => s.errorMessage),
      (prev, next) {
        if (next != null && next.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Lỗi khởi tạo cấu hình: $next'),
              backgroundColor: AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      },
    );

    if (onboardingState.isLoading) {
      return const Scaffold(
        body: Center(
          child: HiLoadingIndicator(
            message: 'Đang tải cấu hình khởi đầu...',
          ),
        ),
      );
    }

    Widget currentScreen;
    switch (onboardingState.currentStep) {
      case OnboardingStep.aiSetup:
        currentScreen = KeyedSubtree(
          key: const ValueKey('step_ai_setup'),
          child: OnboardingApiKeyScreen(
            onSkip: () {
              notifier.setStep(OnboardingStep.placementTest, skippedAi: true);
            },
            onSaveApiKey: (apiKey, [provider = AiProviderType.geminiRest]) async {
              final cleanKey = apiKey.trim();
              final validationError = AiCredentialStorage.validateApiKey(cleanKey);
              if (validationError != null) return false;

              try {
                final storage = credentialStorageOverride ?? AiCredentialStorage();
                await storage.saveApiKey(cleanKey, provider: provider);
                await storage.saveProviderType(provider);
                await notifier.setStep(OnboardingStep.placementTest, skippedAi: false);
                return true;
              } catch (_) {
                return false;
              }
            },
            onSuccessNext: () {
              notifier.setStep(OnboardingStep.placementTest, skippedAi: false);
            },
          ),
        );
        break;

      case OnboardingStep.placementTest:
        currentScreen = KeyedSubtree(
          key: const ValueKey('step_placement_test'),
          child: PlacementTestIntroScreen(
            onBack: () => notifier.previousStep(),
            onTestComplete: ([hskLevel]) {
              notifier.completePlacementTest(hskLevel);
            },
          ),
        );
        break;

      case OnboardingStep.personalization:
        currentScreen = KeyedSubtree(
          key: const ValueKey('step_personalization'),
          child: OnboardingPersonalizationScreen(
            onBack: () => notifier.previousStep(),
            onComplete: (dailyMinutes, focusSkill, [PersonalizationData? data]) async {
              final success = await notifier.completePersonalization(
                dailyMinutes: dailyMinutes,
                focusSkill: focusSkill,
                learningPurpose: data?.purpose ?? 'dailyCommunication',
                showPinyin: data?.showPinyin ?? true,
                pinyinPosition: data?.pinyinPosition ?? 'above_hanzi',
                scriptType: data?.scriptType ?? 'simplified',
                learningMethod: data?.learningMethod ?? 'contextual_lessons',
                speechRate: data?.speechRate ?? 1.0,
                reminderEnabled: data?.reminderEnabled ?? true,
                reminderTime: data?.reminderTime ?? '20:00',
              );
              if (success) {
                onOnboardingComplete();
              }
            },
          ),
        );
        break;

      case OnboardingStep.completed:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onOnboardingComplete();
        });
        return const Scaffold(
          body: Center(
            child: HiLoadingIndicator(
              message: 'Đang khởi tạo lộ trình học tập...',
            ),
          ),
        );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: currentScreen,
    );
  }
}
