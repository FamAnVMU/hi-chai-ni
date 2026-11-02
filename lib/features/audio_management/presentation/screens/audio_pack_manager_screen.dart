import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/audio_pack_models.dart';
import '../providers/audio_pack_providers.dart';
import '../widgets/audio_pack_card.dart';

class AudioPackManagerScreen extends ConsumerWidget {
  const AudioPackManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packsAsync = ref.watch(audioPacksProvider);
    final coverageAsync = ref.watch(audioCoverageReportProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFE),
      appBar: AppBar(
        title: const Text(
          'Quản lý Âm thanh Ngoại tuyến',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              ref.read(audioPacksProvider.notifier).refresh();
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFEDF2F7), height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Audio Coverage Audit Card
          coverageAsync.when(
            data: (report) => Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE3EBF4)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.analytics_outlined, color: Color(0xFF478DD4)),
                          SizedBox(width: 8),
                          Text(
                            'Báo cáo Độ bao phủ Âm thanh',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${report.overallCoveragePercentage.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3979C7),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: report.overallCoveragePercentage / 100,
                      minHeight: 8,
                      backgroundColor: const Color(0xFFEDF2F7),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5B9BE6)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tổng cần có: ${report.grandTotalRequired}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      Text(
                        'Đã sẵn sàng: ${report.grandTotalAvailable}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF22A06B), fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Còn thiếu: ${report.grandTotalMissing}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFFE05D66)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 20),

          const Text(
            'Danh mục Gói âm thanh HSK & Pinyin',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 12),

          // Audio Packs List
          packsAsync.when(
            data: (packs) => Column(
              children: packs.map((AudioPackInfo pack) {
                return AudioPackCard(
                  pack: pack,
                  onDownload: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Đang khởi tạo tải gói ${pack.title}...'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  onDelete: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text('Gỡ bỏ ${pack.title}?'),
                        content: const Text(
                          'Các tệp âm thanh của gói sẽ được gỡ khỏi bộ nhớ thiết bị. Lịch sử học tập và tiến độ của bạn vẫn được bảo toàn nguyên vẹn.',
                        ),
                        actions: [
                          TextButton(
                            child: const Text('Hủy'),
                            onPressed: () => Navigator.of(ctx).pop(),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(foregroundColor: const Color(0xFFE05D66)),
                            child: const Text('Gỡ bỏ'),
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await ref.read(audioPacksProvider.notifier).deletePack(pack.packId);
                            },
                          ),
                        ],
                      ),
                    );
                  },
                );
              }).toList(),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Lỗi: $err')),
          ),
        ],
      ),
    );
  }
}
