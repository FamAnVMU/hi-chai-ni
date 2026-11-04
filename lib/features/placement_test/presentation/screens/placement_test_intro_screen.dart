import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../providers/placement_test_providers.dart';
import 'placement_test_flow_screen.dart';
import 'placement_test_result_screen.dart';

enum LearnerExperienceLevel {
  zeroChinese(
    'Người mới bắt đầu',
    'Chưa từng học tiếng Trung. Học từ Pinyin và nét chữ cơ bản.',
    Icons.school_outlined,
  ),
  basicPinyin(
    'Đã biết cơ bản',
    'Biết phát âm Pinyin hoặc một số chữ Hán đơn giản (50 - 150 từ).',
    Icons.translate_rounded,
  ),
  intermediate(
    'Đã học một thời gian',
    'Có vốn từ và ngữ pháp, muốn kiểm tra chuẩn xác năng lực thực tế.',
    Icons.auto_stories_rounded,
  ),
  hasHsk(
    'Đã có chứng chỉ HSK',
    'Đã từng học hoặc thi đạt các cấp độ HSK 1 đến HSK 6.',
    Icons.workspace_premium_rounded,
  );

  final String title;
  final String description;
  final IconData icon;
  const LearnerExperienceLevel(this.title, this.description, this.icon);
}

class PlacementTestIntroScreen extends ConsumerStatefulWidget {
  final void Function([int? hskLevel])? onTestComplete;

  const PlacementTestIntroScreen({
    super.key,
    this.onTestComplete,
  });

  @override
  ConsumerState<PlacementTestIntroScreen> createState() => _PlacementTestIntroScreenState();
}

class _PlacementTestIntroScreenState extends ConsumerState<PlacementTestIntroScreen> {
  LearnerExperienceLevel _selectedExperience = LearnerExperienceLevel.zeroChinese;
  int _selectedHskLevel = 1;

  double _getInitialTheta() {
    switch (_selectedExperience) {
      case LearnerExperienceLevel.zeroChinese:
        return -1.0;
      case LearnerExperienceLevel.basicPinyin:
        return -0.5;
      case LearnerExperienceLevel.intermediate:
        return 0.5;
      case LearnerExperienceLevel.hasHsk:
        switch (_selectedHskLevel) {
          case 1:
            return -1.0;
          case 2:
            return -0.5;
          case 3:
            return 0.2;
          case 4:
            return 0.8;
          case 5:
            return 1.5;
          case 6:
            return 2.2;
          default:
            return -1.0;
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeSessionAsync = ref.watch(activeCatSessionProvider);
    final latestResultAsync = ref.watch(latestAssessmentResultProvider);

    final activeSession = activeSessionAsync.asData?.value;
    final latestResult = latestResultAsync.asData?.value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Khảo Sát Năng Lực Đầu Vào'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Kinh nghiệm học tiếng Trung của bạn:',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Chọn mức độ hiện tại để hệ thống tối ưu bài kiểm tra thích ứng hoặc chọn lộ trình xuất phát phù hợp nhất.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              ...LearnerExperienceLevel.values.map((exp) {
                final isSelected = _selectedExperience == exp;
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Material(
                    color: isSelected
                        ? AppColors.primaryBlueDark.withAlpha(25)
                        : AppColors.cardBackground,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? AppColors.primaryBlueDark : AppColors.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() => _selectedExperience = exp);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              exp.icon,
                              color: isSelected ? AppColors.primaryBlueDark : AppColors.mutedText,
                              size: 24,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    exp.title,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected ? AppColors.primaryBlueDark : null,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    exp.description,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked,
                              color: isSelected
                                  ? AppColors.primaryBlueDark
                                  : AppColors.mutedText,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),

              if (_selectedExperience == LearnerExperienceLevel.hasHsk) ...[
                const SizedBox(height: AppSpacing.sm),
                HiCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Chọn cấp độ HSK bạn đã đạt được:',
                        style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: 8,
                        children: List.generate(6, (index) {
                          final level = index + 1;
                          final isCurrent = _selectedHskLevel == level;
                          return ChoiceChip(
                            label: Text('HSK $level'),
                            selected: isCurrent,
                            onSelected: (val) {
                              if (val) setState(() => _selectedHskLevel = level);
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (widget.onTestComplete != null)
                        HiButton(
                          text: 'Xác nhận bắt đầu từ HSK $_selectedHskLevel',
                          icon: const Icon(Icons.check_circle_outline_rounded),
                          variant: HiButtonVariant.secondary,
                          isFullWidth: true,
                          onPressed: () => widget.onTestComplete?.call(_selectedHskLevel),
                        ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.lg),

              HiCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlueDark.withAlpha(30),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
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
                                'Khảo Sát Thích Ứng (CAT)',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tự động điều chỉnh độ khó theo 6 kỹ năng',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Bài kiểm tra ứng dụng mô hình Item Response Theory (IRT). Câu hỏi tiếp theo sẽ tự động tăng/giảm độ khó dựa trên kết quả trả lời thực tế của bạn, giúp xác định chuẩn xác điểm khởi đầu chỉ trong 12 - 20 câu.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text(
                '6 Kỹ Năng Được Khảo Sát',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildSkillItem(
                context,
                icon: Icons.menu_book_rounded,
                title: '1. Từ vựng',
                subtitle: 'Vốn từ, nhận diện nghĩa & kết hợp từ',
              ),
              _buildSkillItem(
                context,
                icon: Icons.account_tree_outlined,
                title: '2. Ngữ pháp',
                subtitle: 'Trật tự từ, câu chữ 把/被, liên từ & bổ ngữ',
              ),
              _buildSkillItem(
                context,
                icon: Icons.chrome_reader_mode_rounded,
                title: '3. Đọc hiểu',
                subtitle: 'Đọc hiểu đoạn văn ngữ cảnh ngắn',
              ),
              _buildSkillItem(
                context,
                icon: Icons.headphones_rounded,
                title: '4. Nghe hiểu',
                subtitle: 'Nhận diện phát âm & hội thoại ngắn',
              ),
              _buildSkillItem(
                context,
                icon: Icons.edit_note_rounded,
                title: '5. Kỹ năng Viết',
                subtitle: 'Phân tách: nhận diện chữ, nhập pinyin & thứ tự nét',
              ),
              _buildSkillItem(
                context,
                icon: Icons.mic_rounded,
                title: '6. Phát âm & Nói',
                subtitle: 'Phát âm mẫu & biến điệu (có thể bỏ qua nếu không tiện)',
              ),
              const SizedBox(height: AppSpacing.lg),

              if (activeSession != null && !activeSession.isCompleted) ...[
                HiCard(
                  borderColor: theme.colorScheme.primary,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.history_rounded, color: AppColors.primaryBlueDark),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Bạn có bài kiểm tra đang dang dở!',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Đã hoàn thành ${activeSession.stepIndex} câu hỏi. Bạn có thể tiếp tục ngay lập tức mà không mất dữ liệu.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: HiButton(
                              text: 'Tiếp tục bài test',
                              icon: const Icon(Icons.play_arrow_rounded),
                              variant: HiButtonVariant.primary,
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PlacementTestFlowScreen(
                                      onTestComplete: widget.onTestComplete,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          HiButton(
                            text: 'Bỏ qua',
                            variant: HiButtonVariant.ghost,
                            onPressed: () {
                              ref.read(activeCatSessionProvider.notifier).abandonSession();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              if (latestResult != null) ...[
                HiCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified_outlined, color: AppColors.primaryBlueDark),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'Kết Quả Bài Kiểm Tra Gần Nhất',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Cấp độ tham chiếu: ${latestResult.referenceHskBand}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      HiButton(
                        text: 'Xem lại kết quả & phân tích',
                        variant: HiButtonVariant.secondary,
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => PlacementTestResultScreen(
                                result: latestResult,
                                onContinue: widget.onTestComplete,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              HiButton(
                text: activeSession != null ? 'Bắt đầu bài kiểm tra mới' : 'Bắt đầu làm bài kiểm tra',
                icon: const Icon(Icons.arrow_forward_rounded),
                variant: HiButtonVariant.primary,
                size: HiButtonSize.lg,
                isFullWidth: true,
                onPressed: () async {
                  if (activeSession != null) {
                    await ref.read(activeCatSessionProvider.notifier).abandonSession();
                  }
                  await ref.read(activeCatSessionProvider.notifier).startNewTest(
                    initialTheta: _getInitialTheta(),
                  );
                  if (context.mounted) {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PlacementTestFlowScreen(
                          onTestComplete: widget.onTestComplete,
                        ),
                      ),
                    );
                    final updatedResult = ref.read(latestAssessmentResultProvider).asData?.value;
                    widget.onTestComplete?.call(updatedResult?.recommendedHskLevel);
                  }
                },
              ),
              if (widget.onTestComplete != null) ...[
                const SizedBox(height: AppSpacing.sm),
                HiButton(
                  text: 'Bỏ qua bài kiểm tra (Bắt đầu từ HSK 1)',
                  variant: HiButtonVariant.ghost,
                  isFullWidth: true,
                  onPressed: () => widget.onTestComplete?.call(1),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkillItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: AppDimensions.iconSm, color: AppColors.primaryBlueDark),
          const SizedBox(width: AppSpacing.sm),
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              '- $subtitle',
              style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
