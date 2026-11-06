import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/ai/models/ai_model_config.dart';
import '../../../../core/network/ai/security/ai_credential_storage.dart';
import '../../../../core/theme/theme.dart';
import '../../../placement_test/presentation/screens/placement_test_intro_screen.dart';
import '../providers/onboarding_providers.dart';
import 'onboarding_api_key_screen.dart';
import 'onboarding_personalization_screen.dart';
import '../../../content_packs/presentation/providers/content_packs_providers.dart';

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
            initialHskLevel: onboardingState.assessedHskLevel,
            onBack: () => notifier.previousStep(),
            onComplete: (dailyMinutes, focusSkill, [PersonalizationData? data]) async {
              final chosenHsk = data?.targetHskLevel ?? onboardingState.assessedHskLevel ?? 1;
              final currentHsk = (chosenHsk <= 0) ? 1 : (chosenHsk > 6 ? 6 : chosenHsk);

              // Interceptor: When user starts with HSK >= 3, check pack installation
              if (currentHsk >= 3) {
                final isInstalled = await ref.read(isHskLevelInstalledProvider(currentHsk).future);
                if (!isInstalled && context.mounted) {
                  final shouldDownload = await _showDownloadHskDialog(context, currentHsk);
                  if (shouldDownload == true && context.mounted) {
                    final downloadSuccess = await _performDownloadWithProgress(context, ref, currentHsk);
                    if (context.mounted && downloadSuccess) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã tải thành công giáo trình HSK $currentHsk!'),
                          backgroundColor: AppColors.success,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  } else if (context.mounted) {
                    // Action 2: "Để sau" -> Save HSK 3+, provide visual guidance to Roadmap
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Bạn đã chọn HSK $currentHsk. Bạn có thể tải gói học liệu bất cứ lúc nào trong Lộ trình hoặc Cài đặt.'),
                        backgroundColor: AppColors.primaryBlueDark,
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                }
              }

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
                targetHskLevel: currentHsk,
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

  Future<bool?> _showDownloadHskDialog(BuildContext context, int currentHsk) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.primaryBlueLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.download_rounded,
                color: AppColors.primaryBlueDark,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Bạn đã sẵn sàng học HSK $currentHsk!',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Để học ngay giáo trình và từ vựng chuẩn HSK $currentHsk, ứng dụng cần tải gói học liệu (~350KB - 1.5MB). Bạn muốn tải ngay bây giờ không?',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Để sau',
              style: TextStyle(
                color: AppColors.mutedText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlueDark,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Tải ngay & Bắt đầu',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _performDownloadWithProgress(
    BuildContext context,
    WidgetRef ref,
    int currentHsk,
  ) async {
    final packId = 'hsk${currentHsk}_pack_v1';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => PopScope(
        canPop: false,
        child: Consumer(
          builder: (context, ref, _) {
            final packsState = ref.watch(contentPacksProvider);
            double progress = 0.2;
            String status = 'Đang tải dữ liệu bài học & từ vựng HSK $currentHsk...';

            packsState.whenData((packs) {
              final pack = packs.where((p) => p.info.packId == packId).firstOrNull;
              if (pack != null) {
                if (pack.progress > 0) {
                  progress = pack.progress;
                }
                if (pack.isInstalled) {
                  progress = 1.0;
                  status = 'Cài đặt hoàn tất!';
                } else if (pack.error != null) {
                  status = 'Đang xử lý gói học liệu...';
                }
              }
            });

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Đang tải HSK $currentHsk...',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      backgroundColor: AppColors.border,
                      valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryBlueDark),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          status,
                          style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlueDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    try {
      final success = await ref.read(contentPacksProvider.notifier).installPack(packId);
      await Future.delayed(const Duration(milliseconds: 300));
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ref.invalidate(isHskLevelInstalledProvider(currentHsk));
      return success;
    } catch (_) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      return false;
    }
  }
}
