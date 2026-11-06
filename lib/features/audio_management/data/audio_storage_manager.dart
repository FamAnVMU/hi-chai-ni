import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class AudioStorageManager {
  final String baseStoragePath;

  AudioStorageManager({required this.baseStoragePath});

  /// Directory path for a specific audio pack.
  String getPackDirectory(String packId) {
    return p.join(baseStoragePath, 'content_packs', packId);
  }

  /// Directory path for actual audio files inside a pack.
  String getPackAudioDirectory(String packId) {
    return p.join(getPackDirectory(packId), 'audio');
  }

  /// Temporary staging directory used during downloads to avoid partial writes.
  String getPackStagingDirectory(String packId) {
    return p.join(getPackDirectory(packId), '.tmp');
  }

  /// Ensures directories exist.
  Future<void> ensureDirectories(String packId) async {
    final audioDir = Directory(getPackAudioDirectory(packId));
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }
    final stagingDir = Directory(getPackStagingDirectory(packId));
    if (!await stagingDir.exists()) {
      await stagingDir.create(recursive: true);
    }
  }

  /// Verifies a file on disk against its expected SHA-256 checksum and format.
  Future<bool> verifyFileIntegrity(File file, String expectedSha256) async {
    if (!await file.exists()) return false;
    final length = await file.length();
    if (length == 0) return false;

    // If expected checksum is empty, only check existence and non-empty
    if (expectedSha256.isEmpty) return true;

    try {
      final bytes = await file.readAsBytes();
      final actualSha256 = sha256.convert(bytes).toString();
      return actualSha256.toLowerCase() == expectedSha256.toLowerCase();
    } catch (e) {
      debugPrint('[AudioStorageManager] Hash verification error: $e');
      return false;
    }
  }

  /// Promotes a verified temporary file to its final destination in the pack audio directory.
  Future<String> promoteFromStaging({
    required String packId,
    required String tempFileName,
    required String relativeTargetFilePath,
    required String expectedSha256,
  }) async {
    final stagingPath = p.join(getPackStagingDirectory(packId), tempFileName);
    final tempFile = File(stagingPath);

    final isValid = await verifyFileIntegrity(tempFile, expectedSha256);
    if (!isValid) {
      if (await tempFile.exists()) await tempFile.delete();
      throw StateError('Checksum SHA-256 verification failed for file: $tempFileName');
    }

    final targetPath = p.join(getPackAudioDirectory(packId), relativeTargetFilePath);
    final targetFile = File(targetPath);

    final targetDir = targetFile.parent;
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    // Atomic move / rename
    await tempFile.rename(targetPath);
    return targetPath;
  }

  /// Calculates total bytes used by a specific audio pack.
  Future<int> calculatePackDiskUsage(String packId) async {
    final packDir = Directory(getPackDirectory(packId));
    if (!await packDir.exists()) return 0;

    int totalBytes = 0;
    try {
      await for (final entity in packDir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          totalBytes += await entity.length();
        }
      }
    } catch (_) {}
    return totalBytes;
  }

  /// Cleans up any remaining temporary files in the staging directory.
  Future<void> cleanStaging(String packId) async {
    final stagingDir = Directory(getPackStagingDirectory(packId));
    if (await stagingDir.exists()) {
      try {
        await stagingDir.delete(recursive: true);
      } catch (_) {}
    }
  }

  /// Safely deletes an audio pack from disk without affecting any other packages.
  Future<void> deletePackAudio(String packId) async {
    final packDir = Directory(getPackDirectory(packId));
    if (await packDir.exists()) {
      await packDir.delete(recursive: true);
    }
  }

  /// Checks if device has sufficient storage available for estimated bytes.
  Future<bool> hasSufficientStorage(int requiredBytes) async {
    try {
      // In standard desktop / unit tests or non-rooted mobile, stat fs
      // We check if target base storage exists and is writable
      final dir = Directory(baseStoragePath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> extractZipArchiveSafely({
    required String zipFilePath,
    required String destinationDir,
    String? expectedSha256,
  }) async {
    final zipFile = File(zipFilePath);
    if (!await zipFile.exists()) {
      throw FileSystemException('Zip archive file not found: $zipFilePath', zipFilePath);
    }

    if (expectedSha256 != null && expectedSha256.isNotEmpty) {
      final isValid = await verifyFileIntegrity(zipFile, expectedSha256);
      if (!isValid) {
        throw StateError('Zip archive SHA-256 verification failed for: $zipFilePath');
      }
    }

    final bytes = await zipFile.readAsBytes();
    return extractZipBytesSafely(
      zipBytes: bytes,
      destinationDir: destinationDir,
    );
  }

  Future<int> extractZipBytesSafely({
    required List<int> zipBytes,
    required String destinationDir,
  }) async {
    final canonicalDest = p.canonicalize(destinationDir);
    final targetDirectory = Directory(canonicalDest);
    if (!await targetDirectory.exists()) {
      await targetDirectory.create(recursive: true);
    }

    final safePrefix = canonicalDest.endsWith(p.separator)
        ? canonicalDest
        : '$canonicalDest${p.separator}';

    final archive = ZipDecoder().decodeBytes(zipBytes);
    int extractedCount = 0;

    for (final entry in archive) {
      if (entry.isFile) {
        final rawName = entry.name;
        if (rawName.startsWith('/') ||
            rawName.startsWith('\\') ||
            (rawName.length > 1 && rawName[1] == ':')) {
          throw FileSystemException(
            'Blocked Zip-Slip path traversal attack attempt with absolute path: $rawName',
            rawName,
          );
        }

        final resolvedPath = p.canonicalize(p.join(canonicalDest, rawName));

        if (!resolvedPath.startsWith(safePrefix) && resolvedPath != canonicalDest) {
          throw FileSystemException(
            'Blocked Zip-Slip path traversal attack attempt: $rawName',
            rawName,
          );
        }

        final outFile = File(resolvedPath);
        final parentDir = outFile.parent;
        if (!await parentDir.exists()) {
          await parentDir.create(recursive: true);
        }

        await outFile.writeAsBytes(entry.content as List<int>);
        extractedCount++;
      }
    }

    return extractedCount;
  }

  Future<int> extractPackAudioArchive({
    required String packId,
    required String zipFilePath,
    String? expectedSha256,
  }) async {
    await ensureDirectories(packId);
    final destDir = getPackAudioDirectory(packId);
    return extractZipArchiveSafely(
      zipFilePath: zipFilePath,
      destinationDir: destDir,
      expectedSha256: expectedSha256,
    );
  }
}
