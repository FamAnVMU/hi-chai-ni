import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/reading_models.dart';

/// Compact mode selector pills for switching display modes in reading comprehension
class ReadingModeSelector extends StatelessWidget {
  final ReadingDisplayMode currentMode;
  final ValueChanged<ReadingDisplayMode> onModeChanged;

  const ReadingModeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Row(
        children: [
          _buildChip(
            context,
            mode: ReadingDisplayMode.full,
            label: 'Đầy đủ',
            icon: Icons.view_headline_rounded,
            theme: theme,
            isDark: isDark,
          ),
          const SizedBox(width: AppSpacing.xs),
          _buildChip(
            context,
            mode: ReadingDisplayMode.hanziAndPinyin,
            label: 'Chữ + Pinyin',
            icon: Icons.subtitles_rounded,
            theme: theme,
            isDark: isDark,
          ),
          const SizedBox(width: AppSpacing.xs),
          _buildChip(
            context,
            mode: ReadingDisplayMode.hanziOnly,
            label: 'Chỉ Chữ Hán',
            icon: Icons.translate_rounded,
            theme: theme,
            isDark: isDark,
          ),
          const SizedBox(width: AppSpacing.xs),
          _buildChip(
            context,
            mode: ReadingDisplayMode.hanziAndTranslation,
            label: 'Luyện dịch',
            icon: Icons.g_translate_rounded,
            theme: theme,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required ReadingDisplayMode mode,
    required String label,
    required IconData icon,
    required ThemeData theme,
    required bool isDark,
  }) {
    final isSelected = currentMode == mode;
    final activeColor = AppColors.primaryBlueDark;

    return InkWell(
      onTap: () => onModeChanged(mode),
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor
              : (isDark ? theme.colorScheme.surfaceContainerHighest.withAlpha(60) : AppColors.cardBackground),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.border,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected ? AppElevation.shadowLow(theme.brightness) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : AppColors.secondaryText,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.primaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
