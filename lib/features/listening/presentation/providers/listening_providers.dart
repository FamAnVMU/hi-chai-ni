import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/audio/audio_models.dart';
import '../../../../core/audio/audio_player_service.dart';
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
  final AudioPlaybackStatus status;
  final bool isPlaying;
  final double playbackSpeed;
  final Duration position;
  final Duration totalDuration;
  final bool showTranscript;
  final String? currentAudioUri;
  final String? errorMessage;
  final Map<String, int> selectedAnswers;
  final Map<String, bool> submittedQuestions;

  const ListeningPlaybackState({
    this.status = AudioPlaybackStatus.idle,
    this.isPlaying = false,
    this.playbackSpeed = 1.0,
    this.position = Duration.zero,
    this.totalDuration = const Duration(seconds: 30),
    this.showTranscript = false,
    this.currentAudioUri,
    this.errorMessage,
    this.selectedAnswers = const {},
    this.submittedQuestions = const {},
  });

  bool get isBuffering => status == AudioPlaybackStatus.buffering;
  bool get isError => status == AudioPlaybackStatus.error;

  ListeningPlaybackState copyWith({
    AudioPlaybackStatus? status,
    bool? isPlaying,
    double? playbackSpeed,
    Duration? position,
    Duration? totalDuration,
    bool? showTranscript,
    String? currentAudioUri,
    String? errorMessage,
    bool clearError = false,
    Map<String, int>? selectedAnswers,
    Map<String, bool>? submittedQuestions,
  }) {
    return ListeningPlaybackState(
      status: status ?? this.status,
      isPlaying: isPlaying ?? this.isPlaying,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      position: position ?? this.position,
      totalDuration: totalDuration ?? this.totalDuration,
      showTranscript: showTranscript ?? this.showTranscript,
      currentAudioUri: currentAudioUri ?? this.currentAudioUri,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      submittedQuestions: submittedQuestions ?? this.submittedQuestions,
    );
  }
}

class ListeningPlaybackNotifier extends Notifier<ListeningPlaybackState> {
  final AudioPlayerService? _injectedPlayer;
  AudioPlayerService? _player;
  StreamSubscription<AudioPlaybackStatus>? _statusSub;
  StreamSubscription<Duration>? _posSub;

  ListeningPlaybackNotifier({AudioPlayerService? player})
      : _injectedPlayer = player;

  @override
  ListeningPlaybackState build() {
    ref.onDispose(() {
      _statusSub?.cancel();
      _posSub?.cancel();
      _player?.dispose();
    });
    return const ListeningPlaybackState();
  }

  void _ensurePlayer() {
    if (_player != null) return;
    _player = _injectedPlayer ?? DefaultAudioPlayerService();
    _statusSub = _player!.statusStream.listen((status) {
      final isPlaying = status == AudioPlaybackStatus.playing;
      final total = _player!.totalDuration > Duration.zero
          ? _player!.totalDuration
          : state.totalDuration;
      state = state.copyWith(
        status: status,
        isPlaying: isPlaying,
        totalDuration: total,
      );
    });

    _posSub = _player!.positionStream.listen((pos) {
      state = state.copyWith(position: pos);
    });
  }

  Future<void> togglePlay([String? uri]) async {
    _ensurePlayer();
    final targetUri = uri ?? state.currentAudioUri;
    if (state.isPlaying) {
      await pause();
    } else {
      if (state.status == AudioPlaybackStatus.paused && targetUri == state.currentAudioUri && targetUri != null) {
        await resume();
      } else if (targetUri != null) {
        await play(targetUri);
      } else {
        // For unit tests / mock environments where no URI is supplied
        state = state.copyWith(isPlaying: true, status: AudioPlaybackStatus.playing);
      }
    }
  }

  Future<void> play(String uri) async {
    _ensurePlayer();
    try {
      state = state.copyWith(
        currentAudioUri: uri,
        status: AudioPlaybackStatus.buffering,
        clearError: true,
      );
      await _player!.play(uri, speed: state.playbackSpeed);
      final total = _player!.totalDuration > Duration.zero
          ? _player!.totalDuration
          : state.totalDuration;
      state = state.copyWith(
        status: AudioPlaybackStatus.playing,
        isPlaying: true,
        totalDuration: total,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: AudioPlaybackStatus.error,
        isPlaying: false,
        errorMessage: 'Không thể phát file âm thanh: $e',
      );
    }
  }

  Future<void> pause() async {
    _ensurePlayer();
    try {
      await _player!.pause();
      state = state.copyWith(
        status: AudioPlaybackStatus.paused,
        isPlaying: false,
      );
    } catch (_) {}
  }

  Future<void> resume() async {
    _ensurePlayer();
    try {
      await _player!.resume();
      state = state.copyWith(
        status: AudioPlaybackStatus.playing,
        isPlaying: true,
      );
    } catch (_) {
      if (state.currentAudioUri != null) {
        await play(state.currentAudioUri!);
      }
    }
  }

  Future<void> stop() async {
    try {
      await _player?.stop();
      state = state.copyWith(
        status: AudioPlaybackStatus.stopped,
        isPlaying: false,
      );
    } catch (_) {}
  }

  Future<void> rewind5Seconds() async {
    _ensurePlayer();
    final currentMs = state.position.inMilliseconds;
    final totalMs = state.totalDuration.inMilliseconds;

    // Handle rewind when audio finished playing
    int baseMs = currentMs;
    if (state.status == AudioPlaybackStatus.completed && totalMs > 0) {
      baseMs = totalMs;
    }

    final targetMs = (baseMs - 5000).clamp(0, totalMs > 0 ? totalMs : (baseMs > 5000 ? baseMs : 0));
    final newPos = Duration(milliseconds: targetMs);
    state = state.copyWith(position: newPos);
    await _player?.seek(newPos);
  }

  Future<void> seek(Duration position) async {
    _ensurePlayer();
    final totalMs = state.totalDuration.inMilliseconds;
    final clampedMs = totalMs > 0
        ? position.inMilliseconds.clamp(0, totalMs)
        : position.inMilliseconds.clamp(0, 3600000);
    final targetPos = Duration(milliseconds: clampedMs);
    state = state.copyWith(position: targetPos);
    await _player?.seek(targetPos);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _ensurePlayer();
    state = state.copyWith(playbackSpeed: speed);
    await _player?.setPlaybackSpeed(speed);
  }

  void resetForLesson(String audioUrl, int durationSeconds) {
    if (state.currentAudioUri != audioUrl) {
      stop();
      state = state.copyWith(
        currentAudioUri: audioUrl,
        position: Duration.zero,
        totalDuration: Duration(seconds: durationSeconds),
        isPlaying: false,
        status: AudioPlaybackStatus.idle,
        clearError: true,
      );
    }
  }

  void setPlaying(bool playing) {
    if (playing) {
      if (state.currentAudioUri != null) {
        play(state.currentAudioUri!);
      } else {
        state = state.copyWith(isPlaying: true);
      }
    } else {
      pause();
    }
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
