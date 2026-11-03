import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/audio/audio_models.dart';
import 'package:hi_chinese/core/audio/audio_player_service.dart';
import 'package:hi_chinese/core/audio/audio_recorder_service.dart';
import 'package:hi_chinese/core/audio/tts_service.dart';
import 'package:hi_chinese/features/ai_tutor/data/repositories/ai_tutor_repository.dart';
import 'package:hi_chinese/features/ai_tutor/domain/models/tutor_persona.dart';
import 'package:hi_chinese/features/ai_tutor/domain/voice/voice_conversation_service.dart';

class _FakeAudioRecorderService implements AudioRecorderService {
  final _ampCtrl = StreamController<double>.broadcast();

  @override
  Stream<double> get amplitudeStream => _ampCtrl.stream;

  @override
  Future<bool> checkPermission() async => true;

  @override
  Future<void> startRecording({String? destinationPath}) async {}

  @override
  Future<String?> stopRecording() async => null;

  @override
  Future<void> pauseRecording() async {}

  @override
  Future<void> resumeRecording() async {}

  @override
  void dispose() {
    _ampCtrl.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAudioPlayerService implements AudioPlayerService {
  final _statusCtrl = StreamController<AudioPlaybackStatus>.broadcast();
  final _posCtrl = StreamController<Duration>.broadcast();
  bool isPlayingActive = false;
  AudioPlaybackStatus _status = AudioPlaybackStatus.stopped;

  @override
  AudioPlaybackStatus get status => _status;

  @override
  Stream<AudioPlaybackStatus> get statusStream => _statusCtrl.stream;

  @override
  Stream<Duration> get positionStream => _posCtrl.stream;

  @override
  Future<void> play(String uri, {double speed = 1.0, bool loop = false, Duration? simulatedDuration}) async {
    isPlayingActive = true;
    _status = AudioPlaybackStatus.playing;
    _statusCtrl.add(_status);
  }

  @override
  Future<void> pause() async {
    _status = AudioPlaybackStatus.paused;
    _statusCtrl.add(_status);
  }

  @override
  Future<void> resume() async {
    _status = AudioPlaybackStatus.playing;
    _statusCtrl.add(_status);
  }

  @override
  Future<void> stop() async {
    isPlayingActive = false;
    _status = AudioPlaybackStatus.stopped;
    _statusCtrl.add(_status);
  }

  @override
  void dispose() {
    _statusCtrl.close();
    _posCtrl.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockTtsService implements TtsService {
  bool isLanguageAvailableResult = true;
  String? lastSpokenText;
  String? lastLanguage;
  double? lastPitch;
  double? lastRate;
  int speakCallCount = 0;
  int stopCallCount = 0;
  bool isDisposed = false;

  @override
  Future<bool> isLanguageAvailable(String language) async => isLanguageAvailableResult;

  @override
  Future<List<String>> getAvailableVoices() async => ['zh-CN-female-1'];

  @override
  Future<void> speak(
    String text, {
    String language = 'zh-CN',
    double rate = 0.5,
    double pitch = 1.0,
    double volume = 1.0,
    String? voiceName,
  }) async {
    speakCallCount++;
    lastSpokenText = text;
    lastLanguage = language;
    lastPitch = pitch;
    lastRate = rate;
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
  }

  @override
  void dispose() {
    isDisposed = true;
  }
}

class _DummyAiTutorRepository implements AiTutorRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TutorPersona Voice Configuration Catalog Tests', () {
    test('All registered personas have valid non-empty TTS sample configurations', () {
      final personas = TutorPersonas.all;
      expect(personas.length, 3);

      for (final persona in personas) {
        final config = persona.voiceConfig;
        expect(config.sourceType, PersonaVoiceSourceType.ttsSynthesis);
        expect(config.previewSampleTextZh.isNotEmpty, isTrue);
        expect(config.previewSampleTextPinyin.isNotEmpty, isTrue);
        expect(config.previewSampleTextVi.isNotEmpty, isTrue);
        expect(config.ttsPitch, isNotNull);
        expect(config.ttsRate, isNotNull);
        expect(persona.canPreview, isTrue);
        expect(persona.voicePreviewSampleUri, isNull);
      }
    });

    test('Each persona has differentiated pitch and rate configuration', () {
      final qiaoqiao = TutorPersonas.qiaoqiao.voiceConfig;
      final laowang = TutorPersonas.laowang.voiceConfig;
      final xiaoming = TutorPersonas.xiaoming.voiceConfig;

      expect(qiaoqiao.ttsPitch, isNot(equals(laowang.ttsPitch)));
      expect(xiaoming.ttsPitch, isNot(equals(laowang.ttsPitch)));
      expect(laowang.ttsPitch < 1.0, isTrue);
      expect(qiaoqiao.ttsPitch > 1.0, isTrue);
      expect(xiaoming.ttsRate > qiaoqiao.ttsRate, isTrue);
    });
  });

  group('DefaultVoiceConversationService Persona Voice Preview Tests', () {
    late _FakeAudioRecorderService recorder;
    late _FakeAudioPlayerService player;
    late _MockTtsService tts;
    late _DummyAiTutorRepository repository;
    late DefaultVoiceConversationService service;

    setUp(() {
      recorder = _FakeAudioRecorderService();
      player = _FakeAudioPlayerService();
      tts = _MockTtsService();
      repository = _DummyAiTutorRepository();
      service = DefaultVoiceConversationService(
        recorder: recorder,
        player: player,
        tts: tts,
        repository: repository,
      );
    });

    tearDown(() {
      service.dispose();
      recorder.dispose();
      player.dispose();
    });

    test('1. Preview voice with TTS invokes speak with correct persona parameters', () async {
      await service.previewPersonaVoice(TutorPersonas.qiaoqiao);

      expect(tts.speakCallCount, 1);
      expect(tts.lastSpokenText, TutorPersonas.qiaoqiao.voiceConfig.previewSampleTextZh);
      expect(tts.lastLanguage, 'zh-CN');
      expect(tts.lastPitch, TutorPersonas.qiaoqiao.voiceConfig.ttsPitch);
      expect(tts.lastRate, TutorPersonas.qiaoqiao.voiceConfig.ttsRate);

      expect(service.previewStatus.isPlaying, isTrue);
      expect(service.previewStatus.isTts, isTrue);
      expect(service.previewStatus.personaId, 'qiaoqiao');
    });

    test('2. Preview Lao Wang and Xiao Ming applies corresponding voice parameters', () async {
      await service.previewPersonaVoice(TutorPersonas.laowang);
      expect(tts.lastSpokenText, TutorPersonas.laowang.voiceConfig.previewSampleTextZh);
      expect(tts.lastPitch, TutorPersonas.laowang.voiceConfig.ttsPitch);
      expect(service.previewStatus.personaId, 'laowang');

      await service.previewPersonaVoice(TutorPersonas.xiaoming);
      expect(tts.lastSpokenText, TutorPersonas.xiaoming.voiceConfig.previewSampleTextZh);
      expect(tts.lastPitch, TutorPersonas.xiaoming.voiceConfig.ttsPitch);
      expect(service.previewStatus.personaId, 'xiaoming');
    });

    test('3. Stop preview halts TTS and player and updates previewStatus to stopped', () async {
      await service.previewPersonaVoice(TutorPersonas.qiaoqiao);
      expect(service.previewStatus.isPlaying, isTrue);

      await service.stopPersonaVoicePreview();
      expect(tts.stopCallCount, greaterThanOrEqualTo(1));
      expect(service.previewStatus.isStopped, isTrue);
    });

    test('4. Gracefully handles unsupported TTS language on device without exceptions', () async {
      tts.isLanguageAvailableResult = false;

      await service.previewPersonaVoice(TutorPersonas.qiaoqiao);

      expect(service.previewStatus.isUnsupported, isTrue);
      expect(tts.speakCallCount, 0);
      expect(service.previewStatus.message, contains('chưa cài đặt gói giọng nói'));
    });

    test('5. Gracefully handles null TTS engine without exceptions', () async {
      final noTtsService = DefaultVoiceConversationService(
        recorder: recorder,
        player: player,
        tts: null,
        repository: repository,
      );

      await noTtsService.previewPersonaVoice(TutorPersonas.qiaoqiao);

      expect(noTtsService.previewStatus.isUnsupported, isTrue);
      expect(noTtsService.previewStatus.message, contains('chưa sẵn sàng'));
      noTtsService.dispose();
    });

    test('6. Gracefully handles asset audio missing from bundle without throwing exception', () async {
      const mockAssetPersona = TutorPersona(
        id: TutorPersonaId.qiaoqiao,
        nameZh: '巧巧',
        nameVi: 'Kiều Kiều',
        titleVi: 'Gia sư',
        avatarEmoji: '🌸',
        hskTargetMin: 1,
        hskTargetMax: 3,
        toneDescription: 'Ấm áp',
        systemPromptInstruction: 'Directives',
        voiceConfig: PersonaVoiceConfig(
          sourceType: PersonaVoiceSourceType.assetAudio,
          assetPath: 'assets/audio/personas/non_existent_voice.mp3',
          previewSampleTextZh: '你好',
          previewSampleTextPinyin: 'Nǐ hǎo',
          previewSampleTextVi: 'Chào bạn',
        ),
      );

      await service.previewPersonaVoice(mockAssetPersona);

      expect(service.previewStatus.isUnsupported, isTrue);
      expect(service.previewStatus.message, contains('chưa được cài đặt'));
    });

    test('7. Switching personas stops ongoing preview before starting the new one', () async {
      await service.previewPersonaVoice(TutorPersonas.qiaoqiao);
      final stopsBeforeSwitch = tts.stopCallCount;

      await service.previewPersonaVoice(TutorPersonas.laowang);
      expect(tts.stopCallCount, greaterThan(stopsBeforeSwitch));
      expect(service.previewStatus.personaId, 'laowang');
    });

    test('8. Dispose halts playback and cleans up stream controllers without errors', () {
      expect(() => service.dispose(), returnsNormally);
      expect(tts.isDisposed, isTrue);
    });
  });
}
