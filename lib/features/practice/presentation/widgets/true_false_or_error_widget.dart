import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/practice_models.dart';

class TrueFalseOrErrorWidget extends StatefulWidget {
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
  State<TrueFalseOrErrorWidget> createState() => _TrueFalseOrErrorWidgetState();
}

class _TrueFalseOrErrorWidgetState extends State<TrueFalseOrErrorWidget> {
  int? _selectedTokenIndex;

  @override
  void didUpdateWidget(covariant TrueFalseOrErrorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.definition.id != widget.definition.id ||
        widget.selectedErrorToken == null) {
      _selectedTokenIndex = null;
    }
  }

  ExerciseDefinition get definition => widget.definition;
  bool? get userBool => widget.userBool;
  String? get selectedErrorToken => widget.selectedErrorToken;
  ScoringResult? get result => widget.result;
  ValueChanged<bool> get onSelectBool => widget.onSelectBool;
  ValueChanged<String> get onSelectErrorToken => widget.onSelectErrorToken;

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

    Color border = context.hiBorderColor;
    Color bg = context.hiCardSurface;
    Color textColor = context.hiPrimaryText;

    if (isSubmitted) {
      if (isTarget) {
        border = context.hiSuccessFg;
        bg = context.hiSuccessBg;
        textColor = context.hiSuccessFg;
      } else if (isSelected && !result!.isCorrect) {
        border = context.hiErrorFg;
        bg = context.hiErrorBg;
        textColor = context.hiErrorFg;
      }
    } else if (isSelected) {
      border = context.hiAccentColor;
      bg = context.hiAccentBg;
      textColor = context.hiAccentColor;
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

    // Prefer tokens provided by seed catalog / definition
    List<String> rawTokens;
    if (definition.tokens.isNotEmpty) {
      rawTokens = List<String>.from(definition.tokens);
      final lastPunctMatch = RegExp(r'[\p{P}]+$', unicode: true).firstMatch(text);
      if (lastPunctMatch != null) {
        final trailingPunct = lastPunctMatch.group(0)!;
        final lastToken = rawTokens.last;
        if (!lastToken.endsWith(trailingPunct) && !rawTokens.contains(trailingPunct)) {
          rawTokens.add(trailingPunct);
        }
      }
    } else {
      // Split into segments/tokens roughly by space or punctuation
      rawTokens = text
          .split(RegExp(r'(?<=\s)|(?<=\p{P})|(?=\p{P})', unicode: true))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    final punctuationRegex = RegExp(r'^[\p{P}\s]+$', unicode: true);
    final cleanTargetError = (definition.errorToken ?? '').replaceAll(RegExp(r'[\p{P}\s]', unicode: true), '');
    final cleanSelected = (selectedErrorToken ?? '').replaceAll(RegExp(r'[\p{P}\s]', unicode: true), '');
    final explicitTargetIndex = (definition.metadata['error_token_index'] as num?)?.toInt();

    int? fallbackSelectedIdx;
    if (_selectedTokenIndex == null && selectedErrorToken != null) {
      for (int i = 0; i < rawTokens.length; i++) {
        if (punctuationRegex.hasMatch(rawTokens[i])) continue;
        final cleanTok = rawTokens[i].replaceAll(RegExp(r'[\p{P}\s]', unicode: true), '');
        if (rawTokens[i] == selectedErrorToken ||
            (cleanSelected.isNotEmpty && cleanTok == cleanSelected)) {
          fallbackSelectedIdx = i;
          break;
        }
      }
    }
    final activeSelectedIndex = _selectedTokenIndex ?? fallbackSelectedIdx;

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
          crossAxisAlignment: WrapCrossAlignment.center,
          children: List.generate(rawTokens.length, (idx) {
            final token = rawTokens[idx];
            final isPunctuation = punctuationRegex.hasMatch(token);
            if (isPunctuation) {
              return Text(
                token,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              );
            }

            final cleanToken = token.replaceAll(RegExp(r'[\p{P}\s]', unicode: true), '');
            final isSelected = activeSelectedIndex == idx;
            final isTargetError = explicitTargetIndex != null
                ? idx == explicitTargetIndex
                : (definition.errorToken == token ||
                    (cleanTargetError.isNotEmpty && cleanToken == cleanTargetError));

            Color chipBg = context.hiCardSurface;
            Color chipBorder = context.hiBorderColor;
            Color chipText = context.hiPrimaryText;

            if (isSubmitted) {
              if (isTargetError) {
                chipBg = context.hiSuccessBg;
                chipBorder = context.hiSuccessFg;
                chipText = context.hiSuccessFg;
              } else if (isSelected && !result!.isCorrect) {
                chipBg = context.hiErrorBg;
                chipBorder = context.hiErrorFg;
                chipText = context.hiErrorFg;
              }
            } else if (isSelected) {
              chipBg = context.hiAccentBg;
              chipBorder = context.hiAccentColor;
              chipText = context.hiAccentColor;
            }

            return ActionChip(
              label: Text(
                token,
                style: TextStyle(
                  color: chipText,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  decoration: isSelected ? TextDecoration.underline : TextDecoration.none,
                ),
              ),
              backgroundColor: chipBg,
              side: BorderSide(color: chipBorder),
              onPressed: isSubmitted
                  ? null
                  : () {
                      setState(() => _selectedTokenIndex = idx);
                      onSelectErrorToken(token);
                    },
            );
          }),
        ),
      ],
    );
  }
}
