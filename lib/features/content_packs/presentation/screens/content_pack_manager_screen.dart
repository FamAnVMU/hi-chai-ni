import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../providers/content_packs_providers.dart';

class ContentPackManagerScreen extends ConsumerWidget {
  const ContentPackManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final packsAsync = ref.watch(contentPacksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kho Học Liệu & Cấp Độ HSK'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới danh sách',
            onPressed: () => ref.read(contentPacksProvider.notifier).refresh(),
          ),
        ],
      ),
      body: packsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('Lỗi tải danh mục gói học liệu: $err'),
          ),
        ),
        data: (packs) {
          return ListView(
            padding: AppSpacing.screenPadding,
            children: [
              // Thông tin giới thiệu kiến trúc Offline-First
              HiCard(
                backgroundColor: AppColors.primaryBlueDark.withAlpha(20),
                borderColor: AppColors.primaryBlueDark.withAlpha(80),
                child: Row(
                  children: [
                    const Icon(
                      Icons.cloud_download_rounded,
                      color: AppColors.primaryBlueDark,
                      size: 36,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tự học Offline hoàn toàn',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryBlueDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'HSK 1 & HSK 2 được tích hợp sẵn. Các cấp độ nâng cao (HSK 3-6) có thể tải một lần về máy và sử dụng không cần Internet.',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              Text(
                'Danh mục các cấp độ HSK',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              ...packs.map((item) {
                final info = item.info;
                final isInstalled = item.isInstalled;
                final isDownloading = item.isDownloading;

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: HiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs,
                              ),
                              decoration: BoxDecoration(
                                color: isInstalled
                                    ? AppColors.primaryBlueDark
                                    : (info.isBundled
                                        ? AppColors.information
                                        : AppColors.primaryBlueDark),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'HSK ${info.hskLevel}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    info.title,
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    info.description,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.textTheme.bodySmall?.color?.withAlpha(180),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              info.isBundled
                                  ? 'Tích hợp sẵn • ${info.formattedSize}'
                                  : 'GitHub CDN • ${info.formattedSize}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            if (isInstalled)
                              Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.primaryBlueDark,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Đã sẵn sàng',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.primaryBlueDark,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              )
                            else if (isDownloading)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              HiButton(
                                text: info.isBundled ? 'Cài đặt ngay' : 'Tải xuống',
                                size: HiButtonSize.sm,
                                variant: info.isBundled
                                    ? HiButtonVariant.primary
                                    : HiButtonVariant.secondary,
                                icon: const Icon(Icons.download_rounded, size: 16),
                                onPressed: () async {
                                  final success = await ref
                                      .read(contentPacksProvider.notifier)
                                      .installPack(info.packId);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? 'Đã cài đặt thành công ${info.title}!'
                                              : (item.error ?? 'Cài đặt thất bại, vui lòng thử lại.'),
                                        ),
                                        backgroundColor: success
                                            ? AppColors.primaryBlueDark
                                            : Colors.red[700],
                                      ),
                                    );
                                  }
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
