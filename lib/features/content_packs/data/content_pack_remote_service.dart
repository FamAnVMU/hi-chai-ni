import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../../curriculum/data/content_pack_loader.dart';
import '../../curriculum/domain/models/content_pack_models.dart';

/// Representation of a remote pack available for download.
class RemoteContentPackInfo {
  final String packId;
  final int hskLevel;
  final String title;
  final String description;
  final String version;
  final int sizeBytes;
  final String downloadUrl;
  final String sha256Checksum;
  final bool isBundled;

  const RemoteContentPackInfo({
    required this.packId,
    required this.hskLevel,
    required this.title,
    required this.description,
    required this.version,
    required this.sizeBytes,
    required this.downloadUrl,
    required this.sha256Checksum,
    this.isBundled = false,
  });

  String get formattedSize {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Service managing remote content pack downloading, verifying, and SQLite installing.
class ContentPackRemoteService {
  final DatabaseExecutor _db;
  final http.Client _httpClient;

  /// Default GitHub repository base for official content packs
  static const String defaultRepo = 'FamAnVMU/hi-chai-ni';
  static const String cdnBaseUrl = 'https://raw.githubusercontent.com/$defaultRepo/main/content_packs_cdn';

  ContentPackRemoteService({
    required DatabaseExecutor db,
    http.Client? httpClient,
  })  : _db = db,
        _httpClient = httpClient ?? http.Client();

  /// Curated catalog of available HSK packs (HSK 1 & 2 are bundled, HSK 3-6 downloadable).
  static List<RemoteContentPackInfo> getAvailablePacks() {
    return [
      const RemoteContentPackInfo(
        packId: 'hsk1_pack_v1',
        hskLevel: 1,
        title: 'Giáo trình chuẩn HSK 1',
        description: '150 từ vựng cốt lõi, 15 bài học, 45 ngữ pháp & đề thi tốt nghiệp HSK 1.',
        version: '1.0.0',
        sizeBytes: 170878,
        downloadUrl: 'bundled:assets/data/content_packs/hsk1/hsk1_pack_v1.json',
        sha256Checksum: '',
        isBundled: true,
      ),
      const RemoteContentPackInfo(
        packId: 'hsk2_pack_v1',
        hskLevel: 2,
        title: 'Giáo trình chuẩn HSK 2',
        description: '150 từ vựng nâng cao, 15 bài học chuyên sâu, 45 ngữ pháp & đề thi tốt nghiệp HSK 2.',
        version: '1.0.0',
        sizeBytes: 176422,
        downloadUrl: 'bundled:assets/data/content_packs/hsk2/hsk2_pack_v1.json',
        sha256Checksum: '78f92b4baeb9931b37df8b6998fe76014ba80e68459c367b6119261e06057fcb',
        isBundled: true,
      ),
      const RemoteContentPackInfo(
        packId: 'hsk3_pack_v1',
        hskLevel: 3,
        title: 'Giáo trình chuẩn HSK 3 (Trực tuyến)',
        description: '300 từ vựng trung cấp, 20 bài học, luyện đọc hiểu và phản xạ giao tiếp tự nhiên.',
        version: '1.0.0',
        sizeBytes: 350000,
        downloadUrl: '$cdnBaseUrl/hsk3_pack_v1.json',
        sha256Checksum: '',
        isBundled: false,
      ),
      const RemoteContentPackInfo(
        packId: 'hsk4_pack_v1',
        hskLevel: 4,
        title: 'Giáo trình chuẩn HSK 4 (Trực tuyến)',
        description: '600 từ vựng cao cấp, 20 chuyên đề văn hóa xã hội & đề thi mô phỏng chuẩn quốc tế.',
        version: '1.0.0',
        sizeBytes: 720000,
        downloadUrl: '$cdnBaseUrl/hsk4_pack_v1.json',
        sha256Checksum: '',
        isBundled: false,
      ),
    ];
  }

  /// Checks if a pack is already installed in SQLite.
  Future<bool> isPackInstalled(String packId) async {
    final result = await _db.query(
      'content_packs',
      where: 'id = ?',
      whereArgs: [packId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  /// Downloads a remote JSON content pack, verifies its SHA-256 (if specified), and installs it.
  Future<ContentPackInstallResult> downloadAndInstallPack({
    required RemoteContentPackInfo packInfo,
    void Function(double progress)? onProgress,
  }) async {
    try {
      onProgress?.call(0.1);
      final uri = Uri.parse(packInfo.downloadUrl);
      final response = await _httpClient.get(uri);

      if (response.statusCode != 200) {
        return ContentPackInstallResult.failure(
          packId: packInfo.packId,
          message: 'Lỗi tải gói học liệu từ máy chủ (HTTP ${response.statusCode}).',
        );
      }

      onProgress?.call(0.5);
      final rawJson = utf8.decode(response.bodyBytes);

      // Verify checksum if provided
      if (packInfo.sha256Checksum.isNotEmpty) {
        final computed = sha256.convert(response.bodyBytes).toString();
        if (computed != packInfo.sha256Checksum) {
          return ContentPackInstallResult.failure(
            packId: packInfo.packId,
            message: 'Mã băm SHA-256 không khớp! File có thể bị lỗi khi truyền tải.',
          );
        }
      }

      onProgress?.call(0.8);
      final loader = ContentPackLoader(_db);
      final result = await loader.loadPackFromJson(rawJson);
      onProgress?.call(1.0);
      return result;
    } catch (e) {
      debugPrint('[ContentPackRemoteService] Download failed: $e');
      return ContentPackInstallResult.failure(
        packId: packInfo.packId,
        message: 'Lỗi trong quá trình tải và cài đặt: $e',
      );
    }
  }
}
