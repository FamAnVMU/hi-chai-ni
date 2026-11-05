import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/stroke_models.dart';

/// Bottom modal sheet presenting the objective evaluation of Chinese stroke order.
class WritingEvaluationSheet extends StatelessWidget {
  final WritingEvaluationResult result;
  final VoidCallback onRetry;
  final VoidCallback onSaveAndClose;

  const WritingEvaluationSheet({
    super.key,
    required this.result,
    required this.onRetry,
    required this.onSaveAndClose,
  });

  static Future<void> show({
    required BuildContext context,
    required WritingEvaluationResult result,
    required VoidCallback onRetry,
    required VoidCallback onSaveAndClose,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WritingEvaluationSheet(
        result: result,
        onRetry: onRetry,
        onSaveAndClose: onSaveAndClose,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = result.scorePercent;
    final isSuccess = result.isPassed;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        boxShadow: AppElevation.shadowHigh(theme.brightness),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: AppRadius.borderFull,
                  ),
                ),
              ),

              // Score Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (result.hasStandardStrokeData) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: isSuccess
                                ? AppColors.primaryBlueDark.withAlpha(40)
                                : theme.colorScheme.error.withAlpha(40),
                            borderRadius: AppRadius.borderMd,
                            border: Border.all(
                              color: isSuccess ? AppColors.primaryBlueDark : theme.colorScheme.error,
                            ),
                          ),
                          child: Text(
                            '$score%',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isSuccess ? AppColors.primaryBlueDark : theme.colorScheme.error,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isSuccess ? 'Đạt tiêu chuẩn nét' : 'Cần điều chỉnh nét',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              result.isTracingMode ? 'Chế độ tô theo mẫu' : 'Chế độ tự viết',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlueLight,
                            borderRadius: AppRadius.borderMd,
                            border: Border.all(color: AppColors.secondaryBlue),
                          ),
                          child: const Icon(
                            Icons.draw_rounded,
                            color: AppColors.primaryBlueDark,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Luyện viết tự do',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Không đánh giá nét chuẩn',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  if (result.hasStandardStrokeData)
                    HiChip(
                      label: '${result.correctStrokeCount}/${result.totalStandardStrokes} nét đúng',
                      status: isSuccess ? HiChipStatus.success : HiChipStatus.warning,
                    )
                  else
                    const HiChip(
                      label: 'Chế độ Luyện viết Tự do',
                      status: HiChipStatus.info,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Overall Verdict
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                  borderRadius: AppRadius.borderMd,
                ),
                child: Text(
                  result.overallVerdict,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Feedback Breakdown for Each Stroke
              Text(
                'Chi tiết từng nét bút:',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),

              ...result.strokeFeedbackList.map((feedback) {
                final isNegative = feedback.contains('ngược') ||
                    feedback.contains('lệch') ||
                    feedback.contains('thiếu') ||
                    feedback.contains('thừa');

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isNegative ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                        size: 16,
                        color: isNegative ? Colors.orangeAccent : AppColors.primaryBlueDark,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          feedback,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isNegative
                                ? theme.colorScheme.onSurface
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: AppSpacing.md),

              // Methodological Disclaimer
              Text(
                result.hasStandardStrokeData
                    ? 'Ghi chú: Đánh giá dựa trên hướng vector và thứ tự nét bút thuận theo quy chuẩn GB/T 13000, không so sánh nhận dạng chữ thô.'
                    : 'Ghi chú: Chữ Hán này đang ở chế độ luyện viết tự do do chưa có dữ liệu nét chuẩn GB/T 13000. Hệ thống không chấm điểm thứ tự nét.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: HiButton(
                      text: 'Viết lại',
                      variant: HiButtonVariant.secondary,
                      onPressed: () {
                        Navigator.of(context).pop();
                        onRetry();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: HiButton(
                      text: result.hasStandardStrokeData ? 'Lưu kết quả' : 'Tiếp tục luyện tập',
                      variant: HiButtonVariant.primary,
                      onPressed: () {
                        Navigator.of(context).pop();
                        onSaveAndClose();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
