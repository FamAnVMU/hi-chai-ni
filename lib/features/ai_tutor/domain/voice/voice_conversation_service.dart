import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/audio/audio_models.dart';
import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/audio/audio_recorder_service.dart';
import '../../../../core/utils/app_lifecycle_manager.dart';
import '../../data/repositories/ai_tutor_repository.dart';
import '../models/tutor_persona.dart';
import '../models/tutor_scenario.dart';
import 'voice_conversation_models.dart';

/// Contract for AI Tutor Voice Conversation operations.
abstract class VoiceConversationService {
  VoiceConversationStatus get status;
  Stream<VoiceConversationStatus> get statusStream;
  Stream<double> get amplitudeStream;
  Stream<List<VoiceTranscriptSegment>> get transcriptStream;
  List<VoiceTranscriptSegment> get transcripts;
  bool get isMuted;
  VoiceEngineMode get engineMode;

  Future<bool> checkPermission();
  Future<void> startMicTest();
  Future<void> stopMicTest();
  Future<void> previewPersonaVoice(TutorPersona persona);

  Future<void> startSession({
    required String sessionId,
    required TutorPersona persona,
    required TutorScenario scenario,
    int learnerHskLevel = 1,
  });

  Future<void> endSession();
  Future<void> interrupt();
  Future<void> toggleMute();

  /// Simulates or passes recognized speech input from STT / Live audio feed.
  Future<void> submitSpeechInput(String userText);

  /// Called on OS lifecycle transitions to guarantee Android policy compliance.
  void handleLifecycleTransition(AppLifecycleState state);

  void dispose();
}

/// Concrete production-ready implementation of [VoiceConversationService].
class DefaultVoiceConversationService implements VoiceConversationService {
  final AudioRecorderService recorder;
  final AudioPlayerService player;
  final AiTutorRepository repository;
  final VoiceEngineMode mode;

  VoiceConversationStatus _status = VoiceConversationStatus.idle;
  bool _isMuted = false;
  String? _activeSessionId;
  TutorPersona _activePersona = TutorPersonas.qiaoqiao;
  TutorScenario _activeScenario = TutorScenarios.freeChat;
  int _learnerHskLevel = 1;

  final List<VoiceTranscriptSegment> _transcripts = [];

  final StreamController<VoiceConversationStatus> _statusController =
      StreamController<VoiceConversationStatus>.broadcast();
  final StreamController<double> _amplitudeController =
      StreamController<double>.broadcast();
  final StreamController<List<VoiceTranscriptSegment>> _transcriptController =
      StreamController<List<VoiceTranscriptSegment>>.broadcast();

  StreamSubscription<double>? _recorderAmpSub;
  StreamSubscription<AudioPlaybackStatus>? _playerStatusSub;

  DefaultVoiceConversationService({
    required this.recorder,
    required this.player,
    required this.repository,
    this.mode = VoiceEngineMode.turnBasedAudio,
  }) {
    // Pipe recorder amplitude into our amplitude stream for UI waveform visualizer
    _recorderAmpSub = recorder.amplitudeStream.listen((amp) {
      if (!_isMuted &&
          (_status == VoiceConversationStatus.listening ||
              _status == VoiceConversationStatus.idle)) {
        _amplitudeController.add(amp);
      } else {
        _amplitudeController.add(0.0);
      }
    });

    // Listen to player status to auto-transition back to listening when AI finishes speaking
    _playerStatusSub = player.statusStream.listen((playStatus) {
      if (_status == VoiceConversationStatus.speaking &&
          (playStatus == AudioPlaybackStatus.completed ||
              playStatus == AudioPlaybackStatus.stopped)) {
        _setStatus(VoiceConversationStatus.listening);
      }
    });

    // Register with AppLifecycleManager for background microphone safety
    AppLifecycleManager.instance.registerAudioSession(_onLifecycleAbort);
  }

  @override
  VoiceConversationStatus get status => _status;

  @override
  Stream<VoiceConversationStatus> get statusStream => _statusController.stream;

  @override
  Stream<double> get amplitudeStream => _amplitudeController.stream;

  @override
  Stream<List<VoiceTranscriptSegment>> get transcriptStream =>
      _transcriptController.stream;

  @override
  List<VoiceTranscriptSegment> get transcripts => List.unmodifiable(_transcripts);

  @override
  bool get isMuted => _isMuted;

  @override
  VoiceEngineMode get engineMode => mode;

  void _setStatus(VoiceConversationStatus newStatus) {
    if (_status == newStatus) return;
    _status = newStatus;
    _statusController.add(_status);
  }

  void _addTranscript(VoiceTranscriptSegment segment) {
    _transcripts.add(segment);
    _transcriptController.add(List.unmodifiable(_transcripts));
  }

  void _updateLastInterimTranscript(String text, {bool isFinal = false}) {
    if (_transcripts.isNotEmpty && _transcripts.last.isInterim) {
      final last = _transcripts.removeLast();
      _transcripts.add(last.copyWith(text: text, isInterim: !isFinal));
    } else {
      _transcripts.add(VoiceTranscriptSegment(
        id: 'voice_turn_${DateTime.now().millisecondsSinceEpoch}',
        role: 'user',
        text: text,
        isInterim: !isFinal,
        timestamp: DateTime.now(),
      ));
    }
    _transcriptController.add(List.unmodifiable(_transcripts));
  }

  @override
  Future<bool> checkPermission() async {
    _setStatus(VoiceConversationStatus.requestingPermission);
    final granted = await recorder.checkPermission();
    if (!granted) {
      _setStatus(VoiceConversationStatus.error);
      return false;
    }
    _setStatus(VoiceConversationStatus.idle);
    return true;
  }

  @override
  Future<void> startMicTest() async {
    final granted = await recorder.checkPermission();
    if (!granted) {
      _setStatus(VoiceConversationStatus.error);
      return;
    }
    await recorder.startRecording();
  }

  @override
  Future<void> stopMicTest() async {
    await recorder.stopRecording();
    _amplitudeController.add(0.0);
  }

  @override
  Future<void> previewPersonaVoice(TutorPersona persona) async {
    // Play the persona's greeting sample
    final audioUri = persona.voicePreviewSampleUri;
    await player.play(audioUri, speed: 1.0);
  }

  @override
  Future<void> startSession({
    required String sessionId,
    required TutorPersona persona,
    required TutorScenario scenario,
    int learnerHskLevel = 1,
  }) async {
    _activeSessionId = sessionId;
    _activePersona = persona;
    _activeScenario = scenario;
    _learnerHskLevel = learnerHskLevel;
    _isMuted = false;
    _transcripts.clear();

    _setStatus(VoiceConversationStatus.requestingPermission);
    final hasPerm = await recorder.checkPermission();
    if (!hasPerm) {
      _setStatus(VoiceConversationStatus.error);
      return;
    }

    _setStatus(VoiceConversationStatus.connecting);
    await Future.delayed(const Duration(milliseconds: 300));

    // Add initial scenario greeting to transcript
    _addTranscript(VoiceTranscriptSegment(
      id: 'greeting_${DateTime.now().millisecondsSinceEpoch}',
      role: 'assistant',
      text: scenario.initialAiGreetingZh,
      pinyin: scenario.initialAiGreetingPinyin,
      translationVi: scenario.initialAiGreetingVi,
      isInterim: false,
      timestamp: DateTime.now(),
    ));

    // Play greeting audio if persona has voice sample
    _setStatus(VoiceConversationStatus.speaking);
    await player.play(
      persona.voicePreviewSampleUri,
      simulatedDuration: const Duration(seconds: 2),
    );

    // Start listening for student speech
    await recorder.startRecording();
    _setStatus(VoiceConversationStatus.listening);
  }

  @override
  Future<void> submitSpeechInput(String userText) async {
    if (_status != VoiceConversationStatus.listening) return;
    if (userText.trim().isEmpty) return;

    // 1. Show final user transcript segment
    _updateLastInterimTranscript(userText.trim(), isFinal: true);

    // 2. Transition to processing
    _setStatus(VoiceConversationStatus.processing);
    await recorder.pauseRecording();

    try {
      final sessionId = _activeSessionId;
      if (sessionId == null) {
        throw StateError('Cannot submit speech without active session ID.');
      }

      // 3. Delegate to shared AI Tutor Engine
      final tutorResponse = await repository.sendMessage(
        sessionId: sessionId,
        userText: userText.trim(),
        persona: _activePersona,
        scenario: _activeScenario,
        learnerHskLevel: _learnerHskLevel,
      );

      // 4. Add assistant response transcript
      _addTranscript(VoiceTranscriptSegment(
        id: 'asst_${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        text: tutorResponse.replyZh,
        pinyin: tutorResponse.replyPinyin,
        translationVi: tutorResponse.replyVi,
        isInterim: false,
        timestamp: DateTime.now(),
      ));

      // 5. Play response audio
      _setStatus(VoiceConversationStatus.speaking);
      await player.play(
        _activePersona.voicePreviewSampleUri,
        simulatedDuration: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint('[VoiceConversationService] Speech turn error: $e');
      _setStatus(VoiceConversationStatus.reconnecting);
      await Future.delayed(const Duration(milliseconds: 800));
      _setStatus(VoiceConversationStatus.listening);
      await recorder.resumeRecording();
    }
  }

  @override
  Future<void> interrupt() async {
    if (_status == VoiceConversationStatus.speaking ||
        player.status == AudioPlaybackStatus.playing) {
      await player.stop();
      _setStatus(VoiceConversationStatus.interrupted);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!_isMuted) {
        await recorder.resumeRecording();
      }
      _setStatus(VoiceConversationStatus.listening);
    }
  }

  @override
  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    if (_isMuted) {
      await recorder.pauseRecording();
      _amplitudeController.add(0.0);
    } else {
      await recorder.resumeRecording();
    }
  }

  @override
  Future<void> endSession() async {
    await player.stop();
    await recorder.stopRecording();
    _amplitudeController.add(0.0);
    _setStatus(VoiceConversationStatus.ended);
  }

  void _onLifecycleAbort(String reason) {
    debugPrint('[VoiceConversationService] Lifecycle abort triggered: $reason');
    if (_status == VoiceConversationStatus.listening ||
        _status == VoiceConversationStatus.speaking ||
        _status == VoiceConversationStatus.processing) {
      player.stop();
      recorder.stopRecording();
      _amplitudeController.add(0.0);
      _setStatus(VoiceConversationStatus.interrupted);
    }
  }

  @override
  void handleLifecycleTransition(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _onLifecycleAbort('AppLifecycleState: $state');
    }
  }

  @override
  void dispose() {
    AppLifecycleManager.instance.unregisterAudioSession(_onLifecycleAbort);
    _recorderAmpSub?.cancel();
    _playerStatusSub?.cancel();
    player.stop();
    recorder.stopRecording();
    _statusController.close();
    _amplitudeController.close();
    _transcriptController.close();
  }
}
