import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../../app_shell/presentation/providers/app_shell_providers.dart';
import '../../domain/models/cat_assessment_result.dart';
import '../widgets/cat_knowledge_gaps_card.dart';
import '../widgets/cat_skill_radar_card.dart';

/// Screen presenting the complete pedagogical diagnostic report,
/// skill breakdown, knowledge gaps, and recommended learning roadmap.
class PlacementTestResultScreen extends ConsumerWidget {
  final CatAssessmentResult result;

  const PlacementTestResultScreen({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Báo Cáo Đánh Giá Năng Lực'),
        automaticallyImplyLeading: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Overall Reference HSK Level Card
              HiCard(
                backgroundColor: isDark
                    ? AppColors.cardBackground
                    : theme.colorScheme.primaryContainer.withAlpha(120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withAlpha(isDark ? 50 : 30),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.school_rounded,
                            color: AppColors.primaryBlueDark,
                            size: AppDimensions.iconLg,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cấp độ tham chiếu nội bộ',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                result.referenceHskBand,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        HiChip(
                          label: 'Độ tin cậy: ${(result.confidenceScore * 100).toInt()}%',
                          status: result.confidenceScore >= 0.7
                              ? HiChipStatus.success
                              : HiChipStatus.neutral,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Mandatory pedagogical disclaimer
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withAlpha(120),
                        borderRadius: AppRadius.borderSm,
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withAlpha(80),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              CatAssessmentResult.disclaimerVi,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 2. Six Assessed Skills Breakdown Card
              CatSkillRadarCard(skillScores: result.skillScores),
              const SizedBox(height: AppSpacing.lg),

              // 3. Knowledge Gaps Card
              CatKnowledgeGapsCard(knowledgeGaps: result.knowledgeGaps),
              const SizedBox(height: AppSpacing.lg),

              // 4. Recommended Starting Level & Learning Action
              HiCard(
                borderColor: AppColors.primaryBlueDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.flag_rounded,
                          color: AppColors.primaryBlueDark,
                          size: AppDimensions.iconMd,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            result.recommendedRoadmapTitle,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        HiChip(
                          label: 'HSK ${result.recommendedHskLevel}',
                          status: HiChipStatus.success,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Dựa trên năng lực thực tế và các lỗ hổng phát hiện được, hệ thống đề xuất bạn bắt đầu học từ cấp độ HSK ${result.recommendedHskLevel} để tối ưu hóa thời gian tiếp thu kiến thức.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    HiButton(
                      text: 'Bắt đầu học theo lộ trình gợi ý',
                      icon: const Icon(Icons.play_arrow_rounded),
                      variant: HiButtonVariant.primary,
                      size: HiButtonSize.lg,
                      isFullWidth: true,
                      onPressed: () {
                        // Switch to Learning tab (Tab 1) and pop to root
                        ref
                            .read(selectedTabProvider.notifier)
                            .selectTab(AppTab.learning);
                        Navigator.of(context).popUntil((route) => route.isFirst);
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
