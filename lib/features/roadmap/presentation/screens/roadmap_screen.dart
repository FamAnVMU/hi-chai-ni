import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../../hanzi_writing/hanzi_writing.dart';
import '../../../pronunciation/pronunciation.dart';
import '../../../reading/reading.dart';
import '../../../grammar/grammar.dart';
import '../../../review/presentation/screens/review_screen.dart';
import '../../domain/catalog/curriculum_catalog.dart';
import '../../domain/models/roadmap_models.dart';
import '../providers/roadmap_providers.dart';
import '../widgets/goal_settings_sheet.dart';
import '../widgets/lesson_detail_sheet.dart';
import '../widgets/roadmap_recommendation_card.dart';

/// Screen presenting the full adaptive curriculum roadmap with personal progress.
class RoadmapScreen extends ConsumerStatefulWidget {
  const RoadmapScreen({super.key});

  @override
  ConsumerState<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends ConsumerState<RoadmapScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roadmapAsync = ref.watch(adaptiveRoadmapProvider);
    final selectedLevel = ref.watch(selectedRoadmapLevelProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lộ Trình Thích Ứng'),
        actions: [
          IconButton(
            tooltip: 'Làm mới lộ trình',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(adaptiveRoadmapProvider.notifier).refresh(),
          ),
        ],
      ),
      body: SafeArea(
        child: roadmapAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.errorLight),
                  const SizedBox(height: AppSpacing.md),
                  Text('Không thể tải lộ trình: $err', textAlign: TextAlign.center),
                  const SizedBox(height: AppSpacing.md),
                  HiButton(
                    text: 'Thử lại',
                    onPressed: () => ref.read(adaptiveRoadmapProvider.notifier).refresh(),
                  ),
                ],
              ),
            ),
          ),
          data: (state) {
            final activeGoal = state.activeGoal;
            final curriculumLevel = CurriculumCatalog.getLevel(selectedLevel);
            final progressMap = state.lessonProgressMap;

            return ListView(
              padding: AppSpacing.screenPadding,
              children: [
                // 1. Goal Overview Card
                _buildGoalHeader(context, activeGoal),
                const SizedBox(height: AppSpacing.md),

                // 2. Level Selector
                _buildLevelSelector(selectedLevel),
                const SizedBox(height: AppSpacing.md),

                // 3. Level Completion Progress
                _buildLevelProgressBar(context, selectedLevel, state),
                const SizedBox(height: AppSpacing.lg),

                // 4. Adaptive Recommendations (Top 3)
                RoadmapRecommendationCard(
                  recommendations: state.recommendations,
                  onSelectLesson: (lesson) => _onOpenLesson(context, lesson, progressMap),
                  onSkipLesson: (lesson) => _onSkipLesson(lesson),
                ),
                const SizedBox(height: AppSpacing.lg),

                // 5. Skill Mastery Overview
                _buildSkillMasteryGrid(context, state.skillMasteryMap),
                const SizedBox(height: AppSpacing.lg),

                // 6. Curriculum Units & Lessons
                Text(
                  'Chi Tiết Giáo Trình HSK $selectedLevel',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Hoàn thành bài tiên quyết để mở khóa các bài tiếp theo.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                if (curriculumLevel.units.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Center(
                      child: Text(
                        'Nội dung HSK $selectedLevel đang được biên soạn.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                else
                  ...curriculumLevel.units.map(
                    (unit) => _buildUnitCard(context, unit, progressMap),
                  ),

                const SizedBox(height: AppSpacing.xxl),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildGoalHeader(BuildContext context, LearnerGoal goal) {
    final theme = Theme.of(context);

    return HiCard(
      backgroundColor: theme.colorScheme.primaryContainer.withAlpha(50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.emoji_events_rounded,
                color: AppColors.limeGreen,
                size: AppDimensions.iconMd,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Mục Tiêu Của Bạn: HSK ${goal.targetHskLevel}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  GoalSettingsSheet.show(
                    context: context,
                    currentGoal: goal,
                    onSave: (updated) {
                      ref.read(adaptiveRoadmapProvider.notifier).updateGoal(updated);
                    },
                  );
                },
                child: const Text('Thay đổi'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${goal.purpose.displayName} • ${goal.timeframe.displayName} • ${goal.dailyMinutes} phút/ngày',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLevelSelector(int currentSelectedLevel) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [1, 2, 3, 4, 5].map((lvl) {
          final isSelected = currentSelectedLevel == lvl;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: HiChip(
              label: 'HSK $lvl',
              isSelected: isSelected,
              onTap: () {
                ref.read(selectedRoadmapLevelProvider.notifier).selectLevel(lvl);
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildLevelProgressBar(
    BuildContext context,
    int selectedLevel,
    LearnerRoadmapState state,
  ) {
    final theme = Theme.of(context);
    final levelLessons = state.lessonProgressMap.values.where((p) => p.hskLevel == selectedLevel).toList();
    final completedCount = levelLessons.where((p) => p.isCompleted).length;
    final totalCount = levelLessons.length;
    final double completionRate = totalCount == 0 ? 0.0 : (completedCount / totalCount);

    return HiCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Tiến độ HSK $selectedLevel:',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$completedCount / $totalCount bài (${(completionRate * 100).toInt()}%)',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.limeGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: completionRate,
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.limeGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillMasteryGrid(
    BuildContext context,
    Map<SkillDimension, SkillMastery> masteryMap,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Độ Thành Thạo 6 Kỹ Năng',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Được tính toán liên tục từ bài kiểm tra và bài tập thực hành.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: SkillDimension.values.map((dim) {
            final mastery = masteryMap[dim];
            final rate = mastery?.masteryRate ?? 0.0;
            final percent = (rate * 100).toInt();

            return Container(
              width: (MediaQuery.of(context).size.width - AppSpacing.lg * 2 - AppSpacing.sm) / 2,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withAlpha(80),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dim.displayName,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '$percent%',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: rate >= 0.7 ? AppColors.limeGreen : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    child: LinearProgressIndicator(
                      value: rate,
                      minHeight: 4,
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        rate >= 0.7 ? AppColors.limeGreen : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildUnitCard(
    BuildContext context,
    CurriculumUnit unit,
    Map<String, LessonProgress> progressMap,
  ) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.limeGreen.withAlpha(30),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  'Unit ${unit.unitNumber}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.limeGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  unit.title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            unit.description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...unit.lessons.map(
            (lesson) => _buildLessonItem(context, lesson, progressMap),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonItem(
    BuildContext context,
    CurriculumLesson lesson,
    Map<String, LessonProgress> progressMap,
  ) {
    final theme = Theme.of(context);
    final progress = progressMap[lesson.id];
    final status = progress?.status ?? LessonStatus.locked;

    IconData statusIcon;
    Color statusColor;

    switch (status) {
      case LessonStatus.completed:
        statusIcon = Icons.check_circle_rounded;
        statusColor = AppColors.limeGreen;
        break;
      case LessonStatus.inProgress:
        statusIcon = Icons.timelapse_rounded;
        statusColor = Colors.orange;
        break;
      case LessonStatus.available:
        statusIcon = Icons.lock_open_rounded;
        statusColor = AppColors.limeGreen;
        break;
      case LessonStatus.skipped:
        statusIcon = Icons.skip_next_rounded;
        statusColor = theme.colorScheme.outline;
        break;
      case LessonStatus.locked:
        statusIcon = Icons.lock_outline_rounded;
        statusColor = theme.colorScheme.outlineVariant;
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: InkWell(
        onTap: () => _onOpenLesson(context, lesson, progressMap),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: status == LessonStatus.inProgress
                ? theme.colorScheme.primaryContainer.withAlpha(40)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: status == LessonStatus.inProgress
                  ? AppColors.limeGreen.withAlpha(120)
                  : theme.colorScheme.outlineVariant.withAlpha(60),
            ),
          ),
          child: Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lesson.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: status == LessonStatus.locked
                            ? theme.colorScheme.onSurfaceVariant
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lesson.primarySkill.displayName} • ~${lesson.estimatedMinutes}p',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (progress?.completionScore != null)
                Text(
                  '${(progress!.completionScore! * 100).toInt()}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.limeGreen,
                  ),
                ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: theme.colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onOpenLesson(
    BuildContext context,
    CurriculumLesson lesson,
    Map<String, LessonProgress> progressMap,
  ) {
    LessonDetailSheet.show(
      context: context,
      lesson: lesson,
      progress: progressMap[lesson.id],
      allProgressMap: progressMap,
      onStart: () async {
        // Start lesson explicitly (changes status to inProgress, NEVER marks completed!)
        await ref.read(adaptiveRoadmapProvider.notifier).startLesson(lesson.id);

        if (!context.mounted) return;

        // Navigate to appropriate skill practice screen
        switch (lesson.primarySkill) {
          case SkillDimension.writing:
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HanziWritingScreen()),
            );
            break;
          case SkillDimension.speaking:
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PronunciationLabScreen()),
            );
            break;
          case SkillDimension.reading:
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReadingPassageListScreen()),
            );
            break;
          case SkillDimension.grammar:
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const GrammarListScreen()),
            );
            break;
          case SkillDimension.vocabulary:
          case SkillDimension.listening:
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ReviewScreen()),
            );
            break;
        }
      },
      onComplete: (score) async {
        await ref.read(adaptiveRoadmapProvider.notifier).completeLesson(
              lessonId: lesson.id,
              score: score,
            );
      },
      onSkip: () async {
        await _onSkipLesson(lesson);
      },
    );
  }

  Future<void> _onSkipLesson(CurriculumLesson lesson) async {
    await ref.read(adaptiveRoadmapProvider.notifier).skipLesson(lesson.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã bỏ qua bài "${lesson.title}"')),
    );
  }
}
