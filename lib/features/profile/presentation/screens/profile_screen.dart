import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/database/database_constants.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../../design_system/presentation/screens/design_system_demo_screen.dart';
import '../../../roadmap/domain/models/roadmap_models.dart';
import '../../../settings/presentation/screens/ai_settings_screen.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../../settings/presentation/widgets/data_management_sheet.dart';
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

  Future<void> _checkOrRequestMic() async {
    final result = await PermissionHelper.requestMicrophoneWithRationale(
      context,
      featureName: 'Luyện phát âm & Hội thoại cùng AI Tutor',
    );
    ref.invalidate(microphoneStatusProvider);
    if (mounted) {
      if (result == AudioPermissionResult.granted) {
        HiSnackBar.showSuccess(context, 'Quyền Micro: Đã được cấp phép!');
      } else if (result == AudioPermissionResult.permanentlyDenied) {
        HiSnackBar.showWarning(context, 'Quyền Micro bị từ chối vĩnh viễn. Vui lòng bật trong Cài đặt hệ thống.');
      } else {
        HiSnackBar.showWarning(context, 'Quyền Micro chưa được cấp phép.');
      }
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
    final micStatusAsync = ref.watch(microphoneStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cá Nhân & Cài Đặt'),
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

            // ==================== 3. CÀI ĐẶT ÂM THANH & MICROPHONE ====================
            Text(
              'Âm Thanh & Giọng Đọc',
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
                  Text('Tốc độ phát âm:', style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    children: SpeechRateOption.values.map((opt) {
                      final isSelected = (settings.speechRate - opt.rate).abs() < 0.05;
                      return ChoiceChip(
                        label: Text(opt.labelVi),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            ref.read(appSettingsProvider.notifier).setSpeechRate(opt.rate);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tự động phát âm thanh'),
                    subtitle: const Text('Tự phát audio khi lật thẻ SRS hoặc tra từ'),
                    value: settings.autoPlayAudio,
                    onChanged: (val) {
                      ref.read(appSettingsProvider.notifier).toggleAutoPlayAudio(val);
                    },
                  ),

                  const Divider(height: AppSpacing.md),

                  // Quản lý quyền Micro
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.mic_rounded, color: AppColors.primaryBlueDark),
                    title: const Text('Quyền truy cập Micro'),
                    subtitle: micStatusAsync.when(
                      loading: () => const Text('Đang kiểm tra...'),
                      error: (_, _) => const Text('Không thể kiểm tra quyền'),
                      data: (status) => Text(
                        status.isGranted ? 'Trạng thái: Đã cấp quyền (Sẵn sàng)' : 'Trạng thái: Chưa cấp quyền',
                        style: TextStyle(
                          color: status.isGranted ? AppColors.success : AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    trailing: OutlinedButton(
                      onPressed: _checkOrRequestMic,
                      child: const Text('Kiểm tra'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // ==================== 4. AI TUTOR & CẤU HÌNH HỆ THỐNG ====================
            Text(
              'Hệ Thống, AI & Dữ Liệu',
              style: theme.textTheme.labelMedium?.copyWith(
                color: AppColors.primaryBlueDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            HiCard(
              padding: EdgeInsets.zero,
              backgroundColor: AppColors.cardBackground,
              borderColor: AppColors.border,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.psychology_outlined, color: AppColors.primaryBlueDark),
                    title: const Text('Cài đặt AI Tutor & Chẩn đoán kết nối'),
                    subtitle: const Text('BYOK API Key, model routing, ping latency'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  ListTile(
                    leading: const Icon(Icons.storage_rounded, color: AppColors.primaryBlueDark),
                    title: const Text('Quản lý Dữ liệu & Sao lưu'),
                    subtitle: const Text('Backup, restore, export JSON, dung lượng DB'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => DataManagementSheet.show(context),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  ListTile(
                    leading: const Icon(Icons.palette_outlined, color: AppColors.primaryBlueDark),
                    title: const Text('Design System Showcase'),
                    subtitle: const Text('Bảng màu, typography Việt-Trung, RubyText'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DesignSystemDemoScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                  ListTile(
                    leading: const Icon(Icons.policy_outlined, color: AppColors.primaryBlueDark),
                    title: const Text('Thông tin & Chính sách bảo vệ dữ liệu'),
                    subtitle: Text('Standalone Offline-first • Schema v${DatabaseConstants.currentDatabaseVersion}'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => AboutAndPrivacyDialog.show(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // App Footer
            Center(
              child: Text(
                'HI Chinese • Native Android • Offline-first v1.0.0+1\nCơ sở dữ liệu SQLite Schema v${DatabaseConstants.currentDatabaseVersion}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.white38 : theme.colorScheme.onSurfaceVariant.withAlpha(120),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.huge),
          ],
        ),
      ),
    );
  }
}
