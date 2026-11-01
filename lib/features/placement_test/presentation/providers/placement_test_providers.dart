import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../data/placement_test_repository.dart';
import '../../domain/models/cat_assessment_result.dart';
import '../../domain/models/cat_session_state.dart';

/// Provider exposing the PlacementTestRepository instance.
final placementTestRepositoryProvider = Provider<PlacementTestRepository>((ref) {
  final db = AppDatabase.instance.database;
  return PlacementTestRepository(db);
});

/// State notifier managing an active adaptive placement test session.
class ActiveCatSessionNotifier extends AsyncNotifier<CatSessionState?> {
  @override
  Future<CatSessionState?> build() async {
    final repo = ref.watch(placementTestRepositoryProvider);
    return await repo.getActiveSession();
  }

  /// Starts a fresh adaptive placement test session.
  Future<void> startNewTest() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(placementTestRepositoryProvider);
      return await repo.startNewSession();
    });
  }

  /// Submits an answer for the current active question.
  Future<void> submitAnswer(dynamic answer, {int latencyMs = 1500}) async {
    final current = state.value;
    if (current == null || current.activeItem == null || current.isCompleted) {
      return;
    }

    final repo = ref.read(placementTestRepositoryProvider);
    final engine = repo.engine;

    // 1. Process turn via IRT CAT algorithm
    final nextState = engine.processTurn(
      currentState: current,
      userAnswer: answer,
      latencyMs: latencyMs,
    );

    // 2. Persist turn response in SQLite
    final lastResponse = nextState.responses.last;
    await repo.saveTurnResponse(
      sessionId: current.sessionId,
      response: lastResponse,
      updatedTheta: nextState.currentTheta,
      updatedSe: nextState.currentStandardError,
      stepIndex: nextState.stepIndex,
    );

    // 3. If test reached completion, finalize and store evidence
    if (nextState.isCompleted && nextState.result != null) {
      await repo.finalizeSession(
        sessionState: nextState,
        result: nextState.result!,
      );
      // Invalidate past results cache so UI updates instantly
      ref.invalidate(latestAssessmentResultProvider);
    }

    state = AsyncValue.data(nextState);
  }

  /// Skips the current question (marks as skipped turn without penalizing).
  Future<void> skipCurrentQuestion() async {
    final current = state.value;
    if (current == null || current.activeItem == null || current.isCompleted) {
      return;
    }

    final repo = ref.read(placementTestRepositoryProvider);
    final engine = repo.engine;

    final nextState = engine.processTurn(
      currentState: current,
      userAnswer: null,
      latencyMs: 500,
      isSkipped: true,
    );

    final lastResponse = nextState.responses.last;
    await repo.saveTurnResponse(
      sessionId: current.sessionId,
      response: lastResponse,
      updatedTheta: nextState.currentTheta,
      updatedSe: nextState.currentStandardError,
      stepIndex: nextState.stepIndex,
    );

    if (nextState.isCompleted && nextState.result != null) {
      await repo.finalizeSession(
        sessionState: nextState,
        result: nextState.result!,
      );
      ref.invalidate(latestAssessmentResultProvider);
    }

    state = AsyncValue.data(nextState);
  }

  /// Abandons the active session to restart from scratch.
  Future<void> abandonSession() async {
    final current = state.value;
    if (current != null) {
      final repo = ref.read(placementTestRepositoryProvider);
      await repo.abandonSession(current.sessionId);
    }
    state = const AsyncValue.data(null);
  }
}

/// Active CAT session provider.
final activeCatSessionProvider =
    AsyncNotifierProvider<ActiveCatSessionNotifier, CatSessionState?>(
  ActiveCatSessionNotifier.new,
);

/// Provider exposing the latest completed assessment result.
final latestAssessmentResultProvider =
    FutureProvider<CatAssessmentResult?>((ref) async {
  final repo = ref.watch(placementTestRepositoryProvider);
  return await repo.getLatestCompletedResult();
});
