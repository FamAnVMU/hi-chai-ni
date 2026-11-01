import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_backup_helper.dart';
import '../../../../core/theme/theme.dart';
import '../../../design_system/presentation/screens/design_system_demo_screen.dart';
import '../../../settings/presentation/screens/ai_settings_screen.dart';

/// Tab 4: Profile and Settings Screen.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cá Nhân & Cài Đặt'),
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            // User Header Card
            HiCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      'HI',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Người Học Tiếng Trung',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Mục tiêu: Đạt chứng chỉ HSK 3 trong 6 tháng',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const HiChip(
                    label: 'HSK 1',
                    status: HiChipStatus.success,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Settings Group
            Text(
              'Giao Diện & Chế Độ Màu',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            HiCard(
              child: SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                    value: ThemeMode.system,
                    icon: Icon(Icons.brightness_auto_rounded),
                    label: Text('Hệ thống'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    icon: Icon(Icons.light_mode_rounded),
                    label: Text('Sáng'),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    icon: Icon(Icons.dark_mode_rounded),
                    label: Text('Tối'),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (Set<ThemeMode> newSelection) {
                  ref.read(themeModeProvider.notifier).setThemeMode(newSelection.first);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Navigation Items
            Text(
              'Hệ Thống & Cấu Hình',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            HiCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.settings_outlined, color: AppColors.limeGreen),
                    title: const Text('Cài đặt AI Tutor & Kiểm tra kết nối'),
                    subtitle: const Text('BYOK, model routing, Firebase App Check'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.palette_outlined, color: AppColors.limeGreen),
                    title: const Text('Design System Showcase'),
                    subtitle: const Text('Bảng màu, typography Việt-Trung, RubyText'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DesignSystemDemoScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.storage_rounded, color: AppColors.limeGreen),
                    title: const Text('Kiểm tra Toàn vẹn SQLite Database'),
                    subtitle: const Text('PRAGMA integrity_check và thống kê file'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () async {
                      final db = AppDatabase.instance.database;
                      final integrity = await DatabaseBackupHelper.checkIntegrity(db);
                      if (context.mounted) {
                        if (integrity.isEmpty) {
                          HiSnackBar.showSuccess(context, 'Cơ sở dữ liệu SQLite: Toàn vẹn 100% (OK)');
                        } else {
                          HiSnackBar.showWarning(context, 'Phát hiện cảnh báo: ${integrity.join(", ")}');
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // App Version Info
            Center(
              child: Text(
                'HI Chinese • Native Android • Offline-first v1.0.0\nKiến trúc Flutter Material 3 & Clean Architecture',
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
