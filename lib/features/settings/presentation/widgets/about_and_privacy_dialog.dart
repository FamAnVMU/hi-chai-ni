import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/app_info_provider.dart';
import '../../../../core/database/database_constants.dart';
import '../../../../core/theme/theme.dart';

class AboutAndPrivacyDialog extends ConsumerWidget {
  const AboutAndPrivacyDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const AboutAndPrivacyDialog(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final appInfoAsync = ref.watch(appInfoProvider);
    final versionStr = appInfoAsync.maybeWhen(
      data: (info) => info.fullVersionString,
      orElse: () => 'v${AppConstants.appVersionWithBuild}',
    );

    return AlertDialog(
      title: Row(
        children: const [
          Icon(Icons.info_outline_rounded, color: AppColors.primaryBlueDark),
          SizedBox(width: AppSpacing.sm),
          Text('Thông Tin & Chính Sách'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  const Icon(Icons.translate_rounded, size: 48, color: AppColors.primaryBlueDark),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    AppConstants.appName,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Phiên bản $versionStr • CSDL Schema v${DatabaseConstants.currentDatabaseVersion}',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.md),

            Text(
              'Kiến Trúc Độc Lập (Local Standalone)',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'HI Chinese được thiết kế theo triết lý Offline-first. Bạn không bắt buộc phải tạo tài khoản máy chủ hay đăng nhập đám mây để học tập. '
              'Mọi dữ liệu tiến trình, thẻ từ vựng SRS, lịch sử làm bài và tin nhắn AI Tutor đều được lưu trữ an toàn trong cơ sở dữ liệu SQLite cục bộ trên máy bạn.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
            const SizedBox(height: AppSpacing.md),

            Text(
              'Chính Sách Quyền Riêng Tư & Micro',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '• Quyền Micro: Chỉ kích hoạt khi bạn chủ động nhấn nút thu âm trong Pronunciation Lab hoặc mở Voice Chat với AI Tutor.\n'
              '• An toàn nền tảng: Khi ứng dụng vào trạng thái nền (Background/Paused), micro và luồng âm thanh sẽ tự động giải phóng ngay lập tức.\n'
              '• Dữ liệu phân tích phát âm: Được xử lý trực tiếp hoặc qua API được bạn cấu hình (BYOK), không bị chia sẻ cho bên thứ ba vì mục đích quảng cáo.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
            const SizedBox(height: AppSpacing.md),

            Text(
              'Bảo Vệ Dữ Liệu Học Viên',
              style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Bạn có toàn quyền sao lưu, xuất JSON và khôi phục dữ liệu bất cứ lúc nào. '
              'Các thao tác xóa dữ liệu cục bộ được bảo vệ bằng cơ chế xác nhận 2 bước và snapshot tự động trước khi thực thi.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đã hiểu'),
        ),
      ],
    );
  }
}
