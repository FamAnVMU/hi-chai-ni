import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../data/practice_repository.dart';
import '../../domain/engine/practice_scoring_engine.dart';
import '../../domain/models/practice_models.dart';

final practiceRepositoryProvider = Provider<PracticeRepository>((ref) {
  final db = AppDatabase.instance.database;
  return DefaultPracticeRepository(db);
});

final practiceScoringEngineProvider = Provider<PracticeScoringEngine>((ref) {
  return const PracticeScoringEngine();
});

final activePracticeSessionProvider = FutureProvider.family<PracticeSession?, String?>((ref, skill) async {
  final repo = ref.watch(practiceRepositoryProvider);
  return repo.getActiveSession(skill: skill);
});

final practiceExercisesProvider = FutureProvider.family<List<ExerciseDefinition>, ({String? skill, int? hskLevel, ExerciseType? type})>(
  (ref, filter) async {
    final repo = ref.watch(practiceRepositoryProvider);
    return repo.getExercises(
      skill: filter.skill,
      hskLevel: filter.hskLevel,
      type: filter.type,
    );
  },
);
