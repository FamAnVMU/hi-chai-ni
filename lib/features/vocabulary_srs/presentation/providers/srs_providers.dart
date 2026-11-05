import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_constants.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../data/srs_repository.dart';
import '../../domain/srs_models.dart';

final hasCompletedLessonsProvider = FutureProvider<bool>((ref) async {
  if (!AppDatabase.instance.isOpen) return false;
  final db = AppDatabase.instance.database;
  try {
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tableLessonProgress}
      WHERE status = 'completed'
      AND (source IS NULL OR source != 'placement_test')
    ''');
    final count = result.first['cnt'] as int? ?? 0;
    return count > 0;
  } catch (_) {
    return false;
  }
});

/// Provider exposing the SrsRepository instance tied to the active database.
final srsRepositoryProvider = Provider<SrsRepository>((ref) {
  final db = AppDatabase.instance.database;
  return SrsRepository(db);
});

/// Async notifier providing the reactive SRS due cards count.
/// Auto-memoized, filtered by current learner HSK level, and refreshed whenever reviews occur.
class SrsDueCountNotifier extends AsyncNotifier<int> {
  @override
  Future<int> build() async {
    try {
      final repo = ref.watch(srsRepositoryProvider);
      final profile = ref.watch(userProfileProvider).value;
      return await repo.getDueCardsCount(hskLevel: profile?.currentHskLevel);
    } catch (_) {
      return 0;
    }
  }

  Future<void> refreshCount() async {
    try {
      final repo = ref.read(srsRepositoryProvider);
      final profile = ref.read(userProfileProvider).value;
      final count = await repo.getDueCardsCount(
        hskLevel: profile?.currentHskLevel,
        forceRefresh: true,
      );
      state = AsyncValue.data(count);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final srsDueCountProvider = AsyncNotifierProvider<SrsDueCountNotifier, int>(
  SrsDueCountNotifier.new,
);

/// State management for the active SRS Flashcard study session.
class SrsStudySessionNotifier extends AsyncNotifier<SrsStudySession> {
  @override
  Future<SrsStudySession> build() async {
    final repo = ref.watch(srsRepositoryProvider);
    final profile = ref.watch(userProfileProvider).value;
    final cards = await repo.getDueFlashcards(
      limit: 25,
      hskLevel: profile?.currentHskLevel,
    );
    return SrsStudySession(queue: cards);
  }

  void flipCard() {
    final current = state.value;
    if (current == null || current.isCompleted) return;
    state = AsyncValue.data(
      current.copyWith(isAnswerRevealed: !current.isAnswerRevealed),
    );
  }

  void togglePinyinVisibility() {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(isPinyinVisibleOnFront: !current.isPinyinVisibleOnFront),
    );
  }

  Future<void> submitRating(SrsRating rating) async {
    final current = state.value;
    if (current == null || current.isCompleted || current.isProcessingReview) {
      return;
    }

    final card = current.currentCard;
    if (card == null) return;

    // Lock against duplicate rapid taps
    state = AsyncValue.data(current.copyWith(isProcessingReview: true));

    try {
      final repo = ref.read(srsRepositoryProvider);
      await repo.recordReviewAndProgress(
        item: card,
        rating: rating,
      );

      final isSuccess = rating != SrsRating.again;
      state = AsyncValue.data(
        current.copyWith(
          currentIndex: current.currentIndex + 1,
          isAnswerRevealed: false,
          isProcessingReview: false,
          hasSavedOffline: true,
          completedReviewsCount: current.completedReviewsCount + 1,
          correctReviewsCount: current.correctReviewsCount + (isSuccess ? 1 : 0),
        ),
      );

      // Refresh badge count
      ref.read(srsDueCountProvider.notifier).refreshCount();
    } catch (e) {
      // Revert processing flag and record error
      state = AsyncValue.data(
        current.copyWith(
          isProcessingReview: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> loadMoreCards({int limit = 15, int? hskLevel}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(srsRepositoryProvider);
      final profile = ref.read(userProfileProvider).value;
      final effectiveHsk = hskLevel ?? profile?.currentHskLevel;
      final cards = await repo.getDueFlashcards(limit: limit, hskLevel: effectiveHsk);
      return SrsStudySession(queue: cards);
    });
  }

  void restoreSessionIndex(int index) {
    final current = state.value;
    if (current == null) return;
    if (index >= 0 && index < current.queue.length) {
      state = AsyncValue.data(
        current.copyWith(currentIndex: index, isAnswerRevealed: false),
      );
    }
  }
}

final srsStudySessionProvider =
    AsyncNotifierProvider<SrsStudySessionNotifier, SrsStudySession>(
  SrsStudySessionNotifier.new,
);
