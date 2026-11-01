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
    final isDark = theme.brightness == Brightness.dark;

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
                      ? AppColors.limeGreen.withAlpha(isDark ? 60 : 35)
                      : Colors.red.withAlpha(isDark ? 60 : 35),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Điểm: ${_score!.toStringAsFixed(0)}%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: _score! >= 70
                        ? (isDark ? AppColors.limeGreen : const Color(0xFF2E5B0E))
                        : Colors.red,
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

                    Color? tileColor;
                    if (_hasSubmitted) {
                      if (optIndex == q.answerIndex) {
                        tileColor = Colors.green.withAlpha(40);
                      } else if (isSelected && optIndex != q.answerIndex) {
                        tileColor = Colors.red.withAlpha(40);
                      }
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: tileColor ?? Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: RadioListTile<int>(
                        value: optIndex,
                        groupValue: selectedOption,
                        dense: true,
                        title: Text(
                          optText,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        onChanged: _hasSubmitted
                            ? null
                            : (val) {
                                if (val != null) {
                                  setState(() {
                                    _userAnswers[q.id] = val;
                                  });
                                }
                              },
                      ),
                    );
                  }),

                  // Explanation after submission
                  if (_hasSubmitted) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkForestSurface
                            : theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border(
                          left: BorderSide(
                            color: isCorrect ? AppColors.limeGreen : Colors.orange,
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
                                color: isCorrect ? AppColors.limeGreen : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isCorrect ? 'Đáp án chính xác' : 'Giải thích đáp án',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
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
