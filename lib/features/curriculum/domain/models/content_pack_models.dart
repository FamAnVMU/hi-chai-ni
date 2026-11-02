import 'dart:convert';

class ContentPackManifest {
  final String packId;
  final int hskLevel;
  final String version;
  final String title;
  final String description;
  final bool isBundled;
  final int sizeBytes;
  final String sha256;
  final String curriculumVersion;
  final String minimumAppVersion;
  final int schemaVersion;
  final List<String> dependencies;
  final String? releaseDate;
  final String releaseStatus;
  final String? sourceInfo;

  const ContentPackManifest({
    required this.packId,
    required this.hskLevel,
    required this.version,
    required this.title,
    this.description = '',
    this.isBundled = false,
    this.sizeBytes = 0,
    this.sha256 = '',
    this.curriculumVersion = '1.0.0',
    this.minimumAppVersion = '1.0.0',
    this.schemaVersion = 1,
    this.dependencies = const [],
    this.releaseDate,
    this.releaseStatus = 'stable',
    this.sourceInfo,
  });

  factory ContentPackManifest.fromJson(Map<String, dynamic> json) {
    List<String> deps = [];
    if (json['dependencies'] is List) {
      deps = (json['dependencies'] as List).map((e) => e.toString()).toList();
    } else if (json['dependencies_json'] is String && (json['dependencies_json'] as String).isNotEmpty) {
      try {
        final decoded = jsonDecode(json['dependencies_json'] as String);
        if (decoded is List) {
          deps = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return ContentPackManifest(
      packId: json['pack_id'] as String? ?? json['id'] as String? ?? '',
      hskLevel: (json['hsk_level'] as num?)?.toInt() ?? 1,
      version: json['version'] as String? ?? '1.0.0',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isBundled: json['is_bundled'] == true || json['is_bundled'] == 1,
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      sha256: json['sha256'] as String? ?? json['checksum_sha256'] as String? ?? '',
      curriculumVersion: json['curriculum_version'] as String? ?? '1.0.0',
      minimumAppVersion: json['minimum_app_version'] as String? ?? '1.0.0',
      schemaVersion: (json['schema_version'] as num?)?.toInt() ?? 1,
      dependencies: deps,
      releaseDate: json['release_date'] as String?,
      releaseStatus: json['release_status'] as String? ?? 'stable',
      sourceInfo: json['source_info'] as String?,
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
      'curriculum_version': curriculumVersion,
      'minimum_app_version': minimumAppVersion,
      'schema_version': schemaVersion,
      'dependencies_json': jsonEncode(dependencies),
      'release_date': releaseDate,
      'release_status': releaseStatus,
      'source_info': sourceInfo,
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
  final int installedKnowledgeCount;
  final String? errorMessage;

  const ContentPackInstallResult({
    required this.isSuccess,
    required this.packId,
    this.installedLessonsCount = 0,
    this.installedContentItemsCount = 0,
    this.installedKnowledgeCount = 0,
    this.errorMessage,
  });

  factory ContentPackInstallResult.success({
    required String packId,
    int lessonsCount = 0,
    int contentItemsCount = 0,
    int knowledgeCount = 0,
  }) {
    return ContentPackInstallResult(
      isSuccess: true,
      packId: packId,
      installedLessonsCount: lessonsCount,
      installedContentItemsCount: contentItemsCount,
      installedKnowledgeCount: knowledgeCount,
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
