import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../../content_packs/presentation/screens/content_pack_manager_screen.dart';
import '../../../curriculum/domain/models/curriculum_models.dart';
import '../../../curriculum/presentation/providers/curriculum_providers.dart';
import '../../../curriculum/presentation/screens/curriculum_syllabus_screen.dart';
import '../../../curriculum/presentation/screens/lesson_study_screen.dart';
import '../../../dictionary/dictionary.dart';
import '../../../grammar/grammar.dart';
import '../../../hanzi_writing/hanzi_writing.dart';
import '../../../listening/listening.dart';
import '../../../placement_test/placement_test.dart';
import '../../../practice/practice.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import '../../../pronunciation/pronunciation.dart';
import '../../../reading/reading.dart';
import '../../../roadmap/roadmap.dart'
    hide CurriculumUnit, CurriculumLesson, LessonStatus;
import '../../../shadowing/shadowing.dart';

class LearningScreen extends ConsumerStatefulWidget {
  const LearningScreen({super.key});

  @override
  ConsumerState<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends ConsumerState<LearningScreen>
    with AutomaticKeepAliveClientMixin {
  String _selectedLevel = 'HSK 1';
  bool _hasSyncedLevelWithProfile = false;

  @override
  bool get wantKeepAlive => true;

  int get _hskLevel {
    final match = RegExp(r'\d+').firstMatch(_selectedLevel);
    return match != null ? int.parse(match.group(0)!) : 1;
  }

  String get _curriculumId => CurriculumConstants.curriculumIdForLevel(_hskLevel);

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    final profileAsync = ref.watch(userProfileProvider);
    if (!_hasSyncedLevelWithProfile && profileAsync.hasValue && profileAsync.value != null) {
      final userHsk = profileAsync.value!.currentHskLevel;
      final safeHsk = (userHsk <= 0) ? 1 : (userHsk > 5 ? 5 : userHsk);
      _selectedLevel = 'HSK $safeHsk';
      _hasSyncedLevelWithProfile = true;
    }

    final unitsAsync = ref.watch(curriculumUnitsWithLessonsProvider(_curriculumId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lộ Trình Học Tập'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_for_offline_outlined),
            tooltip: 'Kho học liệu HSK',
            onPressed: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) => const ContentPackManagerScreen(),
                    ),
                  )
                  .then((_) {
                ref.invalidate(curriculumUnitsWithLessonsProvider(_curriculumId));
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            _buildCurriculumBanner(context, unitsAsync),
            const SizedBox(height: AppSpacing.lg),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['HSK 1', 'HSK 2', 'HSK 3', 'HSK 4', 'HSK 5'].map((level) {
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: HiChip(
                      label: level,
                      isSelected: _selectedLevel == level,
                      onTap: () {
                        setState(() {
                          _selectedLevel = level;
                        });
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            _buildFeatureBanner(
              context: context,
              icon: Icons.auto_awesome_rounded,
              title: 'Khảo sát năng lực đầu vào',
              subtitle: 'Kiểm tra thích ứng 6 kỹ năng để chọn lớp HSK',
              buttonText: 'Làm bài',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PlacementTestIntroScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),

            _buildFeatureBanner(
              context: context,
              icon: Icons.map_rounded,
              title: 'Lộ trình thích ứng cá nhân',
              subtitle: 'Đề xuất thông minh theo điểm thực tế & tiên quyết',
              buttonText: 'Xem lộ trình',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const RoadmapScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),

            _buildFeatureBanner(
              context: context,
              icon: Icons.brush_rounded,
              title: 'Luyện viết chữ Hán',
              subtitle: 'Tập vẽ nét bút thuận trên ô Mizige (米字格)',
              buttonText: 'Luyện viết',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const HanziWritingScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),

            Row(
              children: [
                Expanded(
                  child: _buildCompactActionCard(
                    context: context,
                    icon: Icons.record_voice_over_rounded,
                    title: 'Luyện phát âm',
                    subtitle: 'Âm vị & Thanh điệu',
                    buttonText: 'Luyện âm',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PronunciationLabScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildCompactActionCard(
                    context: context,
                    icon: Icons.speed_rounded,
                    title: 'Shadowing',
                    subtitle: 'Nói đuổi & Nhịp độ',
                    buttonText: 'Luyện nói',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ShadowingScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            Row(
              children: [
                Expanded(
                  child: _buildCompactActionCard(
                    context: context,
                    icon: Icons.menu_book_rounded,
                    title: 'Luyện đọc hiểu',
                    subtitle: 'Tương tác & Tra từ',
                    buttonText: 'Đọc hiểu',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReadingPassageListScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _buildCompactActionCard(
                    context: context,
                    icon: Icons.search_rounded,
                    title: 'Từ điển',
                    subtitle: 'Tra cứu offline',
                    buttonText: 'Tra từ',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DictionaryScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            _buildFeatureBanner(
              context: context,
              icon: Icons.auto_stories_rounded,
              title: 'Ngữ pháp tiếng Hán',
              subtitle: 'Cấu trúc câu, ví dụ đối chiếu L1 & bài tập áp dụng',
              buttonText: 'Học ngữ pháp',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const GrammarListScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),

            _buildFeatureBanner(
              context: context,
              icon: Icons.quiz_rounded,
              title: 'Luyện tập tương tác (Practice Engine)',
              subtitle: '7 dạng bài tập chuẩn mực: trắc nghiệm, ghép cặp, điền từ...',
              buttonText: 'Luyện tập',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PracticeSessionScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.sm),

            _buildFeatureBanner(
              context: context,
              icon: Icons.headphones_rounded,
              title: 'Luyện nghe hiểu hội thoại',
              subtitle: 'Hội thoại chuẩn người bản xứ, tùy chỉnh tốc độ và câu hỏi hiểu',
              buttonText: 'Nghe ngay',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ListeningScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),

            unitsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Center(
                  child: Column(
                    children: [
                      HiLoadingIndicator(),
                      SizedBox(height: AppSpacing.sm),
                      Text('Đang nạp bài học...'),
                    ],
                  ),
                ),
              ),
              error: (err, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: HiCard(
                  backgroundColor: AppColors.error.withAlpha(20),
                  borderColor: AppColors.error.withAlpha(80),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppColors.error, size: 36),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Không thể tải danh sách bài học $_selectedLevel',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        err.toString(),
                        style: theme.textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      HiButton(
                        text: 'Thử lại',
                        size: HiButtonSize.sm,
                        variant: HiButtonVariant.secondary,
                        onPressed: () {
                          ref.invalidate(
                              curriculumUnitsWithLessonsProvider(_curriculumId));
                        },
                      ),
                    ],
                  ),
                ),
              ),
              data: (units) {
                if (units.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                    child: HiCard(
                      backgroundColor: AppColors.cardBackground,
                      borderColor: AppColors.border,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.inventory_2_outlined,
                            size: 48,
                            color: AppColors.secondaryText,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Chưa có học liệu cho $_selectedLevel',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Giáo trình và bài học của cấp độ này chưa được tải về máy. Hãy mở Kho học liệu để cài đặt gói bài học HSK.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.secondaryText,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          HiButton(
                            text: 'Mở kho học liệu HSK',
                            icon: const Icon(Icons.download_for_offline_outlined),
                            variant: HiButtonVariant.primary,
                            size: HiButtonSize.sm,
                            onPressed: () {
                              Navigator.of(context)
                                  .push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const ContentPackManagerScreen(),
                                    ),
                                  )
                                  .then((_) {
                                ref.invalidate(
                                    curriculumUnitsWithLessonsProvider(_curriculumId));
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: units.map((unit) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Chương ${unit.orderIndex}: ${unit.titleVi}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText,
                          ),
                        ),
                        if (unit.titleZh.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            unit.titleZh,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.md),
                        ...unit.lessons.map((lesson) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.md),
                            child: _buildLessonCard(context, lesson),
                          );
                        }),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: AppSpacing.huge),
          ],
        ),
      ),
    );
  }

  Widget _buildCurriculumBanner(
    BuildContext context,
    AsyncValue<List<CurriculumUnit>> unitsAsync,
  ) {
    final theme = Theme.of(context);
    final units = unitsAsync.value;
    final totalLessons = units != null
        ? units.fold<int>(0, (int sum, u) => sum + u.lessons.length)
        : 0;

    return HiCard(
      backgroundColor: AppColors.primaryBlueLight,
      borderColor: AppColors.secondaryBlue,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryBlueDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Giáo Trình $_selectedLevel Chuẩn',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlueDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  totalLessons > 0
                      ? '$totalLessons bài học liên hoàn • Giáo trình chuẩn'
                      : 'Giáo trình chuẩn quốc tế HSK',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          HiButton(
            text: 'Học ngay',
            size: HiButtonSize.sm,
            variant: HiButtonVariant.primary,
            onPressed: () {
              Navigator.of(context)
                  .push(
                    MaterialPageRoute(
                      builder: (_) => CurriculumSyllabusScreen(
                        curriculumId: _curriculumId,
                        curriculumTitle: 'Giáo trình $_selectedLevel Chuẩn',
                      ),
                    ),
                  )
                  .then((_) {
                ref.invalidate(curriculumUnitsWithLessonsProvider(_curriculumId));
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBanner({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);

    return HiCard(
      backgroundColor: AppColors.cardBackground,
      borderColor: AppColors.border,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primaryBlueLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryBlueDark,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          HiButton(
            text: buttonText,
            size: HiButtonSize.sm,
            variant: HiButtonVariant.secondary,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactActionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    final theme = Theme.of(context);

    return HiCard(
      backgroundColor: AppColors.cardBackground,
      borderColor: AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.primaryBlueLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryBlueDark,
              size: 22,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
            ),
          ),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          HiButton(
            text: buttonText,
            size: HiButtonSize.sm,
            variant: HiButtonVariant.secondary,
            isFullWidth: true,
            onPressed: onPressed,
          ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(BuildContext context, CurriculumLesson lesson) {
    final theme = Theme.of(context);

    int vocabCount = 0;
    for (final seg in lesson.segments) {
      if (seg.contentPayload != null && seg.contentPayload!['words'] is List) {
        vocabCount += (seg.contentPayload!['words'] as List).length;
      }
    }

    final double progress;
    final HiChipStatus status;
    final String statusText;

    if (lesson.isLocked) {
      progress = 0.0;
      status = HiChipStatus.neutral;
      statusText = 'Chưa mở khóa';
    } else if (lesson.status == LessonStatus.completed ||
        lesson.status == LessonStatus.mastered) {
      progress = 1.0;
      status = HiChipStatus.success;
      statusText = 'Đã hoàn thành';
    } else if (lesson.status == LessonStatus.inProgress) {
      progress = (lesson.masteryScore > 0 ? lesson.masteryScore : 0.5)
          .clamp(0.01, 0.99);
      status = HiChipStatus.warning;
      statusText = 'Đang học (${(progress * 100).toInt()}%)';
    } else {
      progress = 0.0;
      status = HiChipStatus.info;
      statusText = 'Chưa học';
    }

    return HiCard(
      backgroundColor: AppColors.cardBackground,
      borderColor: AppColors.border,
      onTap: () {
        if (lesson.isLocked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Bài học đang bị khóa. Hãy hoàn thành đạt ≥ 80% các bài học tiên quyết.',
              ),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) => LessonStudyScreen(lesson: lesson),
                ),
              )
              .then((_) {
            ref.invalidate(curriculumUnitsWithLessonsProvider(_curriculumId));
          });
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bài ${lesson.orderIndex}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.primaryBlueDark,
                  fontWeight: FontWeight.bold,
                ),
              ),
              HiChip(
                label: statusText,
                status: status,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            lesson.titleVi,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
            ),
          ),
          if (lesson.titleZh.isNotEmpty || lesson.pinyin.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${lesson.titleZh}${lesson.pinyin.isNotEmpty ? ' • ${lesson.pinyin}' : ''}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.primaryBlueDark,
                fontWeight: FontWeight.w600,
                fontFamilyFallback: const ['Noto Sans SC', 'Heiti SC'],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          HiLinearProgress(value: progress),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                vocabCount > 0 ? '$vocabCount từ vựng' : '${lesson.estimatedMinutes} phút',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.mutedText,
                ),
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlueDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
