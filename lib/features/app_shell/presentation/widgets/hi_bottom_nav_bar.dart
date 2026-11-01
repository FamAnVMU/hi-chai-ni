import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/app_tab.dart';

/// Custom Bottom Navigation Bar for HI Chinese featuring a prominent
/// center AI Tutor action button and full Android gesture navigation support.
class HiBottomNavBar extends StatelessWidget {
  final AppTab currentTab;
  final ValueChanged<AppTab> onTabSelected;

  const HiBottomNavBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    final barBgColor = isDark ? AppColors.darkForestSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkForestBorder : theme.colorScheme.outlineVariant;

    return Container(
      decoration: BoxDecoration(
        color: barBgColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 1.0),
        ),
        boxShadow: AppElevation.shadowLow(theme.brightness),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          height: 64.0 + (bottomPadding > 0 ? 0 : 4.0),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 0: Trang chủ
              _buildStandardTabItem(
                context,
                tab: AppTab.home,
                isSelected: currentTab == AppTab.home,
                isDark: isDark,
              ),

              // 1: Học tập
              _buildStandardTabItem(
                context,
                tab: AppTab.learning,
                isSelected: currentTab == AppTab.learning,
                isDark: isDark,
              ),

              // 2: AI TUTOR (NÚT TRUNG TÂM NỔI BẬT)
              _buildCenterAiTutorButton(
                context,
                isSelected: currentTab == AppTab.aiTutor,
                isDark: isDark,
              ),

              // 3: Ôn tập
              _buildStandardTabItem(
                context,
                tab: AppTab.review,
                isSelected: currentTab == AppTab.review,
                isDark: isDark,
              ),

              // 4: Cá nhân
              _buildStandardTabItem(
                context,
                tab: AppTab.profile,
                isSelected: currentTab == AppTab.profile,
                isDark: isDark,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Standard tab item with icon, label, and min 48dp touch target
  Widget _buildStandardTabItem(
    BuildContext context, {
    required AppTab tab,
    required bool isSelected,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final activeColor = isDark ? AppColors.limeGreen : theme.colorScheme.primary;
    final inactiveColor = isDark ? Colors.white60 : theme.colorScheme.onSurfaceVariant;

    final color = isSelected ? activeColor : inactiveColor;

    return Expanded(
      child: Semantics(
        label: tab.semanticLabel,
        button: true,
        selected: isSelected,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: ValueKey('tab_${tab.name}'),
            onTap: () => onTabSelected(tab),
            borderRadius: AppRadius.borderMd,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppDimensions.minTouchTarget,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelected ? tab.activeIcon : tab.icon,
                    size: AppDimensions.iconMd,
                    color: color,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    tab.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 10.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Prominent Center AI Tutor Button
  Widget _buildCenterAiTutorButton(
    BuildContext context, {
    required bool isSelected,
    required bool isDark,
  }) {
    final theme = Theme.of(context);

    // Selected state colors
    final containerColor = isSelected
        ? AppColors.limeGreen
        : (isDark ? AppColors.darkForestCard : theme.colorScheme.primaryContainer);

    final iconColor = isSelected
        ? AppColors.darkForestBg // High-contrast dark forest on lime green
        : (isDark ? AppColors.limeGreen : theme.colorScheme.onPrimaryContainer);

    final textColor = isSelected
        ? (isDark ? AppColors.limeGreen : theme.colorScheme.primary)
        : (isDark ? Colors.white70 : theme.colorScheme.onSurfaceVariant);

    return Semantics(
      label: AppTab.aiTutor.semanticLabel,
      button: true,
      selected: isSelected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const ValueKey('tab_ai_tutor'),
          onTap: () => onTabSelected(AppTab.aiTutor),
          borderRadius: AppRadius.borderFull,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
            constraints: const BoxConstraints(
              minWidth: 58.0,
              minHeight: AppDimensions.minTouchTarget,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  height: 36.0,
                  width: 52.0,
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: AppRadius.borderFull,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.limeGreen
                          : (isDark ? AppColors.darkForestBorder : theme.colorScheme.outlineVariant),
                      width: 1.5,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.limeGreen.withAlpha(80),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: AppDimensions.iconSm + 2,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  AppTab.aiTutor.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: textColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 10.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
