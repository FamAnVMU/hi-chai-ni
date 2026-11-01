import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import 'package:hi_chinese/features/vocabulary_srs/vocabulary_srs.dart';
import '../../data/home_repository.dart';
import '../../domain/models/home_dashboard_data.dart';

/// Provider exposing the [HomeRepository] instance tied to the active SQLite database.
final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final db = AppDatabase.instance.database;
  final srsRepo = ref.watch(srsRepositoryProvider);
  return HomeRepository(db, srsRepository: srsRepo);
});

/// Async notifier managing real-time state of the Home dashboard.
class HomeDashboardNotifier extends AsyncNotifier<HomeDashboardData> {
  @override
  Future<HomeDashboardData> build() async {
    // Re-evaluate if srsDueCount changes
    ref.watch(srsDueCountProvider);

    final repo = ref.watch(homeRepositoryProvider);
    return await repo.getDashboardData();
  }

  /// Manually triggers a pull-to-refresh reload of all live stats.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(homeRepositoryProvider);
      return await repo.getDashboardData();
    });
  }
}

/// Global provider for the live Home Dashboard state.
final homeDashboardProvider =
    AsyncNotifierProvider<HomeDashboardNotifier, HomeDashboardData>(
  HomeDashboardNotifier.new,
);
