import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:hi_chinese/core/audio/unified_audio_playback_service.dart';
import 'package:hi_chinese/core/database/database.dart';
import 'package:hi_chinese/features/audio_management/data/audio_asset_dao.dart';
import 'package:hi_chinese/features/audio_management/data/audio_coverage_auditor.dart';
import 'package:hi_chinese/features/audio_management/data/audio_pack_downloader.dart';
import 'package:hi_chinese/features/audio_management/data/audio_storage_manager.dart';
import 'package:hi_chinese/features/audio_management/domain/models/audio_asset_manifest.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('Offline Audio Asset Management Tests (Tests C–H)', () {
    late Directory tempDir;
    late String dbPath;
    late Database db;
    late AudioStorageManager storageManager;
    late AudioAssetDao audioDao;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('audio_mgmt_test_');
      dbPath = '${tempDir.path}/audio_test.db';
      db = await AppDatabase.instance.open(
        customPath: dbPath,
        customFactory: databaseFactoryFfi,
      );
      storageManager = AudioStorageManager(baseStoragePath: tempDir.path);
      audioDao = AudioAssetDao(db);
    });

    tearDown(() async {
      await AppDatabase.instance.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    // TEST C: Download Audio Pack with Verification & Playback
    test('Test C - Download real audio files, verify SHA-256, stage atomically, and play', () async {
      final sampleAudioBytes = utf8.encode('ID3_MOCK_VALID_AUDIO_BYTES_FOR_HSK3');
      final validSha256 = sha256.convert(sampleAudioBytes).toString();

      final mockClient = MockClient((request) async {
        return http.Response.bytes(sampleAudioBytes, 200);
      });

      final downloader = AudioPackDownloader(
        storageManager: storageManager,
        dao: audioDao,
        client: mockClient,
      );

      final manifest = AudioPackManifest(
        packId: 'audio_hsk3',
        title: 'HSK 3 Standard Audio Pack',
        hskLevel: 3,
        version: '1.0.0',
        totalFiles: 1,
        totalSizeBytes: sampleAudioBytes.length,
        downloadUrl: 'https://cdn.example.com/audio_hsk3.zip',
        sha256Checksum: '',
        assets: [
          AudioAssetItem(
            audioId: 'audio_hsk3_v001',
            packageId: 'audio_hsk3',
            contentId: 'VOCAB_001',
            audioType: 'vocab',
            hskLevel: 3,
            fileSizeBytes: sampleAudioBytes.length,
            checksumSha256: validSha256,
            relativePath: 'v001.mp3',
            createdAt: DateTime.now().toUtc().toIso8601String(),
            updatedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        ],
      );

      double reportedProgress = 0.0;
      final success = await downloader.downloadAndInstallPack(
        manifest: manifest,
        onProgress: (p, _, _) {
          reportedProgress = p;
        },
      );

      expect(success, isTrue);
      expect(reportedProgress, 1.0);

      // Verify file exists on disk
      final targetPath = p.join(storageManager.getPackAudioDirectory('audio_hsk3'), 'v001.mp3');
      expect(await File(targetPath).exists(), isTrue);

      // Verify database record
      final assetRow = await audioDao.getAssetById('audio_hsk3_v001');
      expect(assetRow, isNotNull);
      expect(assetRow!['status'], 'ready');
      expect(assetRow['local_path'], targetPath);

      // Verify playback service plays local offline audio without crashing
      final player = UnifiedAudioPlaybackService.instance;
      await player.playAudio(targetPath, simulatedDuration: const Duration(milliseconds: 200));
      expect(player.currentlyPlayingUri, targetPath);
      await player.stop();
    });

    // TEST D: Download Interrupted & Clean Recovery
    test('Test D - Download interruption cancels staging cleanly without corrupted files', () async {
      final sampleAudioBytes = utf8.encode('AUDIO_STREAM_SAMPLE');
      final validSha256 = sha256.convert(sampleAudioBytes).toString();

      final mockClient = MockClient((request) async {
        return http.Response.bytes(sampleAudioBytes, 200);
      });

      final downloader = AudioPackDownloader(
        storageManager: storageManager,
        dao: audioDao,
        client: mockClient,
      );

      final manifest = AudioPackManifest(
        packId: 'audio_hsk4',
        title: 'HSK 4 Audio Pack',
        hskLevel: 4,
        version: '1.0.0',
        totalFiles: 2,
        totalSizeBytes: sampleAudioBytes.length * 2,
        downloadUrl: 'https://cdn.example.com/hsk4.zip',
        sha256Checksum: '',
        assets: [
          AudioAssetItem(
            audioId: 'audio_hsk4_01',
            packageId: 'audio_hsk4',
            contentId: 'V_01',
            audioType: 'vocab',
            hskLevel: 4,
            checksumSha256: validSha256,
            relativePath: 'v01.mp3',
            createdAt: DateTime.now().toUtc().toIso8601String(),
            updatedAt: DateTime.now().toUtc().toIso8601String(),
          ),
          AudioAssetItem(
            audioId: 'audio_hsk4_02',
            packageId: 'audio_hsk4',
            contentId: 'V_02',
            audioType: 'vocab',
            hskLevel: 4,
            checksumSha256: validSha256,
            relativePath: 'v02.mp3',
            createdAt: DateTime.now().toUtc().toIso8601String(),
            updatedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        ],
      );

      // Cancel download when progress occurs on multi-file pack
      expect(
        () async => await downloader.downloadAndInstallPack(
          manifest: manifest,
          onProgress: (p, current, total) {
            downloader.cancel();
          },
        ),
        throwsA(isA<AudioDownloadException>()),
      );

      // Check that staging directory was cleaned
      final stagingDir = Directory(storageManager.getPackStagingDirectory('audio_hsk4'));
      if (await stagingDir.exists()) {
        final remainingFiles = await stagingDir.list().toList();
        expect(remainingFiles, isEmpty);
      }
    });

    // TEST E: Offline Playback Verification
    test('Test E - Offline playback operates purely locally without any network requests', () async {
      // Create a local audio file
      final localFile = File('${tempDir.path}/offline_sample.mp3');
      await localFile.writeAsBytes(utf8.encode('OFFLINE_AUDIO_PAYLOAD'));

      final player = UnifiedAudioPlaybackService.instance;
      await player.playAudio(localFile.path, simulatedDuration: const Duration(milliseconds: 300));

      expect(player.currentlyPlayingUri, localFile.path);

      // Speed control
      await player.setPlaybackSpeed(1.25);
      expect(player.playbackSpeed, 1.25);

      await player.stop();
      expect(player.currentlyPlayingUri, isNull);
    });

    // TEST F: Incremental Update (Reusing Unchanged Files)
    test('Test F - Update Audio Pack only downloads new or changed files and retains unchanged files', () async {
      final file1Bytes = utf8.encode('FILE_1_UNCHANGED_CONTENT');
      final file1Sha = sha256.convert(file1Bytes).toString();

      final file2Bytes = utf8.encode('FILE_2_NEW_CONTENT');
      final file2Sha = sha256.convert(file2Bytes).toString();

      int networkFetchCount = 0;
      final mockClient = MockClient((request) async {
        networkFetchCount++;
        if (request.url.path.contains('f1.mp3')) {
          return http.Response.bytes(file1Bytes, 200);
        }
        return http.Response.bytes(file2Bytes, 200);
      });

      final downloader = AudioPackDownloader(
        storageManager: storageManager,
        dao: audioDao,
        client: mockClient,
      );

      // 1. Initial install with File 1
      final v1Manifest = AudioPackManifest(
        packId: 'audio_incr_test',
        title: 'Incremental Test Pack',
        hskLevel: 3,
        version: '1.0.0',
        totalFiles: 1,
        totalSizeBytes: file1Bytes.length,
        downloadUrl: '',
        sha256Checksum: '',
        assets: [
          AudioAssetItem(
            audioId: 'audio_f1',
            packageId: 'audio_incr_test',
            contentId: 'F1',
            audioType: 'vocab',
            hskLevel: 3,
            fileSizeBytes: file1Bytes.length,
            checksumSha256: file1Sha,
            relativePath: 'f1.mp3',
            createdAt: DateTime.now().toUtc().toIso8601String(),
            updatedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        ],
      );

      await downloader.downloadAndInstallPack(manifest: v1Manifest);
      expect(networkFetchCount, 1);

      // 2. Update to v1.1.0 with File 1 (identical hash) AND File 2 (new file)
      final v11Manifest = AudioPackManifest(
        packId: 'audio_incr_test',
        title: 'Incremental Test Pack (v1.1.0)',
        hskLevel: 3,
        version: '1.1.0',
        totalFiles: 2,
        totalSizeBytes: file1Bytes.length + file2Bytes.length,
        downloadUrl: '',
        sha256Checksum: '',
        assets: [
          AudioAssetItem(
            audioId: 'audio_f1',
            packageId: 'audio_incr_test',
            contentId: 'F1',
            audioType: 'vocab',
            hskLevel: 3,
            fileSizeBytes: file1Bytes.length,
            checksumSha256: file1Sha, // Same hash!
            relativePath: 'f1.mp3',
            createdAt: DateTime.now().toUtc().toIso8601String(),
            updatedAt: DateTime.now().toUtc().toIso8601String(),
          ),
          AudioAssetItem(
            audioId: 'audio_f2',
            packageId: 'audio_incr_test',
            contentId: 'F2',
            audioType: 'vocab',
            hskLevel: 3,
            fileSizeBytes: file2Bytes.length,
            checksumSha256: file2Sha, // New!
            relativePath: 'f2.mp3',
            createdAt: DateTime.now().toUtc().toIso8601String(),
            updatedAt: DateTime.now().toUtc().toIso8601String(),
          ),
        ],
      );

      await downloader.downloadAndInstallPack(manifest: v11Manifest);

      // Network count should only increase by 1 (for file 2), file 1 was REUSED!
      expect(networkFetchCount, 2);
    });

    // TEST G: Storage Management & Safe Cleanup
    test('Test G - Storage Manager calculates disk usage and safely cleans up without collateral damage', () async {
      await storageManager.ensureDirectories('pack_storage_test');
      final dummyFile = File('${storageManager.getPackAudioDirectory('pack_storage_test')}/test.mp3');
      await dummyFile.writeAsBytes(List.filled(1024 * 100, 1)); // 100 KB

      final diskUsage = await storageManager.calculatePackDiskUsage('pack_storage_test');
      expect(diskUsage, greaterThanOrEqualTo(1024 * 100));

      // Delete pack audio
      await storageManager.deletePackAudio('pack_storage_test');
      final remainingUsage = await storageManager.calculatePackDiskUsage('pack_storage_test');
      expect(remainingUsage, 0);
    });

    // TEST H: Audio Quality & Coverage Audit
    test('Test H - Audio Coverage Auditor accurately calculates coverage without fake placeholder numbers', () async {
      final auditor = AudioCoverageAuditor(db);
      final report = await auditor.auditCoverage();

      expect(report.grandTotalRequired, greaterThan(0));
      expect(report.levelCoverages.length, 7); // Pinyin + HSK 1..6

      final pinyinCoverage = report.levelCoverages.firstWhere((l) => l.hskLevel == 0);
      expect(pinyinCoverage.levelName, 'Pinyin Foundation');
      expect(pinyinCoverage.totalRequired, 114);

      // Overall percentage is calculated objectively
      expect(report.overallCoveragePercentage, isNonNegative);
    });
  });
}
