import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/practice_models.dart';

class ReorderWordsWidget extends StatefulWidget {
  final ExerciseDefinition definition;
  final List<String> orderedTokens;
  final ScoringResult? result;
  final ValueChanged<List<String>> onTokensChanged;

  const ReorderWordsWidget({
    super.key,
    required this.definition,
    required this.orderedTokens,
    this.result,
    required this.onTokensChanged,
  });

  @override
  State<ReorderWordsWidget> createState() => _ReorderWordsWidgetState();
}

class _ReorderWordsWidgetState extends State<ReorderWordsWidget> {
  late List<String> _availableBank;

  @override
  void initState() {
    super.initState();
    _computeBank();
  }

  @override
  void didUpdateWidget(covariant ReorderWordsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderedTokens != widget.orderedTokens) {
      _computeBank();
    }
  }

  void _computeBank() {
    final allTokens = widget.definition.getShuffledTokens(seed: 42);
    final currentOrdered = List<String>.from(widget.orderedTokens);

    final bank = List<String>.from(allTokens);
    for (final t in currentOrdered) {
      bank.remove(t);
    }
    _availableBank = bank;
  }

  void _addToken(String token) {
    if (widget.result != null) return;
    final updated = List<String>.from(widget.orderedTokens)..add(token);
    widget.onTokensChanged(updated);
  }

  void _removeTokenAt(int index) {
    if (widget.result != null) return;
    final updated = List<String>.from(widget.orderedTokens)..removeAt(index);
    widget.onTokensChanged(updated);
  }

  void _reset() {
    if (widget.result != null) return;
    widget.onTokensChanged([]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSubmitted = widget.result != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Assembled Sentence Area
        Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(30),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSubmitted
                  ? (widget.result!.isCorrect ? AppColors.limeGreen : AppColors.errorLight)
                  : theme.colorScheme.outlineVariant,
              width: 1.5,
            ),
          ),
          child: widget.orderedTokens.isEmpty
              ? Center(
                  child: Text(
                    'Chạm vào các từ bên dưới để ghép câu...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                )
              : Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: List.generate(widget.orderedTokens.length, (idx) {
                    final token = widget.orderedTokens[idx];
                    return ActionChip(
                      label: Text(token, style: const TextStyle(fontWeight: FontWeight.bold)),
                      backgroundColor: AppColors.limeGreen.withAlpha(30),
                      onPressed: isSubmitted ? null : () => _removeTokenAt(idx),
                    );
                  }),
                ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Available Bank & Reset Button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Từ vựng có sẵn:',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (widget.orderedTokens.isNotEmpty && !isSubmitted)
              TextButton.icon(
                onPressed: _reset,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Làm lại'),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
          ],
        ),
        const SizedBox(height: 4),

        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: _availableBank.map((token) {
            return ActionChip(
              label: Text(token),
              backgroundColor: theme.colorScheme.surface,
              side: BorderSide(color: theme.colorScheme.outlineVariant),
              onPressed: isSubmitted ? null : () => _addToken(token),
            );
          }).toList(),
        ),
      ],
    );
  }
}
