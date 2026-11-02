import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/curriculum_models.dart';
import '../providers/curriculum_providers.dart';
import 'lesson_study_screen.dart';
import 'level_exit_exam_screen.dart';

class CurriculumSyllabusScreen extends ConsumerWidget {
  final List<CurriculumUnit>? units;
  final String curriculumTitle;
  final String curriculumId;

  const CurriculumSyllabusScreen({
    super.key,
    this.units,
    this.curriculumTitle = 'Giáo trình HSK 1 Chuẩn',
    this.curriculumId = 'hsk_1_official',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // If units provided via constructor (e.g. in tests)
    if (units != null) {
      return _buildSyllabusContent(context, ref, units!);
    }

    // Otherwise load from DB via provider
    final unitsAsync = ref.watch(curriculumUnitsProvider(curriculumId));

    return Scaffold(
      appBar: AppBar(
        title: Text(curriculumTitle),
      ),
      body: unitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Lỗi nạp giáo trình: $err'),
        ),
        data: (loadedUnits) => _buildSyllabusContent(context, ref, loadedUnits),
      ),
    );
  }

  Widget _buildSyllabusContent(BuildContext context, WidgetRef ref, List<CurriculumUnit> displayUnits) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(curriculumTitle),
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          // Banner Đề thi tốt nghiệp HSK 1
          HiCard(
            backgroundColor: AppColors.limeGreenDark.withAlpha(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.limeGreenDark,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Thi tốt nghiệp HSK 1',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.limeGreenDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Đề thi chuẩn quốc tế 40 câu • 35 phút',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                HiButton(
                  text: 'Thi ngay',
                  size: HiButtonSize.sm,
                  variant: HiButtonVariant.primary,
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LevelExitExamScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Units List
          ...displayUnits.map((unit) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.limeGreen,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          unit.titleVi,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (unit.lessons.isEmpty)
                  _UnitLessonsAsyncLoader(unitId: unit.id)
                else
                  ...unit.lessons.map((lesson) => _buildLessonItem(context, lesson)),
                const SizedBox(height: AppSpacing.md),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildLessonItem(BuildContext context, CurriculumLesson lesson) {
    final theme = Theme.of(context);
    final isLocked = lesson.isLocked;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: HiCard(
        child: InkWell(
          onTap: () {
            if (isLocked) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Bài học đang bị khóa. Hãy hoàn thành đạt ≥ 80% các bài học tiên quyết.',
                  ),
                  duration: Duration(seconds: 2),
                ),
              );
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LessonStudyScreen(lesson: lesson),
                ),
              );
            }
          },
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isLocked
                      ? theme.colorScheme.surfaceContainerHighest
                      : AppColors.limeGreen.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isLocked ? Icons.lock_rounded : Icons.play_arrow_rounded,
                    color: isLocked ? Colors.grey : AppColors.limeGreenDark,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bài ${lesson.orderIndex}: ${lesson.titleVi}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isLocked ? theme.colorScheme.outline : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${lesson.titleZh} • ${lesson.pinyin}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isLocked ? theme.colorScheme.outline : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.limeGreenDark.withAlpha(15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    lesson.status == LessonStatus.completed || lesson.status == LessonStatus.mastered
                        ? 'Đã xong'
                        : 'Bắt đầu',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.limeGreenDark,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitLessonsAsyncLoader extends ConsumerWidget {
  final String unitId;

  const _UnitLessonsAsyncLoader({required this.unitId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lessonsAsync = ref.watch(curriculumLessonsProvider(unitId));

    return lessonsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Text('Lỗi nạp bài học: $err'),
      data: (lessons) => Column(
        children: lessons.map((l) {
          final parent = context.findAncestorWidgetOfExactType<CurriculumSyllabusScreen>();
          return parent?._buildLessonItem(context, l) ?? const SizedBox.shrink();
        }).toList(),
      ),
    );
  }
}
