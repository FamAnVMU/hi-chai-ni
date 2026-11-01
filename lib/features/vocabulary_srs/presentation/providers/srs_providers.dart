import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../data/srs_repository.dart';

/// Provider exposing the SrsRepository instance tied to the active database.
final srsRepositoryProvider = Provider<SrsRepository>((ref) {
  final db = AppDatabase.instance.database;
  return SrsRepository(db);
});

/// Async notifier providing the reactive SRS due cards count.
/// Auto-memoized and refreshed whenever reviews occur.
class SrsDueCountNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    try {
      final repo = ref.watch(srsRepositoryProvider);
      return await repo.getDueCardsCount();
    } catch (_) {
      return 0;
    }
  }

  Future<void> refreshCount() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(srsRepositoryProvider);
      return await repo.getDueCardsCount(forceRefresh: true);
    });
  }
}

final srsDueCountProvider = AsyncNotifierProvider<SrsDueCountNotifier, int>(
  SrsDueCountNotifier.new,
);
