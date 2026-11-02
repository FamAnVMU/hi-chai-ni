import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../curriculum/data/content_pack_loader.dart';
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
    final currentList = state.value;
    if (currentList == null) return false;

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
        final result = await _service.downloadAndInstallPack(
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

        if (result.isSuccess) {
          updatedList[targetIdx] = target.copyWith(
            isInstalled: true,
            isDownloading: false,
            progress: 1.0,
          );
          state = AsyncData(updatedList);
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
      updatedList[targetIdx] = target.copyWith(
        isDownloading: false,
        error: e.toString(),
      );
      state = AsyncData(updatedList);
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
