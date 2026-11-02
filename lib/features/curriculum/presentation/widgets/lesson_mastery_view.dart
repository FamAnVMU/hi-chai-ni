import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/curriculum_models.dart';

class LessonMasteryView extends StatefulWidget {
  final CurriculumLesson lesson;
  final LessonSegment? segment;
  final Function(List<Map<String, dynamic>> questions)? onSubmit;
  final VoidCallback? onFinishLesson;

  const LessonMasteryView({
    super.key,
    required this.lesson,
    this.segment,
    this.onSubmit,
    this.onFinishLesson,
  });

  @override
  State<LessonMasteryView> createState() => _LessonMasteryViewState();
}

class _LessonMasteryViewState extends State<LessonMasteryView> {
  final Map<String, String> _userAnswers = {};
  bool _isSubmitted = false;
  double _scorePercent = 0.0;
  int _correctCount = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rawExercises = (widget.segment?.contentPayload?['exercises'] as List<dynamic>?) ?? [];
    final exercises = rawExercises.map((e) => e as Map<String, dynamic>).toList();

    if (exercises.isEmpty) {
      return Center(
        child: Text(
          'Đang nạp bài kiểm tra hoàn thành...',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),
        ),
      );
    }

    if (_isSubmitted) {
      final isPassed = _scorePercent >= 0.8;

      return SingleChildScrollView(
        padding: AppSpacing.screenPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: isPassed ? AppColors.successContainerLight : AppColors.errorContainerLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPassed ? Icons.emoji_events_rounded : Icons.replay_rounded,
                  size: 64,
                  color: isPassed ? AppColors.success : AppColors.error,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              isPassed ? 'Chúc Mừng Bạn Đã Vượt Qua!' : 'Cần Ôn Tập Thêm',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: isPassed ? AppColors.success : AppColors.error,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Điểm số: ${(_scorePercent * 100).toInt()}% ($_correctCount/${exercises.length} câu đúng)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            HiCard(
              backgroundColor: AppColors.cardBackground,
              borderColor: AppColors.border,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPassed ? 'Đạt chuẩn đầu ra' : 'Chưa đạt chuẩn đầu ra (Yêu cầu ≥ 80%)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    isPassed
                        ? 'Toàn bộ từ vựng và ngữ pháp của bài học đã được tự động đưa vào hệ thống lặp lại ngắt quãng (SRS) để ôn tập định kỳ.'
                        : 'Bạn nên xem lại phần từ vựng và điểm ngữ pháp của bài học trước khi thử làm lại bài kiểm tra.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            if (isPassed)
              HiButton(
                text: 'Hoàn thành bài học',
                isFullWidth: true,
                variant: HiButtonVariant.primary,
                size: HiButtonSize.lg,
                onPressed: widget.onFinishLesson ?? () => Navigator.of(context).pop(true),
              )
            else
              HiButton(
                text: 'Làm lại bài kiểm tra',
                isFullWidth: true,
                variant: HiButtonVariant.secondary,
                onPressed: () {
                  setState(() {
                    _isSubmitted = false;
                    _userAnswers.clear();
                  });
                },
              ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, color: AppColors.primaryBlueDark),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Đánh giá hoàn thành',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Trả lời đúng tối thiểu 80% để mở khóa bài học tiếp theo.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          ...exercises.asMap().entries.map((entry) {
            final idx = entry.key;
            final ex = entry.value;
            final qId = (ex['id'] ?? 'ex_m_$idx') as String;
            final prompt = (ex['prompt'] ?? '') as String;
            final rawOptions = (ex['options'] as List<dynamic>?) ?? [];
            final options = rawOptions.map((e) => e.toString()).toList();
            final selected = _userAnswers[qId];

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: HiCard(
                backgroundColor: AppColors.cardBackground,
                borderColor: AppColors.border,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Câu ${idx + 1}: $prompt',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ...options.map((opt) {
                      final isChosen = selected == opt;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _userAnswers[qId] = opt;
                            });
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: isChosen ? AppColors.primaryBlueLight : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isChosen ? AppColors.primaryBlueDark : AppColors.border,
                                width: isChosen ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isChosen ? Icons.radio_button_checked : Icons.radio_button_off,
                                  size: 18,
                                  color: isChosen ? AppColors.primaryBlueDark : AppColors.mutedText,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    opt,
                                    style: TextStyle(
                                      color: isChosen ? AppColors.primaryBlueDark : AppColors.primaryText,
                                      fontWeight: isChosen ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: AppSpacing.md),
          HiButton(
            text: 'Nộp bài kiểm tra',
            isFullWidth: true,
            size: HiButtonSize.lg,
            onPressed: _userAnswers.length < exercises.length
                ? null
                : () {
                    int correct = 0;
                    for (final ex in exercises) {
                      final qId = ex['id']?.toString() ?? '';
                      if (_userAnswers[qId] == ex['correct_answer']?.toString()) {
                        correct++;
                      }
                    }
                    setState(() {
                      _correctCount = correct;
                      _scorePercent = exercises.isNotEmpty ? correct / exercises.length : 0.0;
                      _isSubmitted = true;
                    });
                    widget.onSubmit?.call(exercises);
                  },
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }
}
