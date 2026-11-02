import '../../domain/models/listening_lesson.dart';

abstract class ListeningRepository {
  Future<List<ListeningLesson>> getLessons({int? hskLevel});
  Future<ListeningLesson?> getLessonById(String id);
}

class DefaultListeningRepository implements ListeningRepository {
  final List<ListeningLesson> _lessons;

  DefaultListeningRepository({List<ListeningLesson>? customLessons})
      : _lessons = customLessons ?? ListeningLesson.defaultLessons;

  @override
  Future<List<ListeningLesson>> getLessons({int? hskLevel}) async {
    if (hskLevel == null) return List.unmodifiable(_lessons);
    return _lessons.where((l) => l.hskLevel == hskLevel).toList();
  }

  @override
  Future<ListeningLesson?> getLessonById(String id) async {
    try {
      return _lessons.firstWhere((l) => l.id == id);
    } catch (_) {
      return null;
    }
  }
}
