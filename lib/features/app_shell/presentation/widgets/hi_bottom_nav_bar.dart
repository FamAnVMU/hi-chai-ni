import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/app_tab.dart';

/// Clean Modern Bottom Navigation Bar for HI Chinese: White & Light Blue minimal UI.
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

    final barBgColor = isDark ? AppColors.darkForestSurface : AppColors.cardBackground;
    final borderColor = isDark ? AppColors.darkForestBorder : AppColors.border;

    return Container(
      decoration: BoxDecoration(
        color: barBgColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 1.0),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: true,
        child: Container(
          height: 60.0 + (bottomPadding > 0 ? 0 : 4.0),
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

              // 2: AI TUTOR (NÚT TRUNG TÂM GỌN GÀNG, HIỆN ĐẠI)
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
    final activeColor = isDark ? AppColors.accentBlue : AppColors.primaryBlueDark;
    final inactiveColor = isDark ? AppColors.mutedText : AppColors.secondaryText;

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
            splashColor: (isDark ? AppColors.accentBlue : AppColors.primaryBlue).withAlpha(15),
            highlightColor: Colors.transparent,
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
                  const SizedBox(height: 3.0),
                  Text(
                    tab.label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 11.0,
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

  /// Center AI Tutor Button: Clean, modern pill design
  Widget _buildCenterAiTutorButton(
    BuildContext context, {
    required bool isSelected,
    required bool isDark,
  }) {
    final theme = Theme.of(context);

    final containerColor = isSelected
        ? (isDark ? AppColors.accentBlue : AppColors.primaryBlueDark)
        : (isDark ? AppColors.darkForestCard : AppColors.primaryBlueLight);

    final iconColor = isSelected
        ? Colors.white
        : (isDark ? AppColors.accentBlue : AppColors.primaryBlueDark);

    final textColor = isSelected
        ? (isDark ? AppColors.accentBlue : AppColors.primaryBlueDark)
        : (isDark ? AppColors.mutedText : AppColors.secondaryText);

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
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 2.0),
            constraints: const BoxConstraints(
              minWidth: 58.0,
              minHeight: AppDimensions.minTouchTarget,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  height: 34.0,
                  width: 50.0,
                  decoration: BoxDecoration(
                    color: containerColor,
                    borderRadius: AppRadius.borderFull,
                    border: Border.all(
                      color: isSelected
                          ? (isDark ? AppColors.accentBlue : AppColors.primaryBlueDark)
                          : (isDark ? AppColors.darkForestBorder : AppColors.border),
                      width: 1.0,
                    ),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: AppDimensions.iconSm + 1,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  AppTab.aiTutor.label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: textColor,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
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
