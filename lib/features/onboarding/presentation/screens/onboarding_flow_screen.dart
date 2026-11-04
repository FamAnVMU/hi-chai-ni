import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/ai/models/ai_model_config.dart';
import '../../../../core/network/ai/security/ai_credential_storage.dart';
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

    if (onboardingState.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    switch (onboardingState.currentStep) {
      case OnboardingStep.aiSetup:
        return OnboardingApiKeyScreen(
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
        );

      case OnboardingStep.placementTest:
        return PlacementTestIntroScreen(
          onTestComplete: ([hskLevel]) {
            notifier.completePlacementTest(hskLevel);
          },
        );

      case OnboardingStep.personalization:
        return OnboardingPersonalizationScreen(
          onComplete: (dailyMinutes, focusSkill) async {
            await notifier.completePersonalization(
              dailyMinutes: dailyMinutes,
              focusSkill: focusSkill,
            );
            onOnboardingComplete();
          },
        );

      case OnboardingStep.completed:
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onOnboardingComplete();
        });
        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
    }
  }
}
