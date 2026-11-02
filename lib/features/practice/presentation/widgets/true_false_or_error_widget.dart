import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/practice_models.dart';

class TrueFalseOrErrorWidget extends StatelessWidget {
  final ExerciseDefinition definition;
  final bool? userBool;
  final String? selectedErrorToken;
  final ScoringResult? result;
  final ValueChanged<bool> onSelectBool;
  final ValueChanged<String> onSelectErrorToken;

  const TrueFalseOrErrorWidget({
    super.key,
    required this.definition,
    this.userBool,
    this.selectedErrorToken,
    this.result,
    required this.onSelectBool,
    required this.onSelectErrorToken,
  });

  @override
  Widget build(BuildContext context) {
    final isErrorDetection = definition.errorToken != null && definition.errorToken!.isNotEmpty;

    if (isErrorDetection) {
      return _buildErrorDetection(context);
    } else {
      return _buildTrueFalse(context);
    }
  }

  Widget _buildTrueFalse(BuildContext context) {
    final isSubmitted = result != null;

    return Row(
      children: [
        // Đúng Button
        Expanded(
          child: _buildChoiceButton(
            context,
            label: 'Đúng (正确)',
            icon: Icons.check_circle_outline_rounded,
            isSelected: userBool == true,
            isTarget: definition.isTrue == true,
            isSubmitted: isSubmitted,
            onTap: () => onSelectBool(true),
          ),
        ),
        const SizedBox(width: AppSpacing.md),

        // Sai Button
        Expanded(
          child: _buildChoiceButton(
            context,
            label: 'Sai (错误)',
            icon: Icons.cancel_outlined,
            isSelected: userBool == false,
            isTarget: definition.isTrue == false,
            isSubmitted: isSubmitted,
            onTap: () => onSelectBool(false),
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isTarget,
    required bool isSubmitted,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    Color border = AppColors.border;
    Color bg = AppColors.cardBackground;
    Color textColor = AppColors.primaryText;

    if (isSubmitted) {
      if (isTarget) {
        border = AppColors.success;
        bg = AppColors.successContainerLight;
        textColor = AppColors.success;
      } else if (isSelected && !result!.isCorrect) {
        border = AppColors.error;
        bg = AppColors.errorContainerLight;
        textColor = AppColors.error;
      }
    } else if (isSelected) {
      border = AppColors.primaryBlueDark;
      bg = AppColors.primaryBlueLight;
      textColor = AppColors.primaryBlueDark;
    }

    return InkWell(
      onTap: isSubmitted ? null : onTap,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: border, width: isSelected ? 2.0 : 1.0),
        ),
        child: Column(
          children: [
            Icon(icon, color: textColor, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorDetection(BuildContext context) {
    final theme = Theme.of(context);
    final isSubmitted = result != null;
    final text = definition.stimulus ?? definition.sentenceWithBlank ?? '';

    // Split into segments/tokens roughly by space or Chinese punctuation
    final tokens = text.split(RegExp(r'(?<=\s)|(?<=\p{P})|(?=\p{P})', unicode: true)).where((s) => s.trim().isNotEmpty).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Chạm vào từ/cụm từ bị sai ngữ pháp trong câu:',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: tokens.map((token) {
            final isSelected = selectedErrorToken == token;
            final isTargetError = definition.errorToken == token;

            Color chipBg = AppColors.cardBackground;
            Color chipBorder = AppColors.border;

            if (isSubmitted) {
              if (isTargetError) {
                chipBg = AppColors.successContainerLight;
                chipBorder = AppColors.success;
              } else if (isSelected && !result!.isCorrect) {
                chipBg = AppColors.errorContainerLight;
                chipBorder = AppColors.error;
              }
            } else if (isSelected) {
              chipBg = AppColors.primaryBlueLight;
              chipBorder = AppColors.primaryBlueDark;
            }

            return ActionChip(
              label: Text(
                token,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  decoration: isSelected ? TextDecoration.underline : TextDecoration.none,
                ),
              ),
              backgroundColor: chipBg,
              side: BorderSide(color: chipBorder),
              onPressed: isSubmitted ? null : () => onSelectErrorToken(token),
            );
          }).toList(),
        ),
      ],
    );
  }
}
