import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/listening_repository.dart';
import '../../domain/models/listening_lesson.dart';

final listeningRepositoryProvider = Provider<ListeningRepository>((ref) {
  return DefaultListeningRepository();
});

final listeningLessonsProvider = FutureProvider.family<List<ListeningLesson>, int?>((ref, hskLevel) async {
  final repo = ref.watch(listeningRepositoryProvider);
  return await repo.getLessons(hskLevel: hskLevel);
});

class ActiveListeningLessonNotifier extends Notifier<ListeningLesson?> {
  @override
  ListeningLesson? build() {
    final lessons = ListeningLesson.defaultLessons;
    return lessons.isNotEmpty ? lessons.first : null;
  }

  void selectLesson(ListeningLesson lesson) {
    state = lesson;
  }
}

final activeListeningLessonProvider = NotifierProvider<ActiveListeningLessonNotifier, ListeningLesson?>(
  ActiveListeningLessonNotifier.new,
);

class ListeningPlaybackState {
  final bool isPlaying;
  final double playbackSpeed;
  final Duration position;
  final Duration totalDuration;
  final bool showTranscript;
  final Map<String, int> selectedAnswers;
  final Map<String, bool> submittedQuestions;

  const ListeningPlaybackState({
    this.isPlaying = false,
    this.playbackSpeed = 1.0,
    this.position = Duration.zero,
    this.totalDuration = const Duration(seconds: 30),
    this.showTranscript = false,
    this.selectedAnswers = const {},
    this.submittedQuestions = const {},
  });

  ListeningPlaybackState copyWith({
    bool? isPlaying,
    double? playbackSpeed,
    Duration? position,
    Duration? totalDuration,
    bool? showTranscript,
    Map<String, int>? selectedAnswers,
    Map<String, bool>? submittedQuestions,
  }) {
    return ListeningPlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      position: position ?? this.position,
      totalDuration: totalDuration ?? this.totalDuration,
      showTranscript: showTranscript ?? this.showTranscript,
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      submittedQuestions: submittedQuestions ?? this.submittedQuestions,
    );
  }
}

class ListeningPlaybackNotifier extends Notifier<ListeningPlaybackState> {
  @override
  ListeningPlaybackState build() {
    return const ListeningPlaybackState();
  }

  void togglePlay() {
    state = state.copyWith(isPlaying: !state.isPlaying);
  }

  void setPlaying(bool playing) {
    state = state.copyWith(isPlaying: playing);
  }

  void setPlaybackSpeed(double speed) {
    state = state.copyWith(playbackSpeed: speed);
  }

  void toggleTranscript() {
    state = state.copyWith(showTranscript: !state.showTranscript);
  }

  void selectAnswer(String questionId, int optionIndex) {
    final updated = Map<String, int>.from(state.selectedAnswers);
    updated[questionId] = optionIndex;
    state = state.copyWith(selectedAnswers: updated);
  }

  void submitQuestion(String questionId) {
    final updated = Map<String, bool>.from(state.submittedQuestions);
    updated[questionId] = true;
    state = state.copyWith(submittedQuestions: updated);
  }
}

final listeningPlaybackProvider = NotifierProvider<ListeningPlaybackNotifier, ListeningPlaybackState>(
  ListeningPlaybackNotifier.new,
);
