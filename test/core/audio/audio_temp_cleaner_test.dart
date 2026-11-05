import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/audio/audio_temp_cleaner.dart';

void main() {
  late Directory tempTestDir;

  setUp(() {
    tempTestDir = Directory.systemTemp.createTempSync('hi_chinese_audio_cleaner_test_');
  });

  tearDown(() {
    if (tempTestDir.existsSync()) {
      try {
        tempTestDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  group('AudioTempCleaner Tests (F-30)', () {
    test('1. cleanupTempAudioFiles deletes stale recording files and preserves fresh or non-audio files', () async {
      // 1. Stale recording file (> 1 hour old)
      final staleFile = File('${tempTestDir.path}/rec_12345678.m4a');
      staleFile.writeAsBytesSync([1, 2, 3]);
      staleFile.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));

      // 2. Fresh recording file (< 1 hour old)
      final freshFile = File('${tempTestDir.path}/rec_99999999.m4a');
      freshFile.writeAsBytesSync([4, 5, 6]);
      freshFile.setLastModifiedSync(DateTime.now().subtract(const Duration(minutes: 5)));

      // 3. Stale non-audio file (should NOT be deleted)
      final otherFile = File('${tempTestDir.path}/important_data.json');
      otherFile.writeAsStringSync('{"key": "value"}');
      otherFile.setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 3)));

      final deletedCount = await AudioTempCleaner.cleanupTempAudioFiles(
        olderThan: const Duration(hours: 1),
        directoryOverride: tempTestDir,
      );

      expect(deletedCount, equals(1));
      expect(staleFile.existsSync(), isFalse);
      expect(freshFile.existsSync(), isTrue);
      expect(otherFile.existsSync(), isTrue);
    });

    test('2. deleteAudioFile safely deletes single file or handles missing path without error', () async {
      final sample = File('${tempTestDir.path}/rec_single_test.wav');
      sample.writeAsBytesSync([0, 1]);
      expect(sample.existsSync(), isTrue);

      final deleted = await AudioTempCleaner.deleteAudioFile(sample.path);
      expect(deleted, isTrue);
      expect(sample.existsSync(), isFalse);

      // Calling again on deleted path should return false safely
      final deletedAgain = await AudioTempCleaner.deleteAudioFile(sample.path);
      expect(deletedAgain, isFalse);

      // Calling with null or empty should return false safely
      expect(await AudioTempCleaner.deleteAudioFile(null), isFalse);
      expect(await AudioTempCleaner.deleteAudioFile(''), isFalse);
    });
  });
}
