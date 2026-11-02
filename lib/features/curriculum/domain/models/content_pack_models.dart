class ContentPackManifest {
  final String packId;
  final int hskLevel;
  final String version;
  final String title;
  final String description;
  final bool isBundled;
  final int sizeBytes;
  final String sha256;

  const ContentPackManifest({
    required this.packId,
    required this.hskLevel,
    required this.version,
    required this.title,
    this.description = '',
    this.isBundled = false,
    this.sizeBytes = 0,
    this.sha256 = '',
  });

  factory ContentPackManifest.fromJson(Map<String, dynamic> json) {
    return ContentPackManifest(
      packId: json['pack_id'] as String? ?? json['id'] as String? ?? '',
      hskLevel: (json['hsk_level'] as num?)?.toInt() ?? 1,
      version: json['version'] as String? ?? '1.0.0',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isBundled: json['is_bundled'] == true || json['is_bundled'] == 1,
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      sha256: json['sha256'] as String? ?? json['checksum_sha256'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap({String status = 'not_installed', String? installedAt}) {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'id': packId,
      'hsk_level': hskLevel,
      'version': version,
      'title': title,
      'description': description,
      'is_bundled': isBundled ? 1 : 0,
      'status': status,
      'size_bytes': sizeBytes,
      'checksum_sha256': sha256,
      'installed_at': installedAt ?? (isBundled ? now : null),
      'updated_at': now,
    };
  }
}

class ContentPackInstallResult {
  final bool isSuccess;
  final String packId;
  final int installedLessonsCount;
  final int installedContentItemsCount;
  final String? errorMessage;

  const ContentPackInstallResult({
    required this.isSuccess,
    required this.packId,
    this.installedLessonsCount = 0,
    this.installedContentItemsCount = 0,
    this.errorMessage,
  });

  factory ContentPackInstallResult.success({
    required String packId,
    int lessonsCount = 0,
    int contentItemsCount = 0,
  }) {
    return ContentPackInstallResult(
      isSuccess: true,
      packId: packId,
      installedLessonsCount: lessonsCount,
      installedContentItemsCount: contentItemsCount,
    );
  }

  factory ContentPackInstallResult.failure({
    required String packId,
    required String message,
  }) {
    return ContentPackInstallResult(
      isSuccess: false,
      packId: packId,
      errorMessage: message,
    );
  }
}
