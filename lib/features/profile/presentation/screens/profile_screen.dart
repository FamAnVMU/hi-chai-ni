import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_info_provider.dart';
import '../../../../core/database/database_constants.dart';
import '../../../../core/theme/theme.dart';
import '../../../roadmap/domain/models/roadmap_models.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../settings/presentation/widgets/about_and_privacy_dialog.dart';
import '../../../settings/domain/models/app_settings.dart';
import '../providers/profile_providers.dart';
import '../widgets/edit_profile_sheet.dart';
import '../widgets/edit_goal_dialog.dart';
import '../widgets/goal_history_sheet.dart';
import '../../domain/models/user_profile.dart';

/// Tab 4: Comprehensive Profile and Settings Screen for HI Chinese.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _getAvatarEmoji(String style) {
    switch (style) {
      case 'panda':
        return '🐼';
      case 'dragon':
        return '🐉';
      case 'bamboo':
        return '🎋';
      case 'lantern':
        return '🏮';
      case 'tea':
        return '🍵';
      case 'scholar':
        return '📜';
      default:
        return '🇨🇳';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final profileAsync = ref.watch(userProfileProvider);
    final goalHistoryAsync = ref.watch(goalHistoryProvider);
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cá Nhân'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            tooltip: 'Thông tin ứng dụng',
            onPressed: () => AboutAndPrivacyDialog.show(context),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            // ==================== 1. HỒ SƠ NGƯỜI HỌC ====================
            profileAsync.when(
              loading: () => const HiCard(
                child: SizedBox(height: 120, child: Center(child: CircularProgressIndicator())),
              ),
              error: (err, _) => HiCard(
                child: Text('Lỗi tải hồ sơ: $err'),
              ),
              data: (profile) {
                final dateStr = '${profile.startDate.day}/${profile.startDate.month}/${profile.startDate.year}';
                return HiCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  backgroundColor: AppColors.cardBackground,
                  borderColor: AppColors.border,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            backgroundColor: AppColors.primaryBlueLight,
                            child: Text(
                              _getAvatarEmoji(profile.avatarStyle),
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        profile.displayName,
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primaryText,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    HiChip(
                                      label: 'HSK ${profile.currentHskLevel}',
                                      status: HiChipStatus.info,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Mục tiêu: HSK ${profile.targetHskLevel} • ${profile.dailyMinutes} phút/ngày',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.primaryBlueDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${profile.purpose.displayName} • Học từ $dateStr',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      // Sở thích học
                      if (profile.interests.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: 4,
                          children: profile.interests.map((interestId) {
                            final match = LearnerInterest.defaultInterests.firstWhere(
                              (i) => i.id == interestId,
                              orElse: () => LearnerInterest(id: interestId, labelVi: interestId, labelZh: '', iconName: ''),
                            );
                            return Chip(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              labelPadding: const EdgeInsets.symmetric(horizontal: 6),
                              label: Text(
                                match.labelVi,
                                style: const TextStyle(fontSize: 11),
                              ),
                            );
                          }).toList(),
                        ),
                      ],

                      const Divider(height: AppSpacing.lg),

                      // Nút hành động Hồ sơ
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              label: const Text('Sửa hồ sơ'),
                              onPressed: () {
                                EditProfileSheet.show(
                                  context: context,
                                  profile: profile,
                                  onSave: (updated) {
                                    ref.read(userProfileProvider.notifier).updateProfile(
                                      displayName: updated.displayName,
                                      currentHskLevel: updated.currentHskLevel,
                                      avatarStyle: updated.avatarStyle,
                                      interests: updated.interests,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.track_changes_rounded, size: 16),
                              label: const Text('Đổi mục tiêu'),
                              onPressed: () {
                                EditGoalDialog.show(
                                  context: context,
                                  profile: profile,
                                  onConfirm: ({
                                    required int targetHskLevel,
                                    required int dailyMinutes,
                                    required LearnerPurpose purpose,
                                    required String reason,
                                  }) async {
                                    await ref.read(userProfileProvider.notifier).updateGoal(
                                      targetHskLevel: targetHskLevel,
                                      dailyMinutes: dailyMinutes,
                                      purpose: purpose,
                                      reason: reason,
                                    );
                                    if (context.mounted) {
                                      HiSnackBar.showSuccess(context, 'Đã cập nhật mục tiêu và ghi nhận lịch sử!');
                                    }
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.history_rounded, size: 16),
                          label: Text(
                            'Xem lịch sử mục tiêu (${goalHistoryAsync.value?.length ?? 0} lần đổi)',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () {
                            GoalHistorySheet.show(
                              context: context,
                              history: goalHistoryAsync.value ?? [],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),

            // ==================== 2. GIAO DIỆN & TÙY CHỌN ĐỌC ====================
            Text(
              'Giao Diện & Tùy Chọn Đọc',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            HiCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Theme Mode
                  Text('Chế độ màu:', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto_rounded, size: 18),
                          label: Text('Hệ thống'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_rounded, size: 18),
                          label: Text('Sáng'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_rounded, size: 18),
                          label: Text('Tối'),
                        ),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (Set<ThemeMode> newSelection) {
                        ref.read(appSettingsProvider.notifier).setThemeMode(newSelection.first);
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Cỡ chữ / Font Scale
                  Text('Cỡ chữ hiển thị:', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: FontScaleOption.values.map((opt) {
                      final isSelected = (settings.fontScale - opt.scale).abs() < 0.05;
                      return ChoiceChip(
                        label: Text(opt.labelVi),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            ref.read(appSettingsProvider.notifier).setFontScale(opt.scale);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  // Font preview box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Xem trước chữ Hán & Pinyin:', style: theme.textTheme.labelSmall),
                        const SizedBox(height: 2),
                        const Text('你好世界 • Nǐ hǎo shìjiè • Xin chào thế giới!'),
                      ],
                    ),
                  ),

                  const Divider(height: AppSpacing.lg),

                  // Tùy chọn đọc Pinyin & Ruby
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Hiển thị Pinyin mặc định'),
                    subtitle: const Text('Bật/tắt phiên âm trong từ điển và bài đọc'),
                    value: settings.showPinyinByDefault,
                    onChanged: (val) {
                      ref.read(appSettingsProvider.notifier).toggleShowPinyin(val);
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Chú âm dạng RubyText'),
                    subtitle: const Text('Pinyin đặt ngay trên đỉnh từng chữ Hán'),
                    value: settings.showRubyAnnotation,
                    onChanged: (val) {
                      ref.read(appSettingsProvider.notifier).toggleShowRuby(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ==================== 3. LỐI TẮT CÀI ĐẶT HỆ THỐNG ====================
            const SizedBox(height: AppSpacing.lg),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              tileColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Cài Đặt'),
              subtitle: const Text('Âm thanh, AI Tutor, Dữ liệu & Quyền riêng tư'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // App Footer
            Builder(
              builder: (context) {
                final appInfoAsync = ref.watch(appInfoProvider);
                final versionStr = appInfoAsync.maybeWhen(
                  data: (info) => info.fullVersionString,
                  orElse: () => 'v${AppConstants.appVersionWithBuild}',
                );
                return Center(
                  child: Text(
                    '${AppConstants.appName} • Native Android • Offline-first $versionStr\nCơ sở dữ liệu SQLite Schema v${DatabaseConstants.currentDatabaseVersion}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white38 : theme.colorScheme.onSurfaceVariant.withAlpha(120),
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.huge),
          ],
        ),
      ),
    );
  }
}
