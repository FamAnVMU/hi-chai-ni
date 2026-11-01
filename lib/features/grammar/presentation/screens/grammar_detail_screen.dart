import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/grammar_models.dart';
import '../providers/grammar_providers.dart';
import '../widgets/contrastive_example_card.dart';
import '../widgets/grammar_exercise_widget.dart';
import '../widgets/grammar_rule_card.dart';

/// Screen presenting in-depth Chinese grammar lesson with rules, contrastive examples,
/// and interactive practice exercises with academic rubric evaluation.
class GrammarDetailScreen extends ConsumerStatefulWidget {
  final String grammarId;

  const GrammarDetailScreen({super.key, required this.grammarId});

  @override
  ConsumerState<GrammarDetailScreen> createState() => _GrammarDetailScreenState();
}

class _GrammarDetailScreenState extends ConsumerState<GrammarDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final Map<int, ExerciseEvaluationResult> _exerciseResults = {};
  bool _isSavingProgress = false;
  late final Stopwatch _stopwatch;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _stopwatch = Stopwatch()..start();
  }

  @override
  void dispose() {
    _stopwatch.stop();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleCompleteExercises(GrammarItem item) async {
    if (_exerciseResults.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng làm ít nhất một bài tập trước khi lưu tiến độ.')),
      );
      return;
    }

    setState(() => _isSavingProgress = true);

    // Calculate aggregated score across completed exercises
    final totalScore = _exerciseResults.values.fold<double>(0.0, (acc, r) => acc + r.score);
    final avgScore = totalScore / _exerciseResults.length;
    final durationSeconds = _stopwatch.elapsed.inSeconds.clamp(10, 3600);

    final repo = ref.read(grammarRepositoryProvider);
    await repo.recordStudySession(
      grammarId: item.id,
      score: avgScore,
      durationSeconds: durationSeconds,
      exercisesCount: _exerciseResults.length,
    );

    // Invalidate providers to refresh UI state
    ref.invalidate(grammarProgressMapProvider);
    ref.invalidate(grammarItemProgressProvider(item.id));

    if (!mounted) return;
    setState(() => _isSavingProgress = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Đã lưu tiến độ! Điểm bài tập: ${(avgScore * 100).toInt()}% (${avgScore >= 0.8 ? "Đã thành thạo" : "Đang rèn luyện"}).',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final itemAsync = ref.watch(grammarDetailProvider(widget.grammarId));
    final progressAsync = ref.watch(grammarItemProgressProvider(widget.grammarId));

    return itemAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Đang tải...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, stack) => Scaffold(
        appBar: AppBar(title: const Text('Lỗi')),
        body: Center(child: Text('Không thể tải ngữ pháp: $err')),
      ),
      data: (item) {
        if (item == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Không tìm thấy')),
            body: const Center(child: Text('Điểm ngữ pháp không tồn tại.')),
          );
        }

        final progress = progressAsync.value;
        final status = progress?.status ?? GrammarProgressStatus.unlearned;

        return Scaffold(
          appBar: AppBar(
            title: Text(item.title),
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.menu_book_rounded), text: 'Cấu trúc'),
                Tab(icon: Icon(Icons.compare_arrows_rounded), text: 'Ví dụ & Lỗi sai'),
                Tab(icon: Icon(Icons.edit_note_rounded), text: 'Luyện tập'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Tab 1: Structure & Rules
              ListView(
                padding: AppSpacing.screenPadding,
                children: [
                  GrammarRuleCard(item: item),
                  const SizedBox(height: AppSpacing.md),
                  HiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Giải Thích Chi Tiết',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(item.explanationVi, style: theme.textTheme.bodyMedium),
                        if (item.tags.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.xs,
                            runSpacing: AppSpacing.xs,
                            children: item.tags.map((t) => Chip(label: Text('#$t'))).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),

              // Tab 2: Examples & Contrastive Mistakes
              ListView(
                padding: AppSpacing.screenPadding,
                children: [
                  Text(
                    'Câu Ví Dụ Chuẩn Xác',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ...item.examples.map((ex) => _buildStandardExampleCard(context, ex)),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Lỗi Thường Gặp & Ví Dụ Đối Chiếu (L1 Transfer)',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Phân tích các lỗi sai phổ biến do người học áp dụng trật tự ngữ pháp tiếng Việt.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...item.contrastiveExamples.map((ce) => ContrastiveExampleCard(example: ce)),
                ],
              ),

              // Tab 3: Practice Exercises
              ListView(
                padding: AppSpacing.screenPadding,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Bài Tập Áp Dụng (${item.exercises.length} câu)',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      HiChip(
                        label: status.displayName,
                        status: status == GrammarProgressStatus.mastered
                            ? HiChipStatus.success
                            : HiChipStatus.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ...List.generate(item.exercises.length, (idx) {
                    final ex = item.exercises[idx];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: GrammarExerciseWidget(
                        exercise: ex,
                        exerciseIndex: idx,
                        onEvaluated: (result) {
                          _exerciseResults[idx] = result;
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: AppSpacing.md),
                  HiButton(
                    text: _isSavingProgress ? 'Đang lưu kết quả...' : 'Hoàn thành bài tập & Lưu tiến độ',
                    isLoading: _isSavingProgress,
                    variant: HiButtonVariant.primary,
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    onPressed: _isSavingProgress ? null : () => _handleCompleteExercises(item),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStandardExampleCard(BuildContext context, GrammarExample example) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(70)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              example.hanzi,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              example.pinyin,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(example.translationVi, style: theme.textTheme.bodyMedium),
            if (example.breakdown != null) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  example.breakdown!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
