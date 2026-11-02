import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../../vocabulary_srs/vocabulary_srs.dart';

/// Tab 4: Spaced Repetition System (SRS SM-2) Review Screen.
/// Connects directly to SQLite-backed SM-2 engine, supports 3D card flip,
/// 4 rating grades with interval explanations, and offline persistence.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  late final AppLifecycleListener _lifecycleListener;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        // Refresh due counts when app returns from background
        ref.read(srsDueCountProvider.notifier).refreshCount();
      },
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final sessionAsync = ref.watch(srsStudySessionProvider);
    final dueCountAsync = ref.watch(srsDueCountProvider);

    final dueCountStr = dueCountAsync.when(
      data: (count) => count.toString(),
      loading: () => '...',
      error: (_, _) => '0',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ôn Tập Ngắt Quãng (SM-2)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại hàng đợi',
            onPressed: () {
              ref.read(srsStudySessionProvider.notifier).loadMoreCards();
              ref.read(srsDueCountProvider.notifier).refreshCount();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: sessionAsync.when(
          loading: () => const Center(
            child: HiLoadingIndicator(
              message: 'Đang tải hàng đợi thẻ ôn tập SM-2...',
            ),
          ),
          error: (error, _) => HiErrorState(
            title: 'Không thể tải thẻ ôn tập',
            message: error.toString(),
            onRetry: () => ref.refresh(srsStudySessionProvider),
          ),
          data: (session) {
            final card = session.currentCard;

            // Empty queue or completed session
            if (session.isEmpty || session.isCompleted || card == null) {
              return FlashcardEmptyState(
                completedReviewsCount: session.completedReviewsCount,
                accuracyRate: session.accuracyRate,
                onLoadMoreWords: () => ref
                    .read(srsStudySessionProvider.notifier)
                    .loadMoreCards(limit: 15),
              );
            }

            final reviewedCount = session.completedReviewsCount;
            final accuracyPercent =
                (session.accuracyRate * 100).toStringAsFixed(0);

            return SingleChildScrollView(
              padding: AppSpacing.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Stats Overview Row
                  Row(
                    children: [
                      _buildStatCard(
                        title: 'Cần ôn hôm nay',
                        value: dueCountStr,
                        color: AppColors.primaryBlueDark,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _buildStatCard(
                        title: 'Đã ôn phiên này',
                        value: reviewedCount.toString(),
                        color: AppColors.primaryBlue,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _buildStatCard(
                        title: 'Tỷ lệ nhớ',
                        value: '$accuracyPercent%',
                        color: AppColors.success,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Session Progress Header
                  FlashcardProgressHeader(
                    currentIndex: session.currentIndex,
                    totalCards: session.queue.length,
                    remainingCards: session.remainingCards,
                    hasSavedOffline: session.hasSavedOffline,
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // 3D Flip Flashcard
                  FlashcardCard(
                    card: card,
                    isFlipped: session.isAnswerRevealed,
                    showPinyinOnFront: session.isPinyinVisibleOnFront,
                    onFlip: () => ref
                        .read(srsStudySessionProvider.notifier)
                        .flipCard(),
                    onTogglePinyin: () => ref
                        .read(srsStudySessionProvider.notifier)
                        .togglePinyinVisibility(),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Bottom Controls
                  if (!session.isAnswerRevealed) ...[
                    HiButton(
                      text: 'Xem đáp án (Lật thẻ)',
                      icon: const Icon(Icons.flip_rounded),
                      variant: HiButtonVariant.primary,
                      size: HiButtonSize.lg,
                      isFullWidth: true,
                      onPressed: () => ref
                          .read(srsStudySessionProvider.notifier)
                          .flipCard(),
                    ),
                  ] else ...[
                    Text(
                      'Đánh giá khả năng ghi nhớ:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    FlashcardRatingBar(
                      estimatedIntervals: card.estimatedIntervalDays,
                      isProcessing: session.isProcessingReview,
                      onRatingSelected: (rating) {
                        ref
                            .read(srsStudySessionProvider.notifier)
                            .submitRating(rating);
                      },
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Expanded(
      child: HiCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
