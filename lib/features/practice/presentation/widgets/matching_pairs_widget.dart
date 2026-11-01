import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/practice_models.dart';

class MatchingPairsWidget extends StatefulWidget {
  final ExerciseDefinition definition;
  final Map<String, String> userPairs;
  final ScoringResult? result;
  final ValueChanged<Map<String, String>> onPairsChanged;

  const MatchingPairsWidget({
    super.key,
    required this.definition,
    required this.userPairs,
    this.result,
    required this.onPairsChanged,
  });

  @override
  State<MatchingPairsWidget> createState() => _MatchingPairsWidgetState();
}

class _MatchingPairsWidgetState extends State<MatchingPairsWidget> {
  String? _selectedLeft;
  late List<String> _leftList;
  late List<String> _rightList;

  @override
  void initState() {
    super.initState();
    // Shuffled once per widget mount
    final columns = widget.definition.getShuffledMatchingColumns();
    _leftList = columns['left']!;
    _rightList = columns['right']!;
  }

  void _onTapLeft(String left) {
    if (widget.result != null) return;
    setState(() {
      if (_selectedLeft == left) {
        _selectedLeft = null;
      } else {
        _selectedLeft = left;
      }
    });
  }

  void _onTapRight(String right) {
    if (widget.result != null) return;
    if (_selectedLeft == null) return;

    final updated = Map<String, String>.from(widget.userPairs);
    // If this right was already paired with another left, remove that previous pair
    updated.removeWhere((k, v) => v == right);
    // Assign new pair
    updated[_selectedLeft!] = right;

    setState(() {
      _selectedLeft = null;
    });

    widget.onPairsChanged(updated);
  }

  void _unpair(String left) {
    if (widget.result != null) return;
    final updated = Map<String, String>.from(widget.userPairs);
    updated.remove(left);
    widget.onPairsChanged(updated);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSubmitted = widget.result != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chọn từ ở cột trái rồi chọn nghĩa ở cột phải để nối:',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column
            Expanded(
              child: Column(
                children: _leftList.map((left) {
                  final isSelected = _selectedLeft == left;
                  final pairedRight = widget.userPairs[left];
                  final isPaired = pairedRight != null;

                  Color border = theme.colorScheme.outlineVariant.withAlpha(80);
                  Color bg = theme.colorScheme.surface;

                  if (isSubmitted) {
                    final isCorrect = widget.definition.matchingPairs[left] == pairedRight;
                    border = isCorrect ? AppColors.limeGreen : AppColors.errorLight;
                    bg = isCorrect ? AppColors.limeGreen.withAlpha(20) : AppColors.errorLight.withAlpha(20);
                  } else if (isSelected) {
                    border = AppColors.limeGreen;
                    bg = AppColors.limeGreen.withAlpha(25);
                  } else if (isPaired) {
                    border = theme.colorScheme.primary.withAlpha(150);
                    bg = theme.colorScheme.primary.withAlpha(15);
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: InkWell(
                      onTap: () => _onTapLeft(left),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: border, width: isSelected ? 2 : 1),
                        ),
                        child: Text(
                          left,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Right Column
            Expanded(
              child: Column(
                children: _rightList.map((right) {
                  final isPaired = widget.userPairs.values.contains(right);

                  Color border = theme.colorScheme.outlineVariant.withAlpha(80);
                  Color bg = theme.colorScheme.surface;

                  if (isSubmitted) {
                    // Check if this right matched the correct left
                    final pairedLeft = widget.userPairs.entries.firstWhere(
                      (e) => e.value == right,
                      orElse: () => const MapEntry('', ''),
                    ).key;
                    final isCorrect = widget.definition.matchingPairs[pairedLeft] == right;
                    border = isCorrect ? AppColors.limeGreen : AppColors.errorLight;
                    bg = isCorrect ? AppColors.limeGreen.withAlpha(20) : AppColors.errorLight.withAlpha(20);
                  } else if (isPaired) {
                    border = theme.colorScheme.primary.withAlpha(150);
                    bg = theme.colorScheme.primary.withAlpha(15);
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: InkWell(
                      onTap: () => _onTapRight(right),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: border),
                        ),
                        child: Text(
                          right,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: isPaired ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),

        // Display current pairs summary chips
        if (widget.userPairs.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: widget.userPairs.entries.map((entry) {
              return Chip(
                label: Text('${entry.key} ↔ ${entry.value}'),
                onDeleted: isSubmitted ? null : () => _unpair(entry.key),
                deleteIconColor: theme.colorScheme.outline,
                backgroundColor: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}
