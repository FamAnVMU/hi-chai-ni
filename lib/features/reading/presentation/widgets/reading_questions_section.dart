import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/reading_models.dart';

/// Interactive comprehension questions widget for testing deep passage understanding.
class ReadingQuestionsSection extends StatefulWidget {
  final List<ReadingQuestion> questions;
  final Map<String, int> initialAnswers;
  final bool isSubmitted;
  final Function(Map<String, int> answers, double scorePercent) onSubmitted;
  final void Function(ReadingQuestion question)? onAskAiQuestion;

  const ReadingQuestionsSection({
    super.key,
    required this.questions,
    this.initialAnswers = const {},
    this.isSubmitted = false,
    required this.onSubmitted,
    this.onAskAiQuestion,
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
          final isAnswered = selectedOption != null || _hasSubmitted;
          final isCorrect = selectedOption == q.answerIndex;

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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlueLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Câu $qIndex',
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlueDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          q.question,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Options
                  ...q.options.asMap().entries.map((opt) {
                    final optIndex = opt.key;
                    final optText = opt.value;
                    final isSelected = selectedOption == optIndex;

                    Color cardBg = AppColors.cardBackground;
                    Color cardBorder = AppColors.border;
                    Color textColor = AppColors.primaryText;
                    IconData? statusIcon;
                    Color? iconColor;

                    if (isAnswered) {
                      if (optIndex == q.answerIndex) {
                        cardBg = AppColors.successContainerLight;
                        cardBorder = AppColors.success;
                        textColor = AppColors.success;
                        statusIcon = Icons.check_circle_rounded;
                        iconColor = AppColors.success;
                      } else if (isSelected) {
                        cardBg = AppColors.errorContainerLight;
                        cardBorder = AppColors.error;
                        textColor = AppColors.error;
                        statusIcon = Icons.cancel_rounded;
                        iconColor = AppColors.error;
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
                            width: isSelected || (isAnswered && optIndex == q.answerIndex) ? 1.5 : 1.0,
                          ),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          onTap: () {
                            setState(() {
                              _userAnswers[q.id] = optIndex;
                              _calculateScore();
                            });
                            widget.onSubmitted(_userAnswers, _score ?? 100.0);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                if (statusIcon != null)
                                  Icon(statusIcon, size: 18, color: iconColor)
                                else
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected ? AppColors.primaryBlueDark : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected ? AppColors.primaryBlueDark : AppColors.mutedText,
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
                                      fontWeight: isSelected || (isAnswered && optIndex == q.answerIndex)
                                          ? FontWeight.bold
                                          : FontWeight.normal,
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

                  // Immediate Explanation Box (C3 Comprehension Box)
                  if (isAnswered) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isCorrect
                            ? AppColors.successContainerLight.withAlpha(120)
                            : AppColors.warningContainerLight,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border(
                          left: BorderSide(
                            color: isCorrect ? AppColors.success : AppColors.warning,
                            width: 3.5,
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
                          const SizedBox(height: 6),

                          // Citation Highlight Box (màu vàng nổi bật)
                          if (q.citationText != null && q.citationText!.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF6E7),
                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                border: Border.all(color: AppColors.warning.withAlpha(140)),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.format_quote_rounded, size: 16, color: AppColors.warning),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Dẫn chứng trích đoạn bài đọc:',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.warning,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Trích dẫn: "${q.citationText!}"',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Vietnamese Explanation
                          Text(
                            q.explanationVi,
                            style: theme.textTheme.bodySmall?.copyWith(
                              height: 1.4,
                              color: AppColors.primaryText,
                            ),
                          ),

                          const SizedBox(height: AppSpacing.xs),

                          // Button: "Hỏi AI Tutor về câu này"
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                if (widget.onAskAiQuestion != null) {
                                  widget.onAskAiQuestion!(q);
                                } else {
                                  _showAiExplanationDialog(context, q);
                                }
                              },
                              icon: const Icon(Icons.smart_toy_outlined, size: 16, color: AppColors.primaryBlueDark),
                              label: const Text(
                                'Hỏi AI Tutor về câu này',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryBlueDark,
                                ),
                              ),
                            ),
                          ),
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

  void _showAiExplanationDialog(BuildContext context, ReadingQuestion q) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.smart_toy_outlined, color: AppColors.primaryBlueDark),
            SizedBox(width: 8),
            Text('Trợ Lý AI Đọc Hiểu'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Câu hỏi: ${q.question}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (q.citationText != null && q.citationText!.isNotEmpty) ...[
                Text(
                  'Dẫn chứng: "${q.citationText}"',
                  style: const TextStyle(color: AppColors.secondaryText, fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 8),
              ],
              Text(
                'Phân tích ngữ nghĩa & ngữ pháp:\n${q.explanationVi}\n\nMẹo sư phạm: Đối chiếu kỹ từ khóa trong câu hỏi với các câu đơn trong bài đọc để tránh bị bẫy bởi từ đồng âm/gần nghĩa.',
                style: const TextStyle(height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đã hiểu'),
          ),
        ],
      ),
    );
  }
}
