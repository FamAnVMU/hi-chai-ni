import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/dao/chat_dao.dart';
import '../../../../core/network/ai/ai_service.dart';
import '../../data/repositories/ai_tutor_repository.dart';
import '../../domain/models/tutor_chat_turn.dart';
import '../../domain/models/tutor_persona.dart';
import '../../domain/models/tutor_scenario.dart';

/// Provider for the [AiTutorRepository] singleton.
final aiTutorRepositoryProvider = Provider<AiTutorRepository>((ref) {
  final database = ref.watch(appDatabaseProvider);
  final aiService = ref.watch(aiServiceProvider);

  return AiTutorRepositoryImpl(
    database: database,
    aiService: aiService,
  );
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
