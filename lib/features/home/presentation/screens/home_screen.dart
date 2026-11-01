import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../../design_system/presentation/screens/design_system_demo_screen.dart';
import '../../../settings/presentation/screens/ai_settings_screen.dart';
import 'package:hi_chinese/features/app_shell/presentation/providers/app_shell_providers.dart';
import 'package:hi_chinese/features/vocabulary_srs/vocabulary_srs.dart';

/// Tab 0: Home Screen featuring quick stats, daily roadmap, and quick actions.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dueCountAsync = ref.watch(srsDueCountProvider);
    final dueCount = dueCountAsync.asData?.value ?? 0;

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
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Welcome & Streak Banner
              HiCard(
                backgroundColor: isDark
                    ? AppColors.darkForestCard
                    : theme.colorScheme.primaryContainer.withAlpha(120),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withAlpha(isDark ? 50 : 30),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_fire_department_rounded,
                        color: Colors.orange,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chuỗi học 5 ngày liên tiếp! 🔥',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Mục tiêu hôm nay: 20 từ mới & 1 bài đàm thoại',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 2. SRS Review Due Alert Card
              HiCard(
                borderColor: theme.colorScheme.primary.withAlpha(100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.psychology_rounded,
                          color: AppColors.limeGreen,
                          size: AppDimensions.iconMd,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Ôn tập ngắt quãng (SM-2)',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        HiChip(
                          label: dueCount > 0 ? '$dueCount từ' : 'Đã hoàn thành',
                          status: dueCount > 0 ? HiChipStatus.warning : HiChipStatus.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      dueCount > 0
                          ? 'Hôm nay có $dueCount thẻ từ vựng cần củng cố trí nhớ dài hạn theo thuật toán SM-2.'
                          : 'Tuyệt vời! Bạn đã hoàn thành tất cả thẻ cần ôn tập của ngày hôm nay.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    HiButton(
                      text: 'Bắt đầu ôn tập ngay',
                      icon: const Icon(Icons.play_arrow_rounded),
                      variant: HiButtonVariant.primary,
                      size: HiButtonSize.md,
                      isFullWidth: true,
                      onPressed: () {
                        // Switch directly to Review tab
                        ref.read(selectedTabProvider.notifier).selectTab(AppTab.review);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 3. Continue Learning Roadmap Card
              HiCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.school_rounded,
                          color: AppColors.limeGreen,
                          size: AppDimensions.iconMd,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Lộ trình học: HSK 1 Cơ Bản',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Bài 3: Chào hỏi và giới thiệu bản thân',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    RubyText.fromAnnotatedString(
                      annotatedText: '你[nǐ]好[hǎo]，我[wǒ]叫[jiào]李[lǐ]华[huá]。',
                      showPinyin: true,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const HiLinearProgress(value: 0.60),
                    const SizedBox(height: AppSpacing.md),
                    HiButton(
                      text: 'Tiếp tục bài học',
                      variant: HiButtonVariant.secondary,
                      size: HiButtonSize.md,
                      onPressed: () {
                        ref.read(selectedTabProvider.notifier).selectTab(AppTab.learning);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 4. AI Tutor Interactive Prompt Banner
              HiCard(
                backgroundColor: isDark
                    ? AppColors.darkForestSurface
                    : theme.colorScheme.tertiaryContainer.withAlpha(90),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.limeGreen.withAlpha(isDark ? 60 : 120),
                        borderRadius: AppRadius.borderMd,
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.darkForestBg,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Luyện hội thoại với AI Tutor',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Gia sư AI cá nhân hóa theo trình độ của bạn',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                      onPressed: () {
                        ref.read(selectedTabProvider.notifier).selectTab(AppTab.aiTutor);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
