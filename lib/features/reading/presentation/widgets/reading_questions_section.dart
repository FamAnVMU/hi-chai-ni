import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/reading_models.dart';

/// Interactive comprehension questions widget for testing deep passage understanding.
class ReadingQuestionsSection extends StatefulWidget {
  final List<ReadingQuestion> questions;
  final Map<String, int> initialAnswers;
  final bool isSubmitted;
  final Function(Map<String, int> answers, double scorePercent) onSubmitted;

  const ReadingQuestionsSection({
    super.key,
    required this.questions,
    this.initialAnswers = const {},
    this.isSubmitted = false,
    required this.onSubmitted,
  });

  @override
  State<ReadingQuestionsSection> createState() => _ReadingQuestionsSectionState();
}

class _ReadingQuestionsSectionState extends State<ReadingQuestionsSection> {
  late Map<String, int> _userAnswers;
  late bool _hasSubmitted;
  double? _score;

  @override
  void initState() {
    super.initState();
    _userAnswers = Map<String, int>.from(widget.initialAnswers);
    _hasSubmitted = widget.isSubmitted;
    if (_hasSubmitted) {
      _calculateScore();
    }
  }

  void _calculateScore() {
    if (widget.questions.isEmpty) {
      _score = 100.0;
      return;
    }
    int correctCount = 0;
    for (final q in widget.questions) {
      if (_userAnswers[q.id] == q.answerIndex) {
        correctCount++;
      }
    }
    _score = (correctCount / widget.questions.length) * 100.0;
  }

  void _handleSubmit() {
    _calculateScore();
    setState(() {
      _hasSubmitted = true;
    });
    widget.onSubmitted(_userAnswers, _score ?? 100.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.questions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Câu Hỏi Đọc Hiểu',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_hasSubmitted && _score != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _score! >= 70
                      ? AppColors.successContainerLight
                      : AppColors.errorContainerLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _score! >= 70 ? AppColors.success : AppColors.error,
                    width: 1,
                  ),
                ),
                child: Text(
                  'Điểm: ${_score!.toStringAsFixed(0)}%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _score! >= 70 ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        ...widget.questions.asMap().entries.map((entry) {
          final qIndex = entry.key + 1;
          final q = entry.value;
          final selectedOption = _userAnswers[q.id];
          final isCorrect = _hasSubmitted && selectedOption == q.answerIndex;

          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: HiCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question Title
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Câu $qIndex: ',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          q.question,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Options
                  ...q.options.asMap().entries.map((opt) {
                    final optIndex = opt.key;
                    final optText = opt.value;
                    final isSelected = selectedOption == optIndex;

                    Color cardBg = AppColors.cardBackground;
                    Color cardBorder = AppColors.border;
                    Color textColor = AppColors.primaryText;

                    if (_hasSubmitted) {
                      if (optIndex == q.answerIndex) {
                        cardBg = AppColors.successContainerLight;
                        cardBorder = AppColors.success;
                        textColor = AppColors.success;
                      } else if (isSelected) {
                        cardBg = AppColors.errorContainerLight;
                        cardBorder = AppColors.error;
                        textColor = AppColors.error;
                      }
                    } else if (isSelected) {
                      cardBg = AppColors.primaryBlueLight;
                      cardBorder = AppColors.primaryBlueDark;
                      textColor = AppColors.primaryBlueDark;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Material(
                        color: cardBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          side: BorderSide(
                            color: cardBorder,
                            width: isSelected || (_hasSubmitted && optIndex == q.answerIndex) ? 1.5 : 1.0,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          onTap: _hasSubmitted
                              ? null
                              : () {
                                  setState(() {
                                    _userAnswers[q.id] = optIndex;
                                  });
                                },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected ? cardBorder : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected ? cardBorder : AppColors.mutedText,
                                      width: 2,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check, size: 12, color: Colors.white)
                                      : null,
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    optText,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),

                  // Explanation after submission
                  if (_hasSubmitted) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? AppColors.successContainerLight.withAlpha(120)
                            : AppColors.warningContainerLight,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border(
                          left: BorderSide(
                            color: isCorrect ? AppColors.success : AppColors.warning,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isCorrect ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                size: 16,
                                color: isCorrect ? AppColors.success : AppColors.warning,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isCorrect ? 'Đáp án chính xác' : 'Giải thích đáp án',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isCorrect ? AppColors.success : AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            q.explanationVi,
                            style: theme.textTheme.bodySmall,
                          ),
                          if (q.citationText != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Trích dẫn: "${q.citationText!}"',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontStyle: FontStyle.italic,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),

        // Submit Button
        if (!_hasSubmitted) ...[
          const SizedBox(height: AppSpacing.sm),
          HiButton(
            text: 'Nộp bài kiểm tra đọc hiểu',
            icon: const Icon(Icons.check_rounded, size: 18),
            isFullWidth: true,
            onPressed: _userAnswers.length == widget.questions.length
                ? _handleSubmit
                : () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Vui lòng trả lời đầy đủ tất cả câu hỏi trước khi nộp bài.'),
                      ),
                    );
                  },
          ),
        ],
      ],
    );
  }
}
