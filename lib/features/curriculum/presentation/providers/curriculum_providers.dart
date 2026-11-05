import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_constants.dart';
import '../../data/curriculum_repository.dart';
import '../../domain/engine/prerequisite_engine.dart';
import '../../domain/models/curriculum_models.dart';
import '../../domain/models/content_item_models.dart';

final curriculumRepositoryProvider = Provider<CurriculumRepository>((ref) {
  final db = ref.watch(appDatabaseProvider).database;
  return CurriculumRepository(db);
});

final prerequisiteEngineProvider = Provider<PrerequisiteEngine>((ref) {
  final db = ref.watch(appDatabaseProvider).database;
  return PrerequisiteEngine(db);
});

final curriculumUnitsProvider = FutureProvider.family<List<CurriculumUnit>, String>((ref, curriculumId) async {
  final repo = ref.watch(curriculumRepositoryProvider);
  return repo.getUnits(curriculumId);
});

final curriculumUnitsWithLessonsProvider = FutureProvider.family<List<CurriculumUnit>, String>((ref, curriculumId) async {
  final repo = ref.watch(curriculumRepositoryProvider);
  return repo.getUnitsWithLessons(curriculumId);
});

final curriculumLessonsProvider = FutureProvider.family<List<CurriculumLesson>, String>((ref, unitId) async {
  final repo = ref.watch(curriculumRepositoryProvider);
  return repo.getLessons(unitId);
});

final allCurriculumLessonsProvider = FutureProvider.family<List<CurriculumLesson>, String>((ref, curriculumId) async {
  final repo = ref.watch(curriculumRepositoryProvider);
  return repo.getAllLessons(curriculumId);
});

final contentItemProvider = FutureProvider.family<ContentItem?, String>((ref, contentId) async {
  final repo = ref.watch(curriculumRepositoryProvider);
  return repo.getContentItem(contentId);
});

final exitExamProvider = FutureProvider.family<Map<String, dynamic>?, int>((ref, level) async {
  final repo = ref.watch(curriculumRepositoryProvider);
  return repo.getExitExam(level);
});

/// Checks if the learner has completed at least one curriculum lesson.
/// Used to gate advanced learning and review features for fresh learners.
final hasCompletedLessonsProvider = FutureProvider<bool>((ref) async {
  final db = ref.watch(appDatabaseProvider).database;
  try {
    final rows = await db.rawQuery(
      "SELECT COUNT(*) as count FROM ${DatabaseConstants.tableCurriculumLessons} WHERE status = 'completed'",
    );
    final count = (rows.first['count'] as num?)?.toInt() ?? 0;
    if (count > 0) return true;
  } catch (_) {}

  try {
    final rows = await db.rawQuery(
      "SELECT COUNT(*) as count FROM ${DatabaseConstants.tableLearningActivities} WHERE activity_type = 'lesson'",
    );
    final count = (rows.first['count'] as num?)?.toInt() ?? 0;
    return count > 0;
  } catch (_) {}

  return false;
});

