import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../../vocabulary_srs/vocabulary_srs.dart';

/// Tab 3: Spaced Repetition System (SRS SM-2) Review Screen.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> with AutomaticKeepAliveClientMixin {
  bool _isAnswerRevealed = false;
  int _currentCardIndex = 0;

  final List<Map<String, String>> _sampleReviewCards = [
    {
      'hanzi': '银行',
      'pinyin': 'yínháng',
      'meaning': 'Ngân hàng',
      'example': '我[wǒ]去[qù]银行[yínháng]取[qǔ]钱[qián]。',
    },
    {
      'hanzi': '朋友',
      'pinyin': 'péngyou',
      'meaning': 'Bạn bè, người bạn',
      'example': '他[tā]是[shì]我[wǒ]的[de]好[hǎo]朋友[péngyou]。',
    },
    {
      'hanzi': '学习',
      'pinyin': 'xuéxí',
      'meaning': 'Học tập, học hỏi',
      'example': '我们[wǒmen]一起[yìqǐ]学习[xuéxí]汉语[hànyǔ]。',
    },
  ];

  @override
  bool get wantKeepAlive => true;

  void _handleRating(String ratingName, int quality) {
    HiSnackBar.showSuccess(
      context,
      'Đã ghi nhận "$ratingName" (Quality: $quality) theo thuật toán SM-2.',
    );

    setState(() {
      _isAnswerRevealed = false;
      _currentCardIndex = (_currentCardIndex + 1) % _sampleReviewCards.length;
    });

    ref.read(srsDueCountProvider.notifier).refreshCount();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final card = _sampleReviewCards[_currentCardIndex];
    final dueCountAsync = ref.watch(srsDueCountProvider);
    final dueCountStr = dueCountAsync.when(
      data: (count) => count.toString(),
      loading: () => '...',
      error: (_, _) => '0',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ôn Tập Ngắt Quãng (SM-2)'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Stats Row
              Row(
                children: [
                  _buildStatCard(title: 'Cần ôn hôm nay', value: dueCountStr, color: AppColors.limeGreen),
                  const SizedBox(width: AppSpacing.sm),
                  _buildStatCard(title: 'Đã thuộc', value: '128', color: Colors.blueAccent),
                  const SizedBox(width: AppSpacing.sm),
                  _buildStatCard(title: 'Tỷ lệ nhớ', value: '94%', color: Colors.greenAccent),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Flashcard Surface
              HiCard(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.xxl),
                child: Column(
                  children: [
                    Text(
                      'Thẻ ${_currentCardIndex + 1} / ${_sampleReviewCards.length}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    // Large Hanzi Display
                    Text(
                      card['hanzi']!,
                      style: AppTypography.hanziLarge(color: theme.colorScheme.primary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    if (!_isAnswerRevealed) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      HiButton(
                        text: 'Hiện đáp án & Pinyin',
                        variant: HiButtonVariant.secondary,
                        icon: const Icon(Icons.visibility_rounded),
                        onPressed: () {
                          setState(() {
                            _isAnswerRevealed = true;
                          });
                        },
                      ),
                    ] else ...[
                      // Pinyin and Meaning
                      Text(
                        card['pinyin']!,
                        style: AppTypography.pinyinLarge(color: theme.colorScheme.onSurface),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        card['meaning']!,
                        style: AppTypography.vietnameseMeaning(color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const Divider(height: AppSpacing.xxl),
                      Text(
                        'Câu ví dụ:',
                        style: theme.textTheme.labelSmall,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      RubyText.fromAnnotatedString(
                        annotatedText: card['example']!,
                        showPinyin: true,
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // 4 SM-2 Buttons: Again, Hard, Good, Easy
                      Row(
                        children: [
                          Expanded(
                            child: HiButton(
                              text: 'Again (1)',
                              variant: HiButtonVariant.danger,
                              size: HiButtonSize.sm,
                              onPressed: () => _handleRating('Again', 1),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: HiButton(
                              text: 'Hard (3)',
                              variant: HiButtonVariant.secondary,
                              size: HiButtonSize.sm,
                              onPressed: () => _handleRating('Hard', 3),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: HiButton(
                              text: 'Good (4)',
                              variant: HiButtonVariant.primary,
                              size: HiButtonSize.sm,
                              onPressed: () => _handleRating('Good', 4),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: HiButton(
                              text: 'Easy (5)',
                              variant: HiButtonVariant.primary,
                              size: HiButtonSize.sm,
                              onPressed: () => _handleRating('Easy', 5),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
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
