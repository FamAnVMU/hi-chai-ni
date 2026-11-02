import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../providers/settings_providers.dart';
import '../../../profile/presentation/providers/profile_providers.dart';

class DataManagementSheet extends ConsumerStatefulWidget {
  const DataManagementSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const DataManagementSheet(),
    );
  }

  @override
  ConsumerState<DataManagementSheet> createState() => _DataManagementSheetState();
}

class _DataManagementSheetState extends ConsumerState<DataManagementSheet> {
  bool _isProcessing = false;

  Future<void> _handleBackup() async {
    setState(() => _isProcessing = true);
    try {
      final service = ref.read(dataManagementServiceProvider);
      final file = await service.createBackup();
      ref.invalidate(backupListProvider);
      ref.invalidate(storageBreakdownProvider);
      if (mounted) {
        HiSnackBar.showSuccess(context, 'Sao lưu CSDL thành công: ${file.path.split(Platform.pathSeparator).last}');
      }
    } catch (e) {
      if (mounted) {
        HiSnackBar.showError(context, 'Lỗi sao lưu: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleExportJson() async {
    setState(() => _isProcessing = true);
    try {
      final service = ref.read(dataManagementServiceProvider);
      final jsonStr = await service.exportUserDataJson();
      await Clipboard.setData(ClipboardData(text: jsonStr));
      if (mounted) {
        HiSnackBar.showSuccess(context, 'Đã xuất dữ liệu cá nhân ra JSON & sao chép vào Clipboard!');
      }
    } catch (e) {
      if (mounted) {
        HiSnackBar.showError(context, 'Lỗi xuất JSON: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleCheckIntegrity() async {
    setState(() => _isProcessing = true);
    try {
      final service = ref.read(dataManagementServiceProvider);
      final issues = await service.checkIntegrity();
      if (mounted) {
        if (issues.isEmpty) {
          HiSnackBar.showSuccess(context, 'Toàn vẹn CSDL SQLite: 100% OK (Không phát hiện lỗi)');
        } else {
          HiSnackBar.showWarning(context, 'Phát hiện cảnh báo toàn vẹn: ${issues.join(', ')}');
        }
      }
    } catch (e) {
      if (mounted) {
        HiSnackBar.showError(context, 'Lỗi kiểm tra toàn vẹn: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showBackupListDialog(List<File> backups) async {
    final theme = Theme.of(context);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Danh Sách Bản Sao Lưu'),
        content: SizedBox(
          width: double.maxFinite,
          child: backups.isEmpty
              ? const Text('Chưa có bản sao lưu nào. Hãy tạo bản sao lưu đầu tiên.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: backups.length,
                  itemBuilder: (context, i) {
                    final file = backups[i];
                    final name = file.path.split(Platform.pathSeparator).last;
                    final size = file.lengthSync();
                    final sizeStr = (size / 1024).toStringAsFixed(1);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.inventory_2_outlined, color: AppColors.limeGreen),
                      title: Text(name, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13)),
                      subtitle: Text('$sizeStr KB • ${file.lastModifiedSync().toLocal()}'),
                      trailing: TextButton(
                        child: const Text('Khôi phục'),
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          await _confirmRestore(file);
                        },
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRestore(File backupFile) async {
    final shouldProceed = await HiDialog.show<bool>(
      context: context,
      title: 'Xác Nhận Khôi Phục Dữ Liệu',
      message: 'Hệ thống sẽ tự động tạo bản sao lưu an toàn của dữ liệu hiện tại trước khi khôi phục.\n'
          'Bạn có chắc chắn muốn khôi phục từ bản sao lưu này?',
      confirmText: 'Khôi phục ngay',
      cancelText: 'Hủy',
      onConfirm: () => Navigator.of(context).pop(true),
    );

    if (shouldProceed != true) return;

    setState(() => _isProcessing = true);
    try {
      final service = ref.read(dataManagementServiceProvider);
      await service.restoreBackup(backupFile);
      ref.invalidate(userProfileProvider);
      ref.invalidate(goalHistoryProvider);
      ref.invalidate(storageBreakdownProvider);
      ref.invalidate(backupListProvider);
      if (mounted) {
        HiSnackBar.showSuccess(context, 'Đã khôi phục cơ sở dữ liệu thành công!');
      }
    } catch (e) {
      if (mounted) {
        HiSnackBar.showError(context, 'Lỗi khôi phục: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _showDestructiveResetDialog() async {
    final codeController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isCodeValid = codeController.text.trim().toUpperCase() == 'XOA' ||
                codeController.text.trim().toUpperCase() == 'RESET';

            return AlertDialog(
              backgroundColor: const Color(0xFF241515),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                side: const BorderSide(color: Colors.redAccent, width: 1.5),
              ),
              title: Row(
                children: const [
                  Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                  SizedBox(width: AppSpacing.sm),
                  Text('VÙNG NGUY HIỂM: ĐẶT LẠI', style: TextStyle(color: Colors.white, fontSize: 16)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Thao tác này sẽ xóa toàn bộ tiến trình học tập, lịch sử SRS, bài tập và phiên chat AI Tutor trên máy này.\n\n'
                      '• Hệ thống sẽ TỰ ĐỘNG tạo bản sao lưu snapshot trước khi xóa.\n'
                      '• Chỉ xóa dữ liệu cục bộ; dữ liệu cloud (nếu có liên kết) hoàn toàn KHÔNG bị ảnh hưởng.\n\n'
                      'Để xác nhận, vui lòng nhập chữ "XOA" hoặc "RESET":',
                      style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: codeController,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        hintText: 'Nhập XOA hoặc RESET',
                        hintStyle: TextStyle(color: Colors.white.withAlpha(100)),
                        fillColor: const Color(0xFF351A1A),
                        filled: true,
                        border: const OutlineInputBorder(borderSide: BorderSide(color: Colors.redAccent)),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Hủy bỏ', style: TextStyle(color: Colors.white70)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.red.withAlpha(80),
                  ),
                  onPressed: isCodeValid ? () => Navigator.of(ctx).pop(true) : null,
                  child: const Text('Xác nhận XÓA CỤC BỘ'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final service = ref.read(dataManagementServiceProvider);
      await service.clearAllUserData(confirmationCode: codeController.text);
      ref.invalidate(userProfileProvider);
      ref.invalidate(goalHistoryProvider);
      ref.invalidate(storageBreakdownProvider);
      ref.invalidate(backupListProvider);
      if (mounted) {
        HiSnackBar.showSuccess(context, 'Đã đặt lại dữ liệu học tập cục bộ về mặc định.');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        HiSnackBar.showError(context, 'Lỗi đặt lại: $e');
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storageAsync = ref.watch(storageBreakdownProvider);
    final backupsAsync = ref.watch(backupListProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: AppSpacing.screenPadding,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(Icons.storage_rounded, color: AppColors.limeGreen),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Quản Lý Dữ Liệu & Bộ Nhớ',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Kiểm soát dung lượng SQLite, sao lưu độc lập và khôi phục an toàn.',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Dung lượng lưu trữ
            Text('Dung Lượng Bộ Nhớ', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.xs),
            HiCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: storageAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())),
                error: (e, _) => Text('Không thể đo dung lượng: $e'),
                data: (storage) => Column(
                  children: [
                    _buildStorageRow('Cơ sở dữ liệu SQLite (DB + WAL):', storage.formattedDbSize),
                    const SizedBox(height: 4),
                    _buildStorageRow('Bộ nhớ tạm & Âm thanh:', storage.formattedCacheSize),
                    const Divider(height: 12),
                    _buildStorageRow('Tổng dung lượng ứng dụng chiếm dụng:', storage.formattedTotalSize, isBold: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Các thao tác sao lưu & kiểm tra
            Text('Sao Lưu & Kiểm Tra Toàn Vẹn', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: AppSpacing.xs),
            HiCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.backup_rounded, color: AppColors.limeGreen),
                    title: const Text('Sao lưu cơ sở dữ liệu ngay'),
                    subtitle: const Text('Tạo file .hibak bảo vệ dữ liệu với WAL checkpoint'),
                    trailing: _isProcessing
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: _isProcessing ? null : _handleBackup,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.restore_page_rounded, color: AppColors.limeGreen),
                    title: const Text('Xem danh sách sao lưu & Khôi phục'),
                    subtitle: Text('${backupsAsync.value?.length ?? 0} bản sao lưu sẵn có'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      final backups = backupsAsync.value ?? [];
                      _showBackupListDialog(backups);
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.download_for_offline_rounded, color: AppColors.limeGreen),
                    title: const Text('Xuất dữ liệu cá nhân ra JSON'),
                    subtitle: const Text('Sao chép JSON tiến trình & hồ sơ vào Clipboard'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _isProcessing ? null : _handleExportJson,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.verified_outlined, color: AppColors.limeGreen),
                    title: const Text('Kiểm tra toàn vẹn SQLite (PRAGMA integrity_check)'),
                    subtitle: const Text('Xác nhận không có phân mảnh hay hỏng hóc file'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _isProcessing ? null : _handleCheckIntegrity,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Vùng nguy hiểm (Danger Zone)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(20),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: Colors.redAccent.withAlpha(120), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                      SizedBox(width: AppSpacing.xs),
                      Text(
                        'Vùng Nguy Hiểm (Danger Zone)',
                        style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Đặt lại dữ liệu học tập về trạng thái ban đầu. Dữ liệu từ vựng/ngữ pháp mặc định sẽ được giữ nguyên. Tự động tạo bản sao lưu snapshot trước khi xóa.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  HiButton(
                    text: 'Đặt Lại Dữ Liệu & Tiến Trình...',
                    variant: HiButtonVariant.secondary,
                    onPressed: _isProcessing ? null : _showDestructiveResetDialog,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageRow(String label, String value, {bool isBold = false}) {
    final style = TextStyle(
      fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
      fontSize: 13,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        const SizedBox(width: AppSpacing.sm),
        Text(value, style: style.copyWith(color: AppColors.limeGreen)),
      ],
    );
  }
}
