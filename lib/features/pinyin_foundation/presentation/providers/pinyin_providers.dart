import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../data/pinyin_repository.dart';
import '../../domain/models/pinyin_models.dart';

final pinyinRepositoryProvider = Provider<PinyinRepository>((ref) {
  final db = AppDatabase.instance.database;
  return PinyinRepository(db);
});

final pinyinUnitsProvider = Provider<List<PinyinUnit>>((ref) {
  final repo = ref.watch(pinyinRepositoryProvider);
  return repo.getUnits();
});

final pinyinProgressMapProvider = FutureProvider<Map<String, PinyinProgressRecord>>((ref) async {
  final repo = ref.watch(pinyinRepositoryProvider);
  return repo.getAllProgress();
});

final pinyinCompletionRateProvider = FutureProvider<double>((ref) async {
  final repo = ref.watch(pinyinRepositoryProvider);
  return repo.getOverallCompletionRate();
});
