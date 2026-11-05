import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/audio/audio_recorder_service.dart';
import '../../../../core/audio/tts_service.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/dao/chat_dao.dart';
import '../../../../core/network/ai/ai_service.dart';
import '../../data/repositories/ai_tutor_repository.dart';
import '../../domain/models/tutor_chat_turn.dart';
import '../../domain/models/tutor_persona.dart';
import '../../domain/models/tutor_scenario.dart';
import '../../domain/voice/voice_conversation_models.dart';
import '../../domain/voice/voice_conversation_service.dart';

/// Available chat interaction modes.
enum AiTutorMode {
  text,
  voice,
}

/// Provider managing whether Text Chat or Voice Conversation is active.
class AiTutorModeNotifier extends Notifier<AiTutorMode> {
  @override
  AiTutorMode build() => AiTutorMode.text;

  void setMode(AiTutorMode mode) => state = mode;
}

final aiTutorModeProvider =
    NotifierProvider<AiTutorModeNotifier, AiTutorMode>(AiTutorModeNotifier.new);

/// Provider for the [AiTutorRepository] singleton.
final aiTutorRepositoryProvider = Provider<AiTutorRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final aiService = ref.watch(aiServiceProvider);

  return AiTutorRepositoryImpl(
    database: database,
    aiService: aiService,
  );
});

final aiTutorTtsServiceProvider = Provider<TtsService>((ref) {
  final tts = DefaultTtsService();
  ref.onDispose(() => tts.dispose());
  return tts;
});

/// Dedicated AudioRecorderService instance for AI Tutor.
final aiTutorAudioRecorderProvider = Provider<AudioRecorderService>((ref) {
  final recorder = DefaultAudioRecorderService();
  ref.onDispose(() => recorder.dispose());
  return recorder;
});

/// Dedicated AudioPlayerService instance for AI Tutor.
final aiTutorAudioPlayerProvider = Provider<AudioPlayerService>((ref) {
  final player = DefaultAudioPlayerService();
  ref.onDispose(() => player.dispose());
  return player;
});

/// Provider for [VoiceConversationService] singleton for the AI Tutor.
final voiceConversationServiceProvider = Provider<VoiceConversationService>((ref) {
  final recorder = ref.watch(aiTutorAudioRecorderProvider);
  final player = ref.watch(aiTutorAudioPlayerProvider);
  final tts = ref.watch(aiTutorTtsServiceProvider);
  final repository = ref.watch(aiTutorRepositoryProvider);

  final service = DefaultVoiceConversationService(
    recorder: recorder,
    player: player,
    tts: tts,
    repository: repository,
  );

  ref.onDispose(() => service.dispose());
  return service;
});

final personaPreviewStatusProvider = StreamProvider<PersonaVoicePreviewStatus>((ref) {
  final service = ref.watch(voiceConversationServiceProvider);
  return service.previewStatusStream;
});

/// Reactive stream provider for the voice conversation status.
final voiceStatusProvider = StreamProvider<VoiceConversationStatus>((ref) {
  final service = ref.watch(voiceConversationServiceProvider);
  return service.statusStream;
});

/// Reactive stream provider for real-time voice amplitude (0.0 to 1.0).
final voiceAmplitudeProvider = StreamProvider<double>((ref) {
  final service = ref.watch(voiceConversationServiceProvider);
  return service.amplitudeStream;
});

/// Reactive stream provider for real-time voice transcript segments.
final voiceTranscriptsProvider = StreamProvider<List<VoiceTranscriptSegment>>((ref) {
  final service = ref.watch(voiceConversationServiceProvider);
  return service.transcriptStream;
});

/// Reactive provider indicating whether native ASR (Speech-to-Text) voice input is supported.
/// Currently false pending on-device STT or cloud WebSocket Live API integration (BUG-NEW-003).
final voiceInputSupportedProvider = Provider<bool>((ref) {
  final service = ref.watch(voiceConversationServiceProvider);
  return service.voiceInputSupported;
});

/// Notifier managing the currently selected AI Tutor persona.
class ActivePersonaNotifier extends Notifier<TutorPersona> {
  @override
  TutorPersona build() => TutorPersonas.qiaoqiao;

  void selectPersona(TutorPersona persona) => state = persona;
}

final activePersonaProvider =
    NotifierProvider<ActivePersonaNotifier, TutorPersona>(ActivePersonaNotifier.new);

/// Notifier managing the active conversation scenario.
class ActiveScenarioNotifier extends Notifier<TutorScenario> {
  @override
  TutorScenario build() => TutorScenarios.freeChat;

  void selectScenario(TutorScenario scenario) => state = scenario;
}

final activeScenarioProvider =
    NotifierProvider<ActiveScenarioNotifier, TutorScenario>(ActiveScenarioNotifier.new);

/// Notifier managing the active chat session ID.
class CurrentChatSessionIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void selectSession(String? id) => state = id;
}

final currentChatSessionIdProvider =
    NotifierProvider<CurrentChatSessionIdNotifier, String?>(
        CurrentChatSessionIdNotifier.new);

/// List of messages in the currently selected session.
final sessionMessagesProvider =
    FutureProvider.family<List<TutorChatTurn>, String>((ref, sessionId) async {
  final repository = ref.watch(aiTutorRepositoryProvider);
  return repository.getSessionTurns(sessionId);
});

/// Active recent chat sessions from SQLite.
final recentChatSessionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final database = ref.watch(appDatabaseProvider);
  final db = database.isOpen ? database.database : await database.open();
  final chatDao = ChatDao(db);
  return chatDao.getActiveSessions();
});
