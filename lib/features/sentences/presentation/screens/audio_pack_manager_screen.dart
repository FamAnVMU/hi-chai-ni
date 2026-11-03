import 'package:flutter/material.dart';
import '../../data/audio_pack_manager.dart';
import '../../domain/models/sentence_models.dart';

/// Screen for managing downloadable offline Audio Packs per HSK level
class AudioPackManagerScreen extends StatefulWidget {
  final AudioPackManager packManager;

  const AudioPackManagerScreen({
    super.key,
    required this.packManager,
  });

  @override
  State<AudioPackManagerScreen> createState() => _AudioPackManagerScreenState();
}

class _AudioPackManagerScreenState extends State<AudioPackManagerScreen> {
  List<AudioPack> _packs = [];
  bool _isLoading = true;
  String? _downloadingPackId;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadPacks();
  }

  Future<void> _loadPacks() async {
    setState(() => _isLoading = true);
    final packs = await widget.packManager.getAvailablePacks();
    if (mounted) {
      setState(() {
        _packs = packs;
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadPack(AudioPack pack) async {
    setState(() {
      _downloadingPackId = pack.id;
      _downloadProgress = 0.0;
    });

    await widget.packManager.downloadPack(
      pack.id,
      onProgress: (prog) {
        if (mounted) setState(() => _downloadProgress = prog);
      },
    );

    if (mounted) {
      setState(() {
        _downloadingPackId = null;
      });
      _loadPacks();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Đã tải xong ${pack.title}!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deletePack(AudioPack pack) async {
    await widget.packManager.deletePack(pack.id);
    _loadPacks();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã xóa ${pack.title} để giải phóng bộ nhớ.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý Gói Âm Thanh'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF2563EB)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Tải các gói âm thanh người thật bản xứ để nghe mượt mà không cần mạng Internet. Khi bộ nhớ đầy, bạn có thể xóa các gói cấp độ đã học xong.',
                          style: TextStyle(fontSize: 13, color: Colors.blue.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // List of packs
                for (final pack in _packs) ...[
                  _buildPackCard(pack),
                  const SizedBox(height: 12),
                ],
              ],
            ),
    );
  }

  Widget _buildPackCard(AudioPack pack) {
    final isDownloadingThis = _downloadingPackId == pack.id;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: pack.isDownloaded ? Colors.green.shade300 : Colors.grey.shade300,
          width: pack.isDownloaded ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                pack.isDownloaded ? Icons.check_circle : Icons.cloud_download_outlined,
                color: pack.isDownloaded ? Colors.green : const Color(0xFF2563EB),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  pack.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${pack.sizeMb} MB',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Bao gồm ${pack.sentenceCount} câu hội thoại và ví dụ mẫu giọng người thật.',
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          if (isDownloadingThis) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(value: _downloadProgress),
            const SizedBox(height: 4),
            Text(
              'Đang tải: ${(_downloadProgress * 100).toInt()}%',
              style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB)),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (pack.isBundled) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Có sẵn trong ứng dụng',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (pack.isDownloaded) ...[
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  label: const Text('Xóa gói', style: TextStyle(color: Colors.red)),
                  onPressed: () => _deletePack(pack),
                ),
              ] else ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Tải về máy'),
                  onPressed: isDownloadingThis ? null : () => _downloadPack(pack),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
