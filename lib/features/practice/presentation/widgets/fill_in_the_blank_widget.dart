import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/practice_models.dart';

class FillInTheBlankWidget extends StatefulWidget {
  final ExerciseDefinition definition;
  final String currentAnswer;
  final ScoringResult? result;
  final ValueChanged<String> onAnswerChanged;

  const FillInTheBlankWidget({
    super.key,
    required this.definition,
    required this.currentAnswer,
    this.result,
    required this.onAnswerChanged,
  });

  @override
  State<FillInTheBlankWidget> createState() => _FillInTheBlankWidgetState();
}

class _FillInTheBlankWidgetState extends State<FillInTheBlankWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentAnswer);
  }

  @override
  void didUpdateWidget(covariant FillInTheBlankWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentAnswer != widget.currentAnswer && _controller.text != widget.currentAnswer) {
      _controller.text = widget.currentAnswer;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sentence = widget.definition.sentenceWithBlank ?? widget.definition.stimulus ?? '';
    final isSubmitted = widget.result != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sentence with highlighted blank
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(40),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Text(
            sentence.replaceAll('___', '[  ${widget.currentAnswer.isEmpty ? "___" : widget.currentAnswer}  ]'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),

        // If blank options (word bank) provided: render clickable chips
        if (widget.definition.blankOptions.isNotEmpty) ...[
          Text(
            'Chọn từ thích hợp điền vào chỗ trống:',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: widget.definition.blankOptions.map((opt) {
              final isSelected = widget.currentAnswer == opt;
              return ChoiceChip(
                label: Text(opt),
                selected: isSelected,
                onSelected: isSubmitted
                    ? null
                    : (selected) {
                        final val = selected ? opt : '';
                        _controller.text = val;
                        widget.onAnswerChanged(val);
                      },
                selectedColor: AppColors.primaryBlueDark.withAlpha(40),
                backgroundColor: theme.colorScheme.surface,
              );
            }).toList(),
          ),
        ] else ...[
          // Freeform text entry
          TextField(
            controller: _controller,
            enabled: !isSubmitted,
            decoration: InputDecoration(
              hintText: 'Nhập từ tiếng Trung điền vào chỗ trống...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: isSubmitted ? null : () {
                  _controller.clear();
                  widget.onAnswerChanged('');
                },
              ),
            ),
            onChanged: widget.onAnswerChanged,
          ),
        ],
      ],
    );
  }
}
