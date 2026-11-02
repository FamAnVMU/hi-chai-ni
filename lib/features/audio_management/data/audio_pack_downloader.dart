import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../domain/models/audio_asset_manifest.dart';
import 'audio_asset_dao.dart';
import 'audio_storage_manager.dart';
import 'content_source_config.dart';

class AudioDownloadException implements Exception {
  final String message;
  final String packId;
  const AudioDownloadException(this.message, {this.packId = ''});

  @override
  String toString() => 'AudioDownloadException($packId): $message';
}

class AudioPackDownloader {
  final AudioStorageManager storageManager;
  final AudioAssetDao dao;
  final ContentSourceConfig config;
  final http.Client client;

  bool _isCancelled = false;
  bool _isPaused = false;

  AudioPackDownloader({
    required this.storageManager,
    required this.dao,
    ContentSourceConfig? config,
    http.Client? client,
  })  : config = config ?? const ContentSourceConfig(),
        client = client ?? http.Client();

  void pause() {
    _isPaused = true;
  }

  void resume() {
    _isPaused = false;
  }

  void cancel() {
    _isCancelled = true;
  }

  /// Downloads an entire AudioPack manifest and all of its constituent audio files.
  /// Supports:
  /// - Disk space validation.
  /// - Staging inside `.tmp` to avoid corrupted partial files.
  /// - SHA-256 verification before promoting to active audio directory.
  /// - Incremental updating (skips files already verified and present on disk).
  Future<bool> downloadAndInstallPack({
    required AudioPackManifest manifest,
    void Function(double progress, int downloadedBytes, int totalBytes)? onProgress,
    DatabaseExecutor? executor,
  }) async {
    _isCancelled = false;
    _isPaused = false;

    // 1. Check storage space
    final hasSpace = await storageManager.hasSufficientStorage(manifest.totalSizeBytes);
    if (!hasSpace) {
      throw AudioDownloadException(
        'Thiết bị không đủ dung lượng lưu trữ (${manifest.totalSizeBytes} bytes).',
        packId: manifest.packId,
      );
    }

    await storageManager.ensureDirectories(manifest.packId);

    // 2. Fetch existing assets in DB to support incremental downloads
    final existingRows = await dao.getAssetsByPackage(manifest.packId, executor: executor);
    final existingMap = {for (final r in existingRows) r['id'] as String: r};

    int totalBytes = manifest.totalSizeBytes > 0
        ? manifest.totalSizeBytes
        : manifest.assets.fold(0, (acc, a) => acc + a.fileSizeBytes);
    if (totalBytes <= 0) totalBytes = manifest.assets.length * 1024 * 50; // fallback estimate 50KB/file

    int cumulativeDownloadedBytes = 0;
    int processedFiles = 0;

    for (final asset in manifest.assets) {
      if (_isCancelled) {
        await storageManager.cleanStaging(manifest.packId);
        throw AudioDownloadException('Tải gói âm thanh đã bị hủy bởi người dùng.', packId: manifest.packId);
      }

      while (_isPaused) {
        await Future.delayed(const Duration(milliseconds: 200));
        if (_isCancelled) {
          await storageManager.cleanStaging(manifest.packId);
          throw AudioDownloadException('Tải gói âm thanh đã bị hủy.', packId: manifest.packId);
        }
      }

      final existing = existingMap[asset.audioId];
      final targetRelative = asset.relativePath.isNotEmpty ? asset.relativePath : '${asset.audioId}.${asset.fileFormat}';
      final expectedPath = p.join(storageManager.getPackAudioDirectory(manifest.packId), targetRelative);
      final targetFile = File(expectedPath);

      // INCREMENTAL CHECK: If file already exists and hash matches, reuse it!
      if (existing != null &&
          existing['checksum_sha256'] == asset.checksumSha256 &&
          existing['status'] == 'ready' &&
          await targetFile.exists()) {
        cumulativeDownloadedBytes += asset.fileSizeBytes;
        processedFiles++;
        final progress = (processedFiles / manifest.assets.length).clamp(0.0, 1.0);
        onProgress?.call(progress, cumulativeDownloadedBytes, totalBytes);
        continue;
      }

      // Download file to temporary staging
      final tempFileName = 'temp_${asset.audioId}_${DateTime.now().millisecondsSinceEpoch}.tmp';
      final stagingFilePath = p.join(storageManager.getPackStagingDirectory(manifest.packId), tempFileName);
      final stagingFile = File(stagingFilePath);

      try {
        final downloadUrl = config.getAudioFileUrl(manifest.packId, targetRelative);
        final uri = Uri.parse(downloadUrl);

        final response = await client.get(uri, headers: config.defaultHeaders);
        if (response.statusCode != 200) {
          // If 404 or network error, attempt fallback or record error
          throw AudioDownloadException(
            'Lỗi tải file âm thanh ${asset.audioId} (HTTP ${response.statusCode})',
            packId: manifest.packId,
          );
        }

        await stagingFile.writeAsBytes(response.bodyBytes, flush: true);

        // Verify SHA-256 and promote atomically
        final finalLocalPath = await storageManager.promoteFromStaging(
          packId: manifest.packId,
          tempFileName: tempFileName,
          relativeTargetFilePath: targetRelative,
          expectedSha256: asset.checksumSha256,
        );

        // Update database record
        final assetMap = asset.copyWith(
          localPath: finalLocalPath,
          status: 'ready',
          updatedAt: DateTime.now().toUtc().toIso8601String(),
        ).toMap();

        await dao.insertAsset(assetMap, executor: executor);

        cumulativeDownloadedBytes += response.bodyBytes.length;
        processedFiles++;
        final progress = (processedFiles / manifest.assets.length).clamp(0.0, 1.0);
        onProgress?.call(progress, cumulativeDownloadedBytes, totalBytes);
      } catch (e) {
        if (await stagingFile.exists()) {
          try {
            await stagingFile.delete();
          } catch (_) {}
        }
        debugPrint('[AudioPackDownloader] Error processing ${asset.audioId}: $e');
        rethrow;
      }
    }

    // Clean any remaining staging files
    await storageManager.cleanStaging(manifest.packId);
    return true;
  }
}
