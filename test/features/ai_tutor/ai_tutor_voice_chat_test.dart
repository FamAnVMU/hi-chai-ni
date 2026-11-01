import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/audio/audio_models.dart';
import 'package:hi_chinese/core/audio/audio_player_service.dart';
import 'package:hi_chinese/core/audio/audio_recorder_service.dart';
import 'package:hi_chinese/core/database/app_database.dart';
import 'package:hi_chinese/core/network/ai/ai_service.dart';
import 'package:hi_chinese/core/network/ai/models/ai_model_config.dart';
import 'package:hi_chinese/core/network/ai/providers/mock_ai_provider.dart';
import 'package:hi_chinese/core/network/ai/security/ai_credential_storage.dart';
import 'package:hi_chinese/features/ai_tutor/ai_tutor.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _FakeAudioRecorderService implements AudioRecorderService {
  AudioRecordingStatus _status = AudioRecordingStatus.idle;
  final StreamController<AudioRecordingStatus> _statusCtrl = StreamController.broadcast();
  final StreamController<double> _ampCtrl = StreamController.broadcast();
  final StreamController<Duration> _durCtrl = StreamController.broadcast();

  bool permissionGranted = true;
  bool isRecordingActive = false;

  @override
  bool get hasMicrophone => true;

  @override
  AudioRecordingStatus get status => _status;

  @override
  Duration get recordingDuration => Duration.zero;

  @override
  String? get currentAudioPath => 'test/path/audio.wav';

  @override
  Stream<AudioRecordingStatus> get statusStream => _statusCtrl.stream;

  @override
  Stream<double> get amplitudeStream => _ampCtrl.stream;

  @override
  Stream<Duration> get durationStream => _durCtrl.stream;

  @override
  Future<bool> checkPermission() async => permissionGranted;

  @override
  Future<void> startRecording({String? destinationPath}) async {
    isRecordingActive = true;
    _status = AudioRecordingStatus.recording;
    _statusCtrl.add(_status);
    _ampCtrl.add(0.65);
  }

  @override
  Future<void> pauseRecording() async {
    isRecordingActive = false;
    _status = AudioRecordingStatus.paused;
    _statusCtrl.add(_status);
    _ampCtrl.add(0.0);
  }

  @override
  Future<void> resumeRecording() async {
    isRecordingActive = true;
    _status = AudioRecordingStatus.recording;
    _statusCtrl.add(_status);
    _ampCtrl.add(0.55);
  }

  @override
  Future<String?> stopRecording() async {
    isRecordingActive = false;
    _status = AudioRecordingStatus.stopped;
    _statusCtrl.add(_status);
    _ampCtrl.add(0.0);
    return 'test/path/audio.wav';
  }

  @override
  Future<void> cancelRecording() async {
    await stopRecording();
  }

  @override
  void dispose() {
    _statusCtrl.close();
    _ampCtrl.close();
    _durCtrl.close();
  }
}

class _FakeAudioPlayerService implements AudioPlayerService {
  AudioPlaybackStatus _status = AudioPlaybackStatus.idle;
  final StreamController<AudioPlaybackStatus> _statusCtrl = StreamController.broadcast();
  final StreamController<Duration> _posCtrl = StreamController.broadcast();

  bool isPlayingActive = false;

  @override
  AudioPlaybackStatus get status => _status;

  @override
  Duration get currentPosition => Duration.zero;

  @override
  Duration get totalDuration => const Duration(seconds: 3);

  @override
  double get playbackSpeed => 1.0;

  @override
  bool get isLooping => false;

  @override
  Stream<AudioPlaybackStatus> get statusStream => _statusCtrl.stream;

  @override
  Stream<Duration> get positionStream => _posCtrl.stream;

  @override
  Future<void> play(String uri, {double speed = 1.0, bool loop = false, Duration? simulatedDuration}) async {
    isPlayingActive = true;
    _status = AudioPlaybackStatus.playing;
    _statusCtrl.add(_status);

    // Auto complete playback after short tick if simulatedDuration is given
    if (simulatedDuration != null) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (isPlayingActive) {
          _status = AudioPlaybackStatus.completed;
          _statusCtrl.add(_status);
          isPlayingActive = false;
        }
      });
    }
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
  Future<void> seek(Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(double speed) async {}

  @override
  Future<void> setLooping(bool loop) async {}

  @override
  void dispose() {
    _statusCtrl.close();
    _posCtrl.close();
  }
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('VoiceConversationService State Machine & Pipeline Tests', () {
    late Directory tempDir;
    late String dbPath;
    late AppDatabase appDatabase;
    late MockAiProvider mockAiProvider;
    late AiService aiService;
    late AiTutorRepository repository;
    late _FakeAudioRecorderService recorder;
    late _FakeAudioPlayerService player;
    late VoiceConversationService voiceService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hi_chinese_voice_test_');
      dbPath = '${tempDir.path}/test_voice.db';

      appDatabase = AppDatabase.instance;
      await appDatabase.open(customPath: dbPath);

      mockAiProvider = MockAiProvider();
      aiService = AiService(
        provider: mockAiProvider,
        credentialStorage: AiCredentialStorage.inMemory(initialApiKey: 'test_key'),
        modelRegistry: AiModelRegistry(),
      );

      repository = AiTutorRepositoryImpl(
        database: appDatabase,
        aiService: aiService,
      );

      recorder = _FakeAudioRecorderService();
      player = _FakeAudioPlayerService();

      voiceService = DefaultVoiceConversationService(
        recorder: recorder,
        player: player,
        repository: repository,
      );
    });

    tearDown(() async {
      voiceService.dispose();
      recorder.dispose();
      player.dispose();
      await appDatabase.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('1. Initial state is idle and mic permission check succeeds', () async {
      expect(voiceService.status, VoiceConversationStatus.idle);
      final hasPerm = await voiceService.checkPermission();
      expect(hasPerm, isTrue);
      expect(voiceService.status, VoiceConversationStatus.idle);
    });

    test('2. Start session transitions through connecting, speaking, and enters listening', () async {
      final sessionId = await repository.createSession(
        title: 'Voice Session 1',
        scenarioCode: 'free_chat',
      );

      final statusHistory = <VoiceConversationStatus>[];
      final sub = voiceService.statusStream.listen((s) => statusHistory.add(s));

      await voiceService.startSession(
        sessionId: sessionId,
        persona: TutorPersonas.qiaoqiao,
        scenario: TutorScenarios.freeChat,
      );

      // Wait briefly for greeting playback to complete
      await Future.delayed(const Duration(milliseconds: 100));

      expect(statusHistory, contains(VoiceConversationStatus.connecting));
      expect(statusHistory, contains(VoiceConversationStatus.listening));
      expect(voiceService.status, VoiceConversationStatus.listening);

      // Verify initial greeting transcript segment was added
      expect(voiceService.transcripts.isNotEmpty, isTrue);
      expect(voiceService.transcripts.first.role, 'assistant');
      expect(voiceService.transcripts.first.isInterim, isFalse);

      await sub.cancel();
    });

    test('3. Speech submission triggers processing, speaking, and returns to listening', () async {
      final sessionId = await repository.createSession(
        title: 'Voice Session 2',
        scenarioCode: 'free_chat',
      );

      mockAiProvider.customTextResponse =
          '{"reply_zh": "太好了！", "reply_pinyin": "Tài hǎo le!", "reply_vi": "Tuyệt quá!"}';

      await voiceService.startSession(
        sessionId: sessionId,
        persona: TutorPersonas.qiaoqiao,
        scenario: TutorScenarios.freeChat,
      );
      await Future.delayed(const Duration(milliseconds: 100));

      final statusHistory = <VoiceConversationStatus>[];
      final sub = voiceService.statusStream.listen((s) => statusHistory.add(s));

      await voiceService.submitSpeechInput('我想练习口语');
      await Future.delayed(const Duration(milliseconds: 100));

      expect(statusHistory, contains(VoiceConversationStatus.processing));
      expect(statusHistory, contains(VoiceConversationStatus.speaking));
      expect(voiceService.status, VoiceConversationStatus.listening);

      // Verify transcripts has both user and assistant segments
      expect(voiceService.transcripts.any((t) => t.isUser && t.text == '我想练习口语'), isTrue);
      expect(voiceService.transcripts.any((t) => t.isAssistant && t.text == '太好了！'), isTrue);

      await sub.cancel();
    });

    test('4. Interrupt AI speech stops player immediately and transitions back to listening', () async {
      final sessionId = await repository.createSession(
        title: 'Voice Session 3',
        scenarioCode: 'free_chat',
      );

      await voiceService.startSession(
        sessionId: sessionId,
        persona: TutorPersonas.qiaoqiao,
        scenario: TutorScenarios.freeChat,
      );

      // Artificially start player speech without quick timeout
      await player.play('test/audio.mp3');
      expect(player.isPlayingActive, isTrue);

      // Trigger interrupt
      await voiceService.interrupt();

      expect(player.isPlayingActive, isFalse);
      expect(voiceService.status, VoiceConversationStatus.listening);
    });

    test('5. Toggle mute pauses recording and zeroes amplitude', () async {
      expect(voiceService.isMuted, isFalse);

      await voiceService.toggleMute();
      expect(voiceService.isMuted, isTrue);

      await voiceService.toggleMute();
      expect(voiceService.isMuted, isFalse);
    });

    test('6. App background lifecycle transition immediately halts recording (Privacy Compliance)', () async {
      final sessionId = await repository.createSession(
        title: 'Voice Lifecycle Test',
        scenarioCode: 'free_chat',
      );

      await voiceService.startSession(
        sessionId: sessionId,
        persona: TutorPersonas.qiaoqiao,
        scenario: TutorScenarios.freeChat,
      );
      await Future.delayed(const Duration(milliseconds: 100));

      expect(voiceService.status, VoiceConversationStatus.listening);

      // Simulate OS pausing the app (incoming call / screen lock / switch apps)
      voiceService.handleLifecycleTransition(AppLifecycleState.paused);

      // Must be interrupted, and recorder stopped
      expect(voiceService.status, VoiceConversationStatus.interrupted);
      expect(recorder.isRecordingActive, isFalse);
    });

    test('7. End session stops audio and sets status to ended', () async {
      await voiceService.endSession();
      expect(voiceService.status, VoiceConversationStatus.ended);
    });

    test('8. Live API Preview diagnostic info is well-formed', () {
      const info = LiveApiPreviewInfo();
      expect(info.isPreview, isTrue);
      expect(info.previewModelName, contains('gemini-2.0-flash-exp'));
      expect(info.limitationNotice, contains('Voice Live API'));
      expect(info.isDeviceSupported, isTrue);
    });
  });

  group('AiTutorVoiceChatScreen Widget Tests', () {
    late Directory tempDir;
    late String dbPath;
    late AppDatabase appDatabase;
    late MockAiProvider mockAiProvider;
    late AiService aiService;
    late AiTutorRepository repository;
    late _FakeAudioRecorderService recorder;
    late _FakeAudioPlayerService player;
    late VoiceConversationService voiceService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hi_chinese_voice_ui_test_');
      dbPath = '${tempDir.path}/test_voice_ui.db';

      appDatabase = AppDatabase.instance;
      await appDatabase.open(customPath: dbPath);

      mockAiProvider = MockAiProvider();
      aiService = AiService(
        provider: mockAiProvider,
        credentialStorage: AiCredentialStorage.inMemory(initialApiKey: 'test_key'),
        modelRegistry: AiModelRegistry(),
      );

      repository = AiTutorRepositoryImpl(
        database: appDatabase,
        aiService: aiService,
      );

      recorder = _FakeAudioRecorderService();
      player = _FakeAudioPlayerService();

      voiceService = DefaultVoiceConversationService(
        recorder: recorder,
        player: player,
        repository: repository,
      );
    });

    tearDown(() async {
      voiceService.dispose();
      recorder.dispose();
      player.dispose();
      await appDatabase.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets('Renders Voice Chat UI with status chip and Live API diagnostic pill', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(appDatabase),
            aiTutorRepositoryProvider.overrideWithValue(repository),
            voiceConversationServiceProvider.overrideWithValue(voiceService),
          ],
          child: const MaterialApp(
            home: AiTutorVoiceChatScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check status chip
      expect(find.text('Sẵn sàng'), findsOneWidget);

      // Check Live API Preview pill
      expect(find.text('Live API Preview'), findsOneWidget);

      // Tap Live API Preview pill -> opens diagnostic info modal
      await tester.tap(find.text('Live API Preview'));
      await tester.pumpAndSettle();

      expect(find.text('Voice Live API (Firebase AI Logic)'), findsOneWidget);
      expect(find.text('Đã hiểu'), findsOneWidget);

      await tester.tap(find.text('Đã hiểu'));
      await tester.pumpAndSettle();
    });
  });
}
