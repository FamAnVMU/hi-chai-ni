import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../data/reading_repository.dart';
import '../../domain/models/reading_models.dart';

final readingRepositoryProvider = Provider<ReadingRepository>((ref) {
  final db = AppDatabase.instance.database;
  return DefaultReadingRepository(db);
});

class SelectedHskFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setLevel(int? lvl) => state = lvl;
}

final selectedHskFilterProvider =
    NotifierProvider<SelectedHskFilterNotifier, int?>(
  SelectedHskFilterNotifier.new,
);

class ReadingDisplayModeNotifier extends Notifier<ReadingDisplayMode> {
  @override
  ReadingDisplayMode build() => ReadingDisplayMode.full;

  void setMode(ReadingDisplayMode mode) => state = mode;
}

final readingDisplayModeProvider =
    NotifierProvider<ReadingDisplayModeNotifier, ReadingDisplayMode>(
  ReadingDisplayModeNotifier.new,
);

final readingPassagesProvider =
    FutureProvider.autoDispose<List<ReadingPassage>>((ref) async {
  final hsk = ref.watch(selectedHskFilterProvider);
  final repo = ref.watch(readingRepositoryProvider);
  return await repo.getPassages(hskLevel: hsk);
});

final activePassageProgressProvider =
    FutureProvider.autoDispose.family<ReadingProgress?, String>((ref, passageId) async {
  final repo = ref.watch(readingRepositoryProvider);
  return await repo.getProgress(passageId);
});
