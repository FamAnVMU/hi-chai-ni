/// High-level presentation and status model for an Audio Pack.
class AudioPackInfo {
  final String packId;
  final String title;
  final int hskLevel;
  final String version;
  final int totalFiles;
  final int sizeBytes;
  final String downloadUrl;
  final String sha256Checksum;
  final String status; // not_downloaded, downloading, ready, update_available
  final double progress;
  final int downloadedBytes;
  final String? errorMessage;

  const AudioPackInfo({
    required this.packId,
    required this.title,
    required this.hskLevel,
    required this.version,
    required this.totalFiles,
    required this.sizeBytes,
    required this.downloadUrl,
    required this.sha256Checksum,
    this.status = 'not_downloaded',
    this.progress = 0.0,
    this.downloadedBytes = 0,
    this.errorMessage,
  });

  bool get isReady => status == 'ready';
  bool get isDownloading => status == 'downloading';

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  AudioPackInfo copyWith({
    String? status,
    double? progress,
    int? downloadedBytes,
    String? errorMessage,
  }) {
    return AudioPackInfo(
      packId: packId,
      title: title,
      hskLevel: hskLevel,
      version: version,
      totalFiles: totalFiles,
      sizeBytes: sizeBytes,
      downloadUrl: downloadUrl,
      sha256Checksum: sha256Checksum,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      downloadedBytes: downloadedBytes ?? this.downloadedBytes,
      errorMessage: errorMessage,
    );
  }
}
