import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_constants.dart';
import '../../domain/models/user_profile.dart';
import '../../../roadmap/domain/models/roadmap_models.dart';

abstract class ProfileRepository {
  Future<UserProfile> getProfile();
  Future<void> saveProfile(UserProfile profile);
  Future<void> updateGoal({
    required int targetHskLevel,
    required int dailyMinutes,
    required LearnerPurpose purpose,
    required String reason,
  });
  Future<List<GoalHistoryRecord>> getGoalHistory();
}

class DefaultProfileRepository implements ProfileRepository {
  final Database _db;

  DefaultProfileRepository(this._db);

  @override
  Future<UserProfile> getProfile() async {
    final rows = await _db.query(
      DatabaseConstants.tableUserProfiles,
      limit: 1,
    );

    if (rows.isEmpty) {
      final defaultProf = UserProfile.defaultProfile();
      await saveProfile(defaultProf);
      return defaultProf;
    }

    return UserProfile.fromMap(rows.first);
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    final updatedProfile = profile.copyWith(updatedAt: DateTime.now().toUtc());
    await _db.insert(
      DatabaseConstants.tableUserProfiles,
      updatedProfile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateGoal({
    required int targetHskLevel,
    required int dailyMinutes,
    required LearnerPurpose purpose,
    required String reason,
  }) async {
    final currentProfile = await getProfile();
    final now = DateTime.now().toUtc();

    await _db.transaction((txn) async {
      // 1. Record in goal_history table
      final historyRecord = GoalHistoryRecord(
        id: 'gh_${now.millisecondsSinceEpoch}',
        previousTargetHsk: currentProfile.targetHskLevel,
        newTargetHsk: targetHskLevel,
        previousDailyMinutes: currentProfile.dailyMinutes,
        newDailyMinutes: dailyMinutes,
        previousPurpose: currentProfile.purpose,
        newPurpose: purpose,
        reason: reason.trim().isEmpty ? 'Điều chỉnh mục tiêu học tập' : reason.trim(),
        changedAt: now,
      );

      await txn.insert(
        DatabaseConstants.tableGoalHistory,
        historyRecord.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Update user_profiles table
      final updatedProfile = currentProfile.copyWith(
        targetHskLevel: targetHskLevel,
        dailyMinutes: dailyMinutes,
        purpose: purpose,
        updatedAt: now,
      );

      await txn.insert(
        DatabaseConstants.tableUserProfiles,
        updatedProfile.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 3. Keep roadmap learner_goals table in sync
      final nowUtcStr = now.toIso8601String();
      await txn.update(
        DatabaseConstants.tableLearnerGoals,
        {'is_active': 0, 'updated_at': nowUtcStr},
        where: 'is_active = 1',
      );

      await txn.insert(
        DatabaseConstants.tableLearnerGoals,
        {
          'id': 'goal_${now.millisecondsSinceEpoch}',
          'target_hsk_level': targetHskLevel,
          'purpose': purpose.name,
          'timeframe': currentProfile.timeframe.name,
          'daily_minutes': dailyMinutes,
          'is_active': 1,
          'created_at': nowUtcStr,
          'updated_at': nowUtcStr,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<List<GoalHistoryRecord>> getGoalHistory() async {
    final rows = await _db.query(
      DatabaseConstants.tableGoalHistory,
      orderBy: 'changed_at DESC',
    );

    return rows.map((r) => GoalHistoryRecord.fromMap(r)).toList();
  }
}
