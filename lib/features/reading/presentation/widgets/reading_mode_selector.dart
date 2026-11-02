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
            label: 'Hanzi + Pinyin',
            icon: Icons.subtitles_rounded,
            theme: theme,
            isDark: isDark,
          ),
          const SizedBox(width: AppSpacing.xs),
          _buildChip(
            context,
            mode: ReadingDisplayMode.hanziOnly,
            label: 'Chỉ chữ Hán',
            icon: Icons.translate_rounded,
            theme: theme,
            isDark: isDark,
          ),
          const SizedBox(width: AppSpacing.xs),
          _buildChip(
            context,
            mode: ReadingDisplayMode.hanziAndTranslation,
            label: 'Hanzi + Dịch',
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

    return FilterChip(
      selected: isSelected,
      showCheckmark: false,
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected
            ? (isDark ? Colors.black : Colors.white)
            : theme.colorScheme.onSurfaceVariant,
      ),
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected
            ? (isDark ? Colors.black : Colors.white)
            : theme.colorScheme.onSurface,
      ),
      selectedColor: isDark ? AppColors.primaryBlueDark : theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
      onSelected: (_) => onModeChanged(mode),
    );
  }
}
