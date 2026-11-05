import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Utility service to clean up temporary audio recordings created during
/// pronunciation practice, voice tests, and AI conversation turns.
/// Prevents cache bloat and storage leaks over time (Finding F-30).
class AudioTempCleaner {
  AudioTempCleaner._();

  /// Deletes stale temporary audio files (e.g. older than [olderThan]).
  /// Scans both the app temporary directory and system temp.
  /// Returns the count of deleted files.
  static Future<int> cleanupTempAudioFiles({
    Duration olderThan = const Duration(hours: 1),
    Directory? directoryOverride,
  }) async {
    int deletedCount = 0;
    final now = DateTime.now();

    List<Directory> targetDirs = [];
    if (directoryOverride != null) {
      targetDirs.add(directoryOverride);
    } else {
      try {
        final tempDir = await getTemporaryDirectory();
        targetDirs.add(tempDir);
      } catch (_) {
        targetDirs.add(Directory.systemTemp);
      }
    }

    for (final dir in targetDirs) {
      if (!dir.existsSync()) continue;

      try {
        final entities = dir.listSync(followLinks: false);
        for (final entity in entities) {
          if (entity is! File) continue;

          final name = entity.uri.pathSegments.isNotEmpty
              ? entity.uri.pathSegments.last.toLowerCase()
              : '';

          // Only target audio recordings created by HI Chinese
          final isRecordingFile = name.startsWith('rec_') ||
              name.endsWith('.m4a') ||
              name.endsWith('.wav');

          if (!isRecordingFile) continue;

          try {
            final stat = entity.statSync();
            final age = now.difference(stat.modified);

            if (age >= olderThan) {
              entity.deleteSync();
              deletedCount++;
              debugPrint('[AudioTempCleaner] Deleted stale recording: ${entity.path} (age: ${age.inMinutes}m)');
            }
          } catch (e) {
            debugPrint('[AudioTempCleaner] Failed to delete file ${entity.path}: $e');
          }
        }
      } catch (e) {
        debugPrint('[AudioTempCleaner] Error scanning directory ${dir.path}: $e');
      }
    }

    return deletedCount;
  }

  /// Immediately deletes a single audio file at [filePath] if it exists.
  /// Returns true if deleted, false if file did not exist or could not be deleted.
  static Future<bool> deleteAudioFile(String? filePath) async {
    if (filePath == null || filePath.trim().isEmpty) return false;

    try {
      final file = File(filePath.trim());
      if (await file.exists()) {
        await file.delete();
        debugPrint('[AudioTempCleaner] Deleted recording file: $filePath');
        return true;
      }
    } catch (e) {
      debugPrint('[AudioTempCleaner] Could not delete $filePath: $e');
    }
    return false;
  }
}
