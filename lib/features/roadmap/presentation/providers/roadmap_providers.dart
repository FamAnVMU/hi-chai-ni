import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../data/roadmap_repository.dart';
import '../../domain/models/roadmap_models.dart';

/// Provider for the [RoadmapRepository]
final roadmapRepositoryProvider = Provider<RoadmapRepository>((ref) {
  final db = AppDatabase.instance.database;
  return DefaultRoadmapRepository(db);
});

/// Selected HSK level for viewing in the curriculum roadmap
class SelectedRoadmapLevelNotifier extends Notifier<int> {
  @override
  int build() => 1;

  void selectLevel(int level) => state = level;
}

final selectedRoadmapLevelProvider =
    NotifierProvider<SelectedRoadmapLevelNotifier, int>(
  SelectedRoadmapLevelNotifier.new,
);

/// Notifier providing reactive access to the adaptive roadmap state
class AdaptiveRoadmapNotifier extends AsyncNotifier<LearnerRoadmapState> {
  @override
  Future<LearnerRoadmapState> build() async {
    final repo = ref.watch(roadmapRepositoryProvider);
    return await repo.getAdaptiveRoadmapState();
  }

  /// Update the user's active learning goal
  Future<void> updateGoal(LearnerGoal goal) async {
    state = const AsyncValue.loading();
    final repo = ref.read(roadmapRepositoryProvider);
    await repo.updateGoal(goal);
    // Sync level selector with new target HSK
    ref.read(selectedRoadmapLevelProvider.notifier).selectLevel(goal.targetHskLevel);
    state = await AsyncValue.guard(() => repo.getAdaptiveRoadmapState());
  }

  /// Mark lesson as in-progress (does NOT mark as completed!)
  Future<void> startLesson(String lessonId) async {
    final repo = ref.read(roadmapRepositoryProvider);
    await repo.startLesson(lessonId);
    state = await AsyncValue.guard(() => repo.getAdaptiveRoadmapState());
  }

  /// Mark lesson as completed with an empirical performance score
  Future<void> completeLesson({
    required String lessonId,
    required double score,
  }) async {
    state = const AsyncValue.loading();
    final repo = ref.read(roadmapRepositoryProvider);
    await repo.completeLesson(lessonId: lessonId, score: score);
    state = await AsyncValue.guard(() => repo.getAdaptiveRoadmapState());
  }

  /// Skip a lesson intentionally
  Future<void> skipLesson(String lessonId) async {
    state = const AsyncValue.loading();
    final repo = ref.read(roadmapRepositoryProvider);
    await repo.skipLesson(lessonId);
    state = await AsyncValue.guard(() => repo.getAdaptiveRoadmapState());
  }

  /// Manually refresh the roadmap computation
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final repo = ref.read(roadmapRepositoryProvider);
    state = await AsyncValue.guard(() => repo.getAdaptiveRoadmapState());
  }
}

final adaptiveRoadmapProvider =
    AsyncNotifierProvider<AdaptiveRoadmapNotifier, LearnerRoadmapState>(
  AdaptiveRoadmapNotifier.new,
);
