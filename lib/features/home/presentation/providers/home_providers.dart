import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import 'package:hi_chinese/features/vocabulary_srs/vocabulary_srs.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/home_repository.dart';
import '../../domain/models/home_dashboard_data.dart';

/// Provider exposing the [HomeRepository] instance tied to the active SQLite database.
final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  final db = AppDatabase.instance.database;
  final srsRepo = ref.watch(srsRepositoryProvider);
  return HomeRepository(db, srsRepository: srsRepo);
});

/// Async notifier managing real-time state of the Home dashboard.
/// Automatically updates when profile or SRS due counts change.
class HomeDashboardNotifier extends AsyncNotifier<HomeDashboardData> {
  @override
  Future<HomeDashboardData> build() async {
    // Re-evaluate if srsDueCount changes or profile changes
    ref.watch(srsDueCountProvider);
    final profileAsync = ref.watch(userProfileProvider);
    final profile = profileAsync.value;

    final repo = ref.watch(homeRepositoryProvider);
    return await repo.getDashboardData(
      learnerName: profile?.displayName,
      targetHskLevel: profile?.currentHskLevel,
      dailyGoalMinutes: profile?.dailyMinutes,
    );
  }

  /// Manually triggers a pull-to-refresh reload of all live stats.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(homeRepositoryProvider);
      final profile = ref.read(userProfileProvider).value;
      return await repo.getDashboardData(
        learnerName: profile?.displayName,
        targetHskLevel: profile?.currentHskLevel,
        dailyGoalMinutes: profile?.dailyMinutes,
      );
    });
  }
}

/// Global provider for the live Home Dashboard state.
final homeDashboardProvider =
    AsyncNotifierProvider<HomeDashboardNotifier, HomeDashboardData>(
  HomeDashboardNotifier.new,
);
