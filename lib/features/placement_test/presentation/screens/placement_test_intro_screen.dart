import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../providers/placement_test_providers.dart';
import 'placement_test_flow_screen.dart';
import 'placement_test_result_screen.dart';

/// Screen introducing the Computerized Adaptive Placement Test (CAT),
/// showing past results if available, and allowing resume of in-progress test.
class PlacementTestIntroScreen extends ConsumerWidget {
  final void Function([int? hskLevel])? onTestComplete;

  const PlacementTestIntroScreen({
    super.key,
    this.onTestComplete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              // 1. Overview Banner
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

              // 2. Six Assessed Skills Grid
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

              // 3. Resume in-progress session if exists
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
                                    builder: (_) => const PlacementTestFlowScreen(),
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

              // 4. View Latest Completed Result if exists
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
                              builder: (_) => PlacementTestResultScreen(result: latestResult),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              // 5. Start Fresh Button
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
                  await ref.read(activeCatSessionProvider.notifier).startNewTest();
                  if (context.mounted) {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PlacementTestFlowScreen(),
                      ),
                    );
                    final updatedResult = ref.read(latestAssessmentResultProvider).asData?.value;
                    onTestComplete?.call(updatedResult?.recommendedHskLevel);
                  }
                },
              ),
              if (onTestComplete != null) ...[
                const SizedBox(height: AppSpacing.sm),
                HiButton(
                  text: 'Bỏ qua bài kiểm tra (Bắt đầu từ HSK 1)',
                  variant: HiButtonVariant.ghost,
                  isFullWidth: true,
                  onPressed: () => onTestComplete?.call(1),
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
