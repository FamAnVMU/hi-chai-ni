import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/curriculum_models.dart';

class LessonPracticeView extends StatefulWidget {
  final CurriculumLesson lesson;
  final LessonSegment? segment;
  final Function(String questionId, dynamic answer)? onAnswerRecorded;
  final VoidCallback? onNext;
  final VoidCallback? onAskAi;

  const LessonPracticeView({
    super.key,
    required this.lesson,
    this.segment,
    this.onAnswerRecorded,
    this.onNext,
    this.onAskAi,
  });

  @override
  State<LessonPracticeView> createState() => _LessonPracticeViewState();
}

class _LessonPracticeViewState extends State<LessonPracticeView> {
  int _currentIndex = 0;
  final Map<String, String> _selectedAnswers = {};
  final Map<String, bool> _submittedStatus = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rawExercises = (widget.segment?.contentPayload?['exercises'] as List<dynamic>?) ?? [];
    final exercises = rawExercises.map((e) => e as Map<String, dynamic>).toList();

    if (exercises.isEmpty) {
      return Center(
        child: Text(
          'Đang nạp các bài tập luyện tập...',
          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondaryText),
        ),
      );
    }

    final currentExercise = exercises[_currentIndex];
    final qId = (currentExercise['id'] ?? 'ex_$_currentIndex') as String;
    final prompt = (currentExercise['prompt'] ?? '') as String;
    final rawOptions = (currentExercise['options'] as List<dynamic>?) ?? [];
    final options = rawOptions.map((e) => e.toString()).toList();
    final correctAnswer = currentExercise['correct_answer']?.toString() ?? '';
    final explanation = (currentExercise['explanation'] ?? '') as String;

    final selected = _selectedAnswers[qId];
    final isSubmitted = _submittedStatus[qId] == true;
    final isCorrect = selected == correctAnswer;

    return SingleChildScrollView(
      padding: AppSpacing.screenPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step progress indicator inside practice
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Luyện tập thích ứng',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText,
                ),
              ),
              Text(
                'Câu ${_currentIndex + 1}/${exercises.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          LinearProgressIndicator(
            value: (_currentIndex + 1) / exercises.length,
            backgroundColor: AppColors.primaryBlueLight,
            color: AppColors.primaryBlueDark,
            minHeight: 4,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Question Card
          HiCard(
            backgroundColor: AppColors.cardBackground,
            borderColor: AppColors.border,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlueLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    (currentExercise['skill_type'] ?? 'reading').toString().toUpperCase(),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlueDark,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  prompt,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    height: 1.4,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Options List
          ...options.map((opt) {
            final isChosen = selected == opt;
            Color borderColor = AppColors.border;
            Color bgColor = AppColors.cardBackground;

            if (isSubmitted) {
              if (opt == correctAnswer) {
                borderColor = AppColors.success;
                bgColor = AppColors.successContainerLight;
              } else if (isChosen && !isCorrect) {
                borderColor = AppColors.error;
                bgColor = AppColors.errorContainerLight;
              }
            } else if (isChosen) {
              borderColor = AppColors.primaryBlueDark;
              bgColor = AppColors.primaryBlueLight;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: InkWell(
                onTap: isSubmitted
                    ? null
                    : () {
                        setState(() {
                          _selectedAnswers[qId] = opt;
                        });
                        widget.onAnswerRecorded?.call(qId, opt);
                      },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: borderColor,
                      width: isChosen ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isChosen ? borderColor : AppColors.mutedText,
                            width: 2,
                          ),
                          color: isChosen ? borderColor : Colors.transparent,
                        ),
                        child: isChosen
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          opt,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: isChosen ? FontWeight.bold : FontWeight.normal,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),

          // Check Answer or Explanation
          if (!isSubmitted) ...[
            const SizedBox(height: AppSpacing.md),
            HiButton(
              text: 'Kiểm tra đáp án',
              isFullWidth: true,
              onPressed: selected == null
                  ? null
                  : () {
                      setState(() {
                        _submittedStatus[qId] = true;
                      });
                    },
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isCorrect ? AppColors.successContainerLight : AppColors.errorContainerLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCorrect ? AppColors.success : AppColors.error,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
                        color: isCorrect ? AppColors.success : AppColors.error,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          isCorrect ? 'Chính xác!' : 'Chưa chính xác! (Đáp án: $correctAnswer)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isCorrect ? AppColors.success : AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (explanation.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Giải thích: $explanation',
                      style: theme.textTheme.bodySmall?.copyWith(
                        height: 1.4,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ],
                  if (!isCorrect && widget.onAskAi != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: widget.onAskAi,
                        icon: const Icon(Icons.psychology_outlined, size: 16, color: AppColors.primaryBlueDark),
                        label: const Text(
                          'Hỏi AI vì sao sai',
                          style: TextStyle(color: AppColors.primaryBlueDark, fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (_currentIndex < exercises.length - 1)
              HiButton(
                text: 'Câu tiếp theo',
                variant: HiButtonVariant.primary,
                isFullWidth: true,
                onPressed: () {
                  setState(() {
                    _currentIndex++;
                  });
                },
              )
            else
              HiButton(
                text: 'Hoàn thành phần luyện tập',
                variant: HiButtonVariant.primary,
                isFullWidth: true,
                onPressed: widget.onNext,
              ),
          ],
        ],
      ),
    );
  }
}
