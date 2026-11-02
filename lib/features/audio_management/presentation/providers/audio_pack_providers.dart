import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../data/audio_asset_dao.dart';
import '../../data/audio_coverage_auditor.dart';
import '../../data/audio_storage_manager.dart';
import '../../domain/models/audio_coverage_report.dart';
import '../../domain/models/audio_pack_models.dart';

final audioStorageManagerProvider = Provider<AudioStorageManager>((ref) {
  final dbPath = AppDatabase.instance.path ?? Directory.systemTemp.path;
  final baseDir = File(dbPath).parent.path;
  return AudioStorageManager(baseStoragePath: baseDir);
});

final audioAssetDaoProvider = Provider<AudioAssetDao>((ref) {
  final db = AppDatabase.instance.database;
  return AudioAssetDao(db);
});

final audioCoverageAuditorProvider = Provider<AudioCoverageAuditor>((ref) {
  final db = AppDatabase.instance.database;
  return AudioCoverageAuditor(db);
});

final audioCoverageReportProvider = FutureProvider<AudioCoverageReport>((ref) async {
  final auditor = ref.watch(audioCoverageAuditorProvider);
  return auditor.auditCoverage();
});

class AudioPacksNotifier extends AsyncNotifier<List<AudioPackInfo>> {
  late AudioStorageManager _storageManager;
  late AudioAssetDao _dao;

  @override
  Future<List<AudioPackInfo>> build() async {
    _storageManager = ref.watch(audioStorageManagerProvider);
    _dao = ref.watch(audioAssetDaoProvider);
    return _loadPacks();
  }

  Future<List<AudioPackInfo>> _loadPacks() async {
    // Official curated Audio Pack catalog (Pinyin + HSK 1 to 6)
    final catalog = [
      const AudioPackInfo(
        packId: 'audio_pinyin',
        title: 'Pinyin Foundation Audio Pack',
        hskLevel: 0,
        version: '1.0.0',
        totalFiles: 114,
        sizeBytes: 8388608, // ~8 MB
        downloadUrl: 'https://raw.githubusercontent.com/FamAnVMU/hi-chai-ni/main/content_packs_cdn/audio/audio_pinyin.zip',
        sha256Checksum: '',
      ),
      const AudioPackInfo(
        packId: 'audio_hsk1',
        title: 'HSK 1 Standard Audio Pack',
        hskLevel: 1,
        version: '1.0.0',
        totalFiles: 165,
        sizeBytes: 15728640, // ~15 MB
        downloadUrl: 'https://raw.githubusercontent.com/FamAnVMU/hi-chai-ni/main/content_packs_cdn/audio/audio_hsk1.zip',
        sha256Checksum: '',
      ),
      const AudioPackInfo(
        packId: 'audio_hsk2',
        title: 'HSK 2 Standard Audio Pack',
        hskLevel: 2,
        version: '1.0.0',
        totalFiles: 170,
        sizeBytes: 16777216, // ~16 MB
        downloadUrl: 'https://raw.githubusercontent.com/FamAnVMU/hi-chai-ni/main/content_packs_cdn/audio/audio_hsk2.zip',
        sha256Checksum: '',
      ),
      const AudioPackInfo(
        packId: 'audio_hsk3',
        title: 'HSK 3 Standard Audio Pack',
        hskLevel: 3,
        version: '1.0.0',
        totalFiles: 320,
        sizeBytes: 31457280, // ~30 MB
        downloadUrl: 'https://raw.githubusercontent.com/FamAnVMU/hi-chai-ni/main/content_packs_cdn/audio/audio_hsk3.zip',
        sha256Checksum: '',
      ),
      const AudioPackInfo(
        packId: 'audio_hsk4',
        title: 'HSK 4 Standard Audio Pack',
        hskLevel: 4,
        version: '1.0.0',
        totalFiles: 650,
        sizeBytes: 62914560, // ~60 MB
        downloadUrl: 'https://raw.githubusercontent.com/FamAnVMU/hi-chai-ni/main/content_packs_cdn/audio/audio_hsk4.zip',
        sha256Checksum: '',
      ),
      const AudioPackInfo(
        packId: 'audio_hsk5',
        title: 'HSK 5 Advanced Audio Pack',
        hskLevel: 5,
        version: '1.0.0',
        totalFiles: 1350,
        sizeBytes: 136314880, // ~130 MB
        downloadUrl: 'https://raw.githubusercontent.com/FamAnVMU/hi-chai-ni/main/content_packs_cdn/audio/audio_hsk5.zip',
        sha256Checksum: '',
      ),
      const AudioPackInfo(
        packId: 'audio_hsk6',
        title: 'HSK 6 Mastery Audio Pack',
        hskLevel: 6,
        version: '1.0.0',
        totalFiles: 2600,
        sizeBytes: 262144000, // ~250 MB
        downloadUrl: 'https://raw.githubusercontent.com/FamAnVMU/hi-chai-ni/main/content_packs_cdn/audio/audio_hsk6.zip',
        sha256Checksum: '',
      ),
    ];

    final result = <AudioPackInfo>[];
    for (final pack in catalog) {
      final readyCount = await _dao.getReadyCountByPackage(pack.packId);
      final isReady = readyCount >= (pack.totalFiles * 0.8).toInt() && readyCount > 0;
      result.add(pack.copyWith(
        status: isReady ? 'ready' : 'not_downloaded',
        progress: isReady ? 1.0 : 0.0,
      ));
    }
    return result;
  }

  Future<void> deletePack(String packId) async {
    await _storageManager.deletePackAudio(packId);
    await _dao.deleteAssetsByPackage(packId);
    state = AsyncData(await _loadPacks());
    ref.invalidate(audioCoverageReportProvider);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _loadPacks());
    ref.invalidate(audioCoverageReportProvider);
  }
}

final audioPacksProvider = AsyncNotifierProvider<AudioPacksNotifier, List<AudioPackInfo>>(
  AudioPacksNotifier.new,
);
