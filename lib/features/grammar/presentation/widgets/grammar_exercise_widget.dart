import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/engine/grammar_evaluation_engine.dart';
import '../../domain/models/grammar_models.dart';

/// Interactive widget presenting a grammar practice exercise with instant deterministic rubric evaluation.
class GrammarExerciseWidget extends StatefulWidget {
  final GrammarExercise exercise;
  final int exerciseIndex;
  final ValueChanged<ExerciseEvaluationResult> onEvaluated;

  const GrammarExerciseWidget({
    super.key,
    required this.exercise,
    required this.exerciseIndex,
    required this.onEvaluated,
  });

  @override
  State<GrammarExerciseWidget> createState() => _GrammarExerciseWidgetState();
}

class _GrammarExerciseWidgetState extends State<GrammarExerciseWidget> {
  final _engine = const GrammarEvaluationEngine();

  int? _selectedChoiceIndex;
  late List<String> _remainingTokens;
  final List<String> _selectedTokens = [];
  final _openTextController = TextEditingController();

  ExerciseEvaluationResult? _result;

  @override
  void initState() {
    super.initState();
    _remainingTokens = List.from(widget.exercise.shuffledTokens);
  }

  @override
  void dispose() {
    _openTextController.dispose();
    super.dispose();
  }

  void _handleEvaluate() {
    final eval = _engine.evaluate(
      exercise: widget.exercise,
      selectedOptionIndex: _selectedChoiceIndex,
      orderedTokens: _selectedTokens,
      openTextResponse: _openTextController.text,
    );

    setState(() {
      _result = eval;
    });

    widget.onEvaluated(eval);
  }

  void _handleReset() {
    setState(() {
      _selectedChoiceIndex = null;
      _selectedTokens.clear();
      _remainingTokens = List.from(widget.exercise.shuffledTokens);
      _openTextController.clear();
      _result = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ex = widget.exercise;

    return HiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlueDark.withAlpha(25),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'Bài ${widget.exerciseIndex + 1}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.primaryBlueDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  ex.prompt,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Exercise Type Specific UI
          if (ex.type == GrammarExerciseType.multipleChoice ||
              ex.type == GrammarExerciseType.fillInBlank ||
              ex.type == GrammarExerciseType.errorRecognition) ...[
            if (ex.sentenceWithBlank != null) ...[
              Text(
                ex.sentenceWithBlank!,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            ...List.generate(ex.options.length, (idx) {
              final opt = ex.options[idx];
              final isSelected = _selectedChoiceIndex == idx;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: InkWell(
                  onTap: _result != null ? null : () => setState(() => _selectedChoiceIndex = idx),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryBlueDark.withAlpha(30)
                          : theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      border: Border.all(
                        color: isSelected ? AppColors.primaryBlueDark : theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                          size: 18,
                          color: isSelected ? AppColors.primaryBlueDark : theme.colorScheme.outline,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          opt,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ] else if (ex.type == GrammarExerciseType.reorderWords) ...[
            // Assembled Tokens Slot
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 50),
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(70),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: _selectedTokens.isEmpty
                  ? Center(
                      child: Text(
                        'Chạm các từ bên dưới để ghép câu',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    )
                  : Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: _selectedTokens.map((tok) {
                        return ActionChip(
                          label: Text(tok, style: const TextStyle(fontWeight: FontWeight.bold)),
                          onPressed: _result != null
                              ? null
                              : () {
                                  setState(() {
                                    _selectedTokens.remove(tok);
                                    _remainingTokens.add(tok);
                                  });
                                },
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Remaining Tokens Pool
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: _remainingTokens.map((tok) {
                return ActionChip(
                  label: Text(tok),
                  onPressed: _result != null
                      ? null
                      : () {
                          setState(() {
                            _remainingTokens.remove(tok);
                            _selectedTokens.add(tok);
                          });
                        },
                );
              }).toList(),
            ),
          ] else if (ex.type == GrammarExerciseType.openTranslation) ...[
            HiTextField(
              controller: _openTextController,
              hintText: 'Nhập câu tiếng Trung của bạn...',
              enabled: _result == null,
            ),
          ],

          const SizedBox(height: AppSpacing.md),

          // Evaluation Result Banner
          if (_result != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: _result!.isCorrect
                    ? AppColors.primaryBlueDark.withAlpha(25)
                    : (_result!.needsHumanReview
                        ? Colors.orange.withAlpha(25)
                        : AppColors.errorLight.withAlpha(25)),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: _result!.isCorrect
                      ? AppColors.primaryBlueDark
                      : (_result!.needsHumanReview ? Colors.orange : AppColors.errorLight),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: AppSpacing.xs,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _result!.isCorrect
                                ? Icons.check_circle_rounded
                                : (_result!.needsHumanReview
                                    ? Icons.help_outline_rounded
                                    : Icons.cancel_rounded),
                            size: 18,
                            color: _result!.isCorrect
                                ? AppColors.primaryBlueDark
                                : (_result!.needsHumanReview ? Colors.orange : AppColors.errorLight),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            _result!.isCorrect
                                ? 'Chính xác (${(_result!.score * 100).toInt()}%)'
                                : (_result!.needsHumanReview
                                    ? 'Cần xem lại kết quả'
                                    : 'Chưa đúng'),
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _result!.isCorrect
                                  ? AppColors.primaryBlueDark
                                  : (_result!.needsHumanReview ? Colors.orange : AppColors.errorLight),
                            ),
                          ),
                        ],
                      ),
                      if (_result!.confidence >= 0.8 && !_result!.needsHumanReview)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primaryBlueDark.withAlpha(30),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            'Tự động đạt chuẩn',
                            style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                          ),
                        )
                      else if (_result!.needsHumanReview)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange.withAlpha(30),
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Text(
                            'Độ tin cậy vừa (${(_result!.confidence * 100).toInt()}%)',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 10,
                              color: Colors.orange,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _result!.feedbackVi,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],

          // Action Buttons
          Row(
            children: [
              if (_result == null)
                Expanded(
                  child: HiButton(
                    text: 'Kiểm tra đáp án',
                    size: HiButtonSize.sm,
                    variant: HiButtonVariant.primary,
                    icon: const Icon(Icons.check_rounded, size: 16),
                    onPressed: _handleEvaluate,
                  ),
                )
              else ...[
                Expanded(
                  child: HiButton(
                    text: 'Làm lại',
                    size: HiButtonSize.sm,
                    variant: HiButtonVariant.secondary,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    onPressed: _handleReset,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
