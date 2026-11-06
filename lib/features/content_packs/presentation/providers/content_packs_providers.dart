import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../curriculum/data/content_pack_loader.dart';
import '../../../curriculum/domain/models/content_pack_models.dart';
import '../../data/content_pack_remote_service.dart';

class ContentPackItemState {
  final RemoteContentPackInfo info;
  final bool isInstalled;
  final bool isDownloading;
  final double progress;
  final String? error;

  const ContentPackItemState({
    required this.info,
    required this.isInstalled,
    this.isDownloading = false,
    this.progress = 0.0,
    this.error,
  });

  ContentPackItemState copyWith({
    bool? isInstalled,
    bool? isDownloading,
    double? progress,
    String? error,
  }) {
    return ContentPackItemState(
      info: info,
      isInstalled: isInstalled ?? this.isInstalled,
      isDownloading: isDownloading ?? this.isDownloading,
      progress: progress ?? this.progress,
      error: error,
    );
  }
}

class ContentPacksNotifier extends AsyncNotifier<List<ContentPackItemState>> {
  late ContentPackRemoteService _service;

  @override
  Future<List<ContentPackItemState>> build() async {
    final db = AppDatabase.instance.database;
    _service = ContentPackRemoteService(db: db);
    return _fetchStates();
  }

  Future<List<ContentPackItemState>> _fetchStates() async {
    final catalog = ContentPackRemoteService.getAvailablePacks();
    final items = <ContentPackItemState>[];

    for (final pack in catalog) {
      final installed = await _service.isPackInstalled(pack.packId);
      items.add(ContentPackItemState(
        info: pack,
        isInstalled: installed,
      ));
    }
    return items;
  }

  Future<bool> installPack(String packId) async {
    List<ContentPackItemState>? currentList = state.value;
    if (currentList == null) {
      currentList = await _fetchStates();
      state = AsyncData(currentList);
    }

    final targetIdx = currentList.indexWhere((p) => p.info.packId == packId);
    if (targetIdx == -1) return false;

    final target = currentList[targetIdx];

    // Update UI state to downloading
    final updatedList = List<ContentPackItemState>.from(currentList);
    updatedList[targetIdx] = target.copyWith(isDownloading: true, progress: 0.1, error: null);
    state = AsyncData(updatedList);

    try {
      if (target.info.isBundled) {
        // Install from local bundled assets
        final assetPath = target.info.downloadUrl.replaceFirst('bundled:', '');
        final rawJson = await rootBundle.loadString(assetPath);
        final loader = ContentPackLoader(AppDatabase.instance.database);
        final result = await loader.loadPackFromJson(rawJson);

        if (result.isSuccess) {
          updatedList[targetIdx] = target.copyWith(
            isInstalled: true,
            isDownloading: false,
            progress: 1.0,
          );
          state = AsyncData(updatedList);
          ref.invalidate(isHskLevelInstalledProvider(target.info.hskLevel));
          return true;
        } else {
          updatedList[targetIdx] = target.copyWith(
            isDownloading: false,
            error: result.errorMessage,
          );
          state = AsyncData(updatedList);
          return false;
        }
      } else {
        // Download from GitHub CDN / Remote
        var result = await _service.downloadAndInstallPack(
          packInfo: target.info,
          onProgress: (p) {
            final list = List<ContentPackItemState>.from(state.value ?? []);
            final idx = list.indexWhere((item) => item.info.packId == packId);
            if (idx != -1) {
              list[idx] = list[idx].copyWith(progress: p);
              state = AsyncData(list);
            }
          },
        );

        // Offline / testing fallback: try loading from local assets if remote download failed
        if (!result.isSuccess) {
          final fallbackAssetPath =
              'assets/data/content_packs/hsk${target.info.hskLevel}/${target.info.packId}.json';
          try {
            final rawJson = await rootBundle.loadString(fallbackAssetPath);
            final loader = ContentPackLoader(AppDatabase.instance.database);
            result = await loader.loadPackFromJson(rawJson);
          } catch (_) {}
        }

        if (result.isSuccess) {
          updatedList[targetIdx] = target.copyWith(
            isInstalled: true,
            isDownloading: false,
            progress: 1.0,
          );
          state = AsyncData(updatedList);
          ref.invalidate(isHskLevelInstalledProvider(target.info.hskLevel));
          return true;
        } else {
          updatedList[targetIdx] = target.copyWith(
            isDownloading: false,
            error: result.errorMessage,
          );
          state = AsyncData(updatedList);
          return false;
        }
      }
    } catch (e) {
      // Offline / testing fallback on unhandled exception
      try {
        final fallbackAssetPath =
            'assets/data/content_packs/hsk${target.info.hskLevel}/${target.info.packId}.json';
        final rawJson = await rootBundle.loadString(fallbackAssetPath);
        final loader = ContentPackLoader(AppDatabase.instance.database);
        final fallbackResult = await loader.loadPackFromJson(rawJson);
        if (fallbackResult.isSuccess) {
          updatedList[targetIdx] = target.copyWith(
            isInstalled: true,
            isDownloading: false,
            progress: 1.0,
          );
          state = AsyncData(updatedList);
          ref.invalidate(isHskLevelInstalledProvider(target.info.hskLevel));
          return true;
        }
      } catch (_) {}

      updatedList[targetIdx] = target.copyWith(
        isDownloading: false,
        error: e.toString(),
      );
      state = AsyncData(updatedList);
      return false;
    }
  }

  Future<bool> uninstallPack(String packId) async {
    try {
      final success = await _service.uninstallPack(packId);
      if (success) {
        await refresh();
        return true;
      }
      return false;
    } catch (e) {
      final currentList = state.value;
      if (currentList != null) {
        final targetIdx = currentList.indexWhere((p) => p.info.packId == packId);
        if (targetIdx != -1) {
          final updatedList = List<ContentPackItemState>.from(currentList);
          updatedList[targetIdx] = updatedList[targetIdx].copyWith(error: e.toString());
          state = AsyncData(updatedList);
        }
      }
      return false;
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _fetchStates());
  }
}

final contentPacksProvider = AsyncNotifierProvider<ContentPacksNotifier, List<ContentPackItemState>>(
  ContentPacksNotifier.new,
);

/// Provider exposing the active [ContentPackRemoteService].
final contentPackRemoteServiceProvider = Provider<ContentPackRemoteService?>((ref) {
  if (!AppDatabase.instance.isOpen) return null;
  return ContentPackRemoteService(db: AppDatabase.instance.database);
});

/// Provider checking whether a given HSK level's content pack is installed.
/// HSK 1 and 2 are always bundled/available (returns true).
/// HSK 3-6 require checking whether their pack has been installed in SQLite.
final isHskLevelInstalledProvider = FutureProvider.family<bool, int>((ref, hskLevel) async {
  final service = ref.watch(contentPackRemoteServiceProvider);
  if (hskLevel <= 2) {
    if (service != null) {
      final dbInstalled = await service.isHskLevelInstalled(hskLevel);
      if (dbInstalled) return true;
    }
    return true;
  }
  if (service == null) return false;
  return await service.isHskLevelInstalled(hskLevel);
});

/// Provider retrieving the installed [ContentPackManifest] for [hskLevel], or null if not installed.
final hskPackMetadataProvider = FutureProvider.family<ContentPackManifest?, int>((ref, hskLevel) async {
  final service = ref.watch(contentPackRemoteServiceProvider);
  if (service == null) return null;
  return await service.getHskPackManifest(hskLevel);
});
