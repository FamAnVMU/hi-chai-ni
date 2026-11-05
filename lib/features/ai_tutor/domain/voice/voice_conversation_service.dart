import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/audio/audio_models.dart';
import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/audio/audio_recorder_service.dart';
import '../../../../core/audio/tts_service.dart';
import '../../../../core/network/ai/models/cancel_token.dart';
import '../../../../core/utils/app_lifecycle_manager.dart';
import '../../data/repositories/ai_tutor_repository.dart';
import '../models/tutor_persona.dart';
import '../models/tutor_scenario.dart';
import 'voice_conversation_models.dart';

abstract class VoiceConversationService {
  VoiceConversationStatus get status;
  Stream<VoiceConversationStatus> get statusStream;
  Stream<double> get amplitudeStream;
  Stream<List<VoiceTranscriptSegment>> get transcriptStream;
  List<VoiceTranscriptSegment> get transcripts;
  bool get isMuted;
  bool get voiceInputSupported;
  VoiceEngineMode get engineMode;

  PersonaVoicePreviewStatus get previewStatus;
  Stream<PersonaVoicePreviewStatus> get previewStatusStream;

  Future<bool> checkPermission();
  Future<void> startMicTest();
  Future<void> stopMicTest();

  Future<void> previewPersonaVoice(TutorPersona persona);
  Future<void> stopPersonaVoicePreview();

  Future<void> startSession({
    required String sessionId,
    required TutorPersona persona,
    required TutorScenario scenario,
    int learnerHskLevel = 1,
  });

  Future<void> endSession();
  Future<void> interrupt();
  Future<void> cancelCurrentTurn();
  Future<void> stopListening();
  Future<void> toggleMute();

  Future<void> submitSpeechInput(String userText);

  void handleLifecycleTransition(AppLifecycleState state);

  void dispose();
}

class DefaultVoiceConversationService implements VoiceConversationService {
  final AudioRecorderService recorder;
  final AudioPlayerService player;
  final TtsService? tts;
  final AiTutorRepository repository;
  final VoiceEngineMode mode;
  @override
  final bool voiceInputSupported;

  VoiceConversationStatus _status = VoiceConversationStatus.idle;
  bool _isMuted = false;
  String? _activeSessionId;
  TutorPersona _activePersona = TutorPersonas.qiaoqiao;
  TutorScenario _activeScenario = TutorScenarios.freeChat;
  int _learnerHskLevel = 1;
  CancelToken? _currentTurnCancelToken;

  PersonaVoicePreviewStatus _previewStatus = PersonaVoicePreviewStatus.initial;
  final StreamController<PersonaVoicePreviewStatus> _previewStatusController =
      StreamController<PersonaVoicePreviewStatus>.broadcast();

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
    this.tts,
    required this.repository,
    this.mode = VoiceEngineMode.turnBasedAudio,
    this.voiceInputSupported = false,
  }) {
    _recorderAmpSub = recorder.amplitudeStream.listen((amp) {
      if (_amplitudeController.isClosed) return;
      if (!_isMuted &&
          (_status == VoiceConversationStatus.listening ||
              _status == VoiceConversationStatus.idle)) {
        _amplitudeController.add(amp);
      } else {
        _amplitudeController.add(0.0);
      }
    });

    _playerStatusSub = player.statusStream.listen((playStatus) {
      if (_previewStatus.isPlaying &&
          (playStatus == AudioPlaybackStatus.completed ||
              playStatus == AudioPlaybackStatus.stopped ||
              playStatus == AudioPlaybackStatus.error)) {
        _setPreviewStatus(PersonaVoicePreviewStatus(
          personaId: _previewStatus.personaId,
          state: playStatus == AudioPlaybackStatus.error
              ? PersonaPreviewPlaybackState.error
              : PersonaPreviewPlaybackState.stopped,
          message: playStatus == AudioPlaybackStatus.error ? 'Lỗi phát file âm thanh mẫu' : null,
        ));
      }

      if (_status == VoiceConversationStatus.speaking &&
          (playStatus == AudioPlaybackStatus.completed ||
              playStatus == AudioPlaybackStatus.stopped)) {
        _setStatus(VoiceConversationStatus.listening);
      }
    });

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

  @override
  PersonaVoicePreviewStatus get previewStatus => _previewStatus;

  @override
  Stream<PersonaVoicePreviewStatus> get previewStatusStream =>
      _previewStatusController.stream;

  void _setStatus(VoiceConversationStatus newStatus) {
    if (_status == newStatus) return;
    _status = newStatus;
    if (!_statusController.isClosed) {
      _statusController.add(_status);
    }
  }

  void _setPreviewStatus(PersonaVoicePreviewStatus newStatus) {
    _previewStatus = newStatus;
    if (!_previewStatusController.isClosed) {
      _previewStatusController.add(_previewStatus);
    }
  }

  void _addTranscript(VoiceTranscriptSegment segment) {
    _transcripts.add(segment);
    if (!_transcriptController.isClosed) {
      _transcriptController.add(List.unmodifiable(_transcripts));
    }
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
    if (!_transcriptController.isClosed) {
      _transcriptController.add(List.unmodifiable(_transcripts));
    }
  }

  @override
  Future<bool> checkPermission() async {
    _setStatus(VoiceConversationStatus.requestingPermission);
    bool granted = false;
    try {
      granted = await recorder.checkPermission();
    } catch (e) {
      debugPrint('[VoiceConversationService] checkPermission error: $e');
      granted = false;
    }
    if (!granted) {
      _setStatus(voiceInputSupported ? VoiceConversationStatus.error : VoiceConversationStatus.idle);
      return false;
    }
    _setStatus(VoiceConversationStatus.idle);
    return true;
  }

  @override
  Future<void> startMicTest() async {
    final granted = await checkPermission();
    if (!granted) {
      throw const AudioRecordingPermissionException(
        'Không được cấp quyền truy cập Microphone.',
      );
    }
    await recorder.startRecording();
  }

  @override
  Future<void> stopMicTest() async {
    await recorder.stopRecording();
    if (!_amplitudeController.isClosed) {
      _amplitudeController.add(0.0);
    }
  }

  @override
  Future<void> stopPersonaVoicePreview() async {
    try {
      await player.stop();
      if (tts != null) {
        await tts!.stop();
      }
    } catch (_) {}
    _setPreviewStatus(PersonaVoicePreviewStatus(
      personaId: _previewStatus.personaId,
      state: PersonaPreviewPlaybackState.stopped,
    ));
  }

  @override
  Future<void> previewPersonaVoice(TutorPersona persona) async {
    await stopPersonaVoicePreview();

    final config = persona.voiceConfig;
    final personaIdStr = persona.id.name;

    if (!persona.canPreview) {
      _setPreviewStatus(PersonaVoicePreviewStatus(
        personaId: personaIdStr,
        state: PersonaPreviewPlaybackState.unsupported,
        message: 'Giọng mẫu của ${persona.nameZh} hiện chưa khả dụng trên thiết bị.',
      ));
      return;
    }

    _setPreviewStatus(PersonaVoicePreviewStatus(
      personaId: personaIdStr,
      state: PersonaPreviewPlaybackState.loading,
      isTts: config.sourceType == PersonaVoiceSourceType.ttsSynthesis,
    ));

    try {
      if (config.sourceType == PersonaVoiceSourceType.assetAudio) {
        final path = config.assetPath;
        if (path == null || path.trim().isEmpty) {
          _setPreviewStatus(PersonaVoicePreviewStatus(
            personaId: personaIdStr,
            state: PersonaPreviewPlaybackState.unsupported,
            message: 'Chưa có file mẫu âm thanh cho ${persona.nameZh}.',
          ));
          return;
        }

        try {
          await rootBundle.load(path);
        } catch (_) {
          _setPreviewStatus(PersonaVoicePreviewStatus(
            personaId: personaIdStr,
            state: PersonaPreviewPlaybackState.unsupported,
            message: 'Tài nguyên âm thanh mẫu cho ${persona.nameZh} chưa được cài đặt.',
          ));
          return;
        }

        _setPreviewStatus(PersonaVoicePreviewStatus(
          personaId: personaIdStr,
          state: PersonaPreviewPlaybackState.playing,
          isTts: false,
        ));
        await player.play(path, speed: 1.0);
      } else if (config.sourceType == PersonaVoiceSourceType.ttsSynthesis) {
        if (tts == null) {
          _setPreviewStatus(PersonaVoicePreviewStatus(
            personaId: personaIdStr,
            state: PersonaPreviewPlaybackState.unsupported,
            message: 'Công cụ tổng hợp giọng nói (TTS) chưa sẵn sàng.',
          ));
          return;
        }

        final langSupported = await tts!.isLanguageAvailable(config.ttsLocale ?? 'zh-CN');
        if (!langSupported) {
          _setPreviewStatus(PersonaVoicePreviewStatus(
            personaId: personaIdStr,
            state: PersonaPreviewPlaybackState.unsupported,
            message: 'Thiết bị chưa cài đặt gói giọng nói tiếng Trung (${config.ttsLocale}).',
          ));
          return;
        }

        _setPreviewStatus(PersonaVoicePreviewStatus(
          personaId: personaIdStr,
          state: PersonaPreviewPlaybackState.playing,
          isTts: true,
          message: 'Đang phát giọng đọc mẫu TTS (xem trước).',
        ));

        await tts!.speak(
          config.previewSampleTextZh,
          language: config.ttsLocale ?? 'zh-CN',
          pitch: config.ttsPitch,
          rate: config.ttsRate,
          voiceName: config.ttsVoiceName,
        );
      }
    } catch (e) {
      debugPrint('[VoiceConversationService] Preview error: $e');
      _setPreviewStatus(PersonaVoicePreviewStatus(
        personaId: personaIdStr,
        state: PersonaPreviewPlaybackState.error,
        message: 'Không thể phát giọng nghe thử: $e',
      ));
    }
  }

  @override
  Future<void> startSession({
    required String sessionId,
    required TutorPersona persona,
    required TutorScenario scenario,
    int learnerHskLevel = 1,
  }) async {
    await stopPersonaVoicePreview();

    _activeSessionId = sessionId;
    _activePersona = persona;
    _activeScenario = scenario;
    _learnerHskLevel = learnerHskLevel;
    _isMuted = false;
    _transcripts.clear();

    _setStatus(VoiceConversationStatus.requestingPermission);
    bool hasPerm = false;
    try {
      hasPerm = await recorder.checkPermission();
    } catch (_) {
      hasPerm = false;
    }

    if (!hasPerm && voiceInputSupported) {
      _setStatus(VoiceConversationStatus.error);
      return;
    }

    _setStatus(VoiceConversationStatus.connecting);
    await Future.delayed(const Duration(milliseconds: 300));

    if (_status == VoiceConversationStatus.ended ||
        _status == VoiceConversationStatus.idle ||
        _activeSessionId != sessionId) {
      return;
    }

    _addTranscript(VoiceTranscriptSegment(
      id: 'greeting_${DateTime.now().millisecondsSinceEpoch}',
      role: 'assistant',
      text: scenario.initialAiGreetingZh,
      pinyin: scenario.initialAiGreetingPinyin,
      translationVi: scenario.initialAiGreetingVi,
      isInterim: false,
      timestamp: DateTime.now(),
    ));

    _setStatus(VoiceConversationStatus.speaking);
    final greetingAsset = persona.voicePreviewSampleUri;
    if (greetingAsset != null) {
      try {
        await player.play(
          greetingAsset,
          simulatedDuration: const Duration(seconds: 2),
        );
      } catch (_) {}
    } else if (tts != null && persona.voiceConfig.sourceType == PersonaVoiceSourceType.ttsSynthesis) {
      try {
        await tts!.speak(
          scenario.initialAiGreetingZh,
          language: persona.voiceConfig.ttsLocale ?? 'zh-CN',
          pitch: persona.voiceConfig.ttsPitch,
          rate: persona.voiceConfig.ttsRate,
        );
      } catch (_) {}
    }

    if (_status == VoiceConversationStatus.ended ||
        _status == VoiceConversationStatus.idle ||
        _activeSessionId != sessionId) {
      return;
    }

    if (voiceInputSupported && hasPerm) {
      try {
        await recorder.startRecording();
      } catch (e) {
        debugPrint('[VoiceConversationService] startRecording error: $e');
      }
    }
    _setStatus(VoiceConversationStatus.listening);
  }

  @override
  Future<void> submitSpeechInput(String userText) async {
    if (_status != VoiceConversationStatus.listening) return;
    if (userText.trim().isEmpty) return;

    _updateLastInterimTranscript(userText.trim(), isFinal: true);

    _setStatus(VoiceConversationStatus.processing);
    if (voiceInputSupported) {
      try {
        await recorder.pauseRecording();
      } catch (_) {}
    }

    try {
      final sessionId = _activeSessionId;
      if (sessionId == null) {
        throw StateError('Cannot submit speech without active session ID.');
      }

      _currentTurnCancelToken?.cancel();
      _currentTurnCancelToken = CancelToken();

      final tutorResponse = await repository.sendMessage(
        sessionId: sessionId,
        userText: userText.trim(),
        learnerHskLevel: _learnerHskLevel,
        persona: _activePersona,
        scenario: _activeScenario,
        cancelToken: _currentTurnCancelToken,
      );

      // Abort immediately if turn was cancelled, or session ended/idle while waiting for LLM
      if (_currentTurnCancelToken?.isCancelled == true ||
          _status == VoiceConversationStatus.ended ||
          _status == VoiceConversationStatus.idle ||
          _activeSessionId != sessionId) {
        return;
      }

      _addTranscript(VoiceTranscriptSegment(
        id: 'resp_${DateTime.now().millisecondsSinceEpoch}',
        role: 'assistant',
        text: tutorResponse.replyZh,
        pinyin: tutorResponse.replyPinyin,
        translationVi: tutorResponse.replyVi,
        isInterim: false,
        timestamp: DateTime.now(),
      ));

      _setStatus(VoiceConversationStatus.speaking);
      final assetUri = _activePersona.voicePreviewSampleUri;
      if (assetUri != null) {
        await player.play(
          assetUri,
          simulatedDuration: const Duration(seconds: 3),
        );
      } else if (tts != null) {
        await tts!.speak(
          tutorResponse.replyZh,
          language: _activePersona.voiceConfig.ttsLocale ?? 'zh-CN',
          pitch: _activePersona.voiceConfig.ttsPitch,
          rate: _activePersona.voiceConfig.ttsRate,
        );
      } else {
        await Future.delayed(const Duration(milliseconds: 500));
      }

      _setStatus(VoiceConversationStatus.listening);
      if (voiceInputSupported) {
        try {
          await recorder.resumeRecording();
        } catch (_) {}
      }
    } catch (e) {
      if (_currentTurnCancelToken?.isCancelled == true ||
          _status == VoiceConversationStatus.ended ||
          _status == VoiceConversationStatus.idle) {
        return;
      }
      debugPrint('[VoiceConversationService] Speech turn error: $e');
      _setStatus(VoiceConversationStatus.reconnecting);
      await Future.delayed(const Duration(milliseconds: 800));
      if (_status == VoiceConversationStatus.ended || _status == VoiceConversationStatus.idle) return;
      _setStatus(VoiceConversationStatus.listening);
      if (voiceInputSupported) {
        try {
          await recorder.resumeRecording();
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> interrupt() async {
    cancelCurrentTurn();
    if (_status == VoiceConversationStatus.speaking ||
        player.status == AudioPlaybackStatus.playing) {
      await player.stop();
      if (tts != null) {
        await tts!.stop();
      }
      _setStatus(VoiceConversationStatus.interrupted);
      await Future.delayed(const Duration(milliseconds: 200));
      _setStatus(VoiceConversationStatus.listening);
      if (voiceInputSupported) {
        try {
          await recorder.resumeRecording();
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> cancelCurrentTurn() async {
    _currentTurnCancelToken?.cancel();
    _currentTurnCancelToken = null;
    await player.stop();
    if (tts != null) {
      await tts!.stop();
    }
  }

  @override
  Future<void> stopListening() async {
    await recorder.stopRecording();
    if (!_amplitudeController.isClosed) {
      _amplitudeController.add(0.0);
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
    await stopPersonaVoicePreview();
    await player.stop();
    if (tts != null) {
      await tts!.stop();
    }
    await recorder.stopRecording();
    if (!_amplitudeController.isClosed) {
      _amplitudeController.add(0.0);
    }
    _setStatus(VoiceConversationStatus.ended);
  }

  void _onLifecycleAbort(String reason) {
    debugPrint('[VoiceConversationService] Lifecycle abort triggered: $reason');
    _currentTurnCancelToken?.cancel();
    _currentTurnCancelToken = null;
    stopPersonaVoicePreview();
    if (_status == VoiceConversationStatus.listening ||
        _status == VoiceConversationStatus.speaking ||
        _status == VoiceConversationStatus.processing ||
        _status == VoiceConversationStatus.connecting ||
        _status == VoiceConversationStatus.requestingPermission) {
      player.stop();
      if (tts != null) {
        tts!.stop();
      }
      recorder.stopRecording();
      if (!_amplitudeController.isClosed) {
        _amplitudeController.add(0.0);
      }
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
    _currentTurnCancelToken?.cancel();
    _currentTurnCancelToken = null;
    _recorderAmpSub?.cancel();
    _playerStatusSub?.cancel();
    player.stop();
    if (tts != null) {
      tts!.stop();
      tts!.dispose();
    }
    recorder.stopRecording();
    _previewStatus = PersonaVoicePreviewStatus.initial;
    if (!_statusController.isClosed) _statusController.close();
    if (!_amplitudeController.isClosed) _amplitudeController.close();
    if (!_transcriptController.isClosed) _transcriptController.close();
    if (!_previewStatusController.isClosed) _previewStatusController.close();
  }
}
