import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../data/repositories/profile_repository.dart';
import '../../domain/models/user_profile.dart';
import '../../../roadmap/domain/models/roadmap_models.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final db = ref.watch(appDatabaseProvider).database;
  return DefaultProfileRepository(db);
});

class UserProfileNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    final repo = ref.watch(profileRepositoryProvider);
    return await repo.getProfile();
  }

  Future<void> updateProfile({
    String? displayName,
    int? currentHskLevel,
    int? targetHskLevel,
    LearnerPurpose? purpose,
    LearnerTimeframe? timeframe,
    int? dailyMinutes,
    List<String>? interests,
    String? avatarStyle,
  }) async {
    final current = state.value ?? UserProfile.defaultProfile();
    final updated = current.copyWith(
      displayName: displayName,
      currentHskLevel: currentHskLevel,
      targetHskLevel: targetHskLevel,
      purpose: purpose,
      timeframe: timeframe,
      dailyMinutes: dailyMinutes,
      interests: interests,
      avatarStyle: avatarStyle,
    );

    state = AsyncData(updated);
    final repo = ref.read(profileRepositoryProvider);
    await repo.saveProfile(updated);
  }

  Future<void> updateGoal({
    required int targetHskLevel,
    required int dailyMinutes,
    required LearnerPurpose purpose,
    required String reason,
  }) async {
    final repo = ref.read(profileRepositoryProvider);
    await repo.updateGoal(
      targetHskLevel: targetHskLevel,
      dailyMinutes: dailyMinutes,
      purpose: purpose,
      reason: reason,
    );
    // Refresh both profile and history
    ref.invalidateSelf();
    ref.invalidate(goalHistoryProvider);
  }
}

final userProfileProvider = AsyncNotifierProvider<UserProfileNotifier, UserProfile>(
  UserProfileNotifier.new,
);

final goalHistoryProvider = FutureProvider<List<GoalHistoryRecord>>((ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  return await repo.getGoalHistory();
});
