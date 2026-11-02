/// Represents a single audio asset item with complete provenance and technical metadata.
class AudioAssetItem {
  final String audioId;
  final String packageId;
  final String contentId;
  final String audioType; // vocab, syllable, initial, final, sentence, dialogue, listening, reading, shadowing, exam
  final int hskLevel;
  final String speakerId;
  final String fileFormat;
  final int sampleRate;
  final int durationMs;
  final int fileSizeBytes;
  final String checksumSha256;
  final String relativePath;
  final String? localPath;
  final String status; // remote, downloading, ready, corrupted
  final String? source;
  final String? license;
  final String? transcriptZh;
  final String? transcriptVi;
  final String createdAt;
  final String updatedAt;

  const AudioAssetItem({
    required this.audioId,
    required this.packageId,
    required this.contentId,
    required this.audioType,
    required this.hskLevel,
    this.speakerId = 'native_zh',
    this.fileFormat = 'mp3',
    this.sampleRate = 44100,
    this.durationMs = 0,
    this.fileSizeBytes = 0,
    required this.checksumSha256,
    required this.relativePath,
    this.localPath,
    this.status = 'remote',
    this.source,
    this.license,
    this.transcriptZh,
    this.transcriptVi,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AudioAssetItem.fromMap(Map<String, dynamic> map) {
    return AudioAssetItem(
      audioId: map['id'] as String? ?? map['audio_id'] as String? ?? '',
      packageId: map['package_id'] as String? ?? '',
      contentId: map['content_id'] as String? ?? '',
      audioType: map['audio_type'] as String? ?? 'vocab',
      hskLevel: (map['hsk_level'] as num?)?.toInt() ?? 1,
      speakerId: map['speaker_id'] as String? ?? 'native_zh',
      fileFormat: map['file_format'] as String? ?? 'mp3',
      sampleRate: (map['sample_rate'] as num?)?.toInt() ?? 44100,
      durationMs: (map['duration_ms'] as num?)?.toInt() ?? 0,
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt() ?? 0,
      checksumSha256: map['checksum_sha256'] as String? ?? '',
      relativePath: map['relative_path'] as String? ?? '',
      localPath: map['local_path'] as String?,
      status: map['status'] as String? ?? 'remote',
      source: map['source'] as String?,
      license: map['license'] as String?,
      transcriptZh: map['transcript_zh'] as String?,
      transcriptVi: map['transcript_vi'] as String?,
      createdAt: map['created_at'] as String? ?? '',
      updatedAt: map['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': audioId,
      'package_id': packageId,
      'content_id': contentId,
      'audio_type': audioType,
      'hsk_level': hskLevel,
      'speaker_id': speakerId,
      'file_format': fileFormat,
      'sample_rate': sampleRate,
      'duration_ms': durationMs,
      'file_size_bytes': fileSizeBytes,
      'checksum_sha256': checksumSha256,
      'relative_path': relativePath,
      'local_path': localPath,
      'status': status,
      'source': source,
      'license': license,
      'transcript_zh': transcriptZh,
      'transcript_vi': transcriptVi,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  AudioAssetItem copyWith({
    String? localPath,
    String? status,
    String? updatedAt,
  }) {
    return AudioAssetItem(
      audioId: audioId,
      packageId: packageId,
      contentId: contentId,
      audioType: audioType,
      hskLevel: hskLevel,
      speakerId: speakerId,
      fileFormat: fileFormat,
      sampleRate: sampleRate,
      durationMs: durationMs,
      fileSizeBytes: fileSizeBytes,
      checksumSha256: checksumSha256,
      relativePath: relativePath,
      localPath: localPath ?? this.localPath,
      status: status ?? this.status,
      source: source,
      license: license,
      transcriptZh: transcriptZh,
      transcriptVi: transcriptVi,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Manifest definition of an entire Audio Pack.
class AudioPackManifest {
  final String packId;
  final String title;
  final int hskLevel;
  final String version;
  final int totalFiles;
  final int totalSizeBytes;
  final String downloadUrl;
  final String sha256Checksum;
  final List<AudioAssetItem> assets;

  const AudioPackManifest({
    required this.packId,
    required this.title,
    required this.hskLevel,
    required this.version,
    required this.totalFiles,
    required this.totalSizeBytes,
    required this.downloadUrl,
    required this.sha256Checksum,
    required this.assets,
  });

  factory AudioPackManifest.fromJson(Map<String, dynamic> json) {
    final assetList = (json['assets'] as List<dynamic>? ?? [])
        .map((e) => AudioAssetItem.fromMap(e as Map<String, dynamic>))
        .toList();

    return AudioPackManifest(
      packId: json['pack_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      hskLevel: (json['hsk_level'] as num?)?.toInt() ?? 1,
      version: json['version'] as String? ?? '1.0.0',
      totalFiles: (json['total_files'] as num?)?.toInt() ?? assetList.length,
      totalSizeBytes: (json['total_size_bytes'] as num?)?.toInt() ?? 0,
      downloadUrl: json['download_url'] as String? ?? '',
      sha256Checksum: json['sha256_checksum'] as String? ?? '',
      assets: assetList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pack_id': packId,
      'title': title,
      'hsk_level': hskLevel,
      'version': version,
      'total_files': totalFiles,
      'total_size_bytes': totalSizeBytes,
      'download_url': downloadUrl,
      'sha256_checksum': sha256Checksum,
      'assets': assets.map((a) => a.toMap()).toList(),
    };
  }
}
