import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_info_provider.dart';
import '../../../../core/database/database_constants.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../domain/models/app_settings.dart';
import '../providers/settings_providers.dart';
import '../widgets/about_and_privacy_dialog.dart';
import '../widgets/data_management_sheet.dart';
import 'ai_settings_screen.dart';

/// Screen presenting system, audio, AI, and data management settings.
/// Navigated from ProfileScreen via the "Cài Đặt" entry tile.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = ref.watch(appSettingsProvider);
    final micStatusAsync = ref.watch(microphoneStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài Đặt'),
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
            // ==================== 1. CÀI ĐẶT ÂM THANH & MICROPHONE ====================
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
                  Text(
                    'Tốc độ phát âm:',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
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

            // ==================== 2. AI TUTOR & DỮ LIỆU HỆ THỐNG ====================
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
