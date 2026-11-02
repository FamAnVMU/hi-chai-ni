import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../data/learning_pipeline_coordinator.dart';
import '../../domain/models/mastery_state.dart';

final learningPipelineCoordinatorProvider = Provider<LearningPipelineCoordinator>((ref) {
  final db = AppDatabase.instance.database;
  return LearningPipelineCoordinator(db);
});

final masterySummaryProvider = FutureProvider.autoDispose<Map<MasteryState, int>>((ref) async {
  final coordinator = ref.watch(learningPipelineCoordinatorProvider);
  return coordinator.getMasterySummary();
});
