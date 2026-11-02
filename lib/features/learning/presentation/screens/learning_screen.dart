import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../hanzi_writing/hanzi_writing.dart';
import '../../../placement_test/placement_test.dart';
import '../../../pronunciation/pronunciation.dart';
import '../../../shadowing/shadowing.dart';
import '../../../reading/reading.dart';
import '../../../dictionary/dictionary.dart';
import '../../../roadmap/roadmap.dart';
import '../../../grammar/grammar.dart';
import '../../../practice/practice.dart';
import '../../../listening/listening.dart';

/// Tab 1: Learning Screen featuring structured lessons and HSK roadmap.
class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> with AutomaticKeepAliveClientMixin {
  String _selectedLevel = 'HSK 1';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lộ Trình Học Tập'),
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            // Level Selector Chips
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

            // Placement Test Banner Card
            HiCard(
              backgroundColor: theme.colorScheme.primaryContainer.withAlpha(80),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: AppColors.limeGreen,
                    size: AppDimensions.iconLg,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Khảo sát năng lực đầu vào',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Kiểm tra thích ứng 6 kỹ năng để chọn lớp HSK',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  HiButton(
                    text: 'Làm bài',
                    size: HiButtonSize.sm,
                    variant: HiButtonVariant.primary,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PlacementTestIntroScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Adaptive Roadmap Banner Card
            HiCard(
              backgroundColor: AppColors.limeGreen.withAlpha(20),
              child: Row(
                children: [
                  const Icon(
                    Icons.map_rounded,
                    color: AppColors.limeGreen,
                    size: AppDimensions.iconLg,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lộ trình thích ứng cá nhân',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Đề xuất thông minh theo điểm thực tế & tiên quyết',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  HiButton(
                    text: 'Xem lộ trình',
                    size: HiButtonSize.sm,
                    variant: HiButtonVariant.primary,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RoadmapScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Hanzi Writing Practice Banner Card
            HiCard(
              backgroundColor: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
              child: Row(
                children: [
                  const Icon(
                    Icons.brush_rounded,
                    color: AppColors.limeGreen,
                    size: AppDimensions.iconLg,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Luyện viết chữ Hán',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tập vẽ nét bút thuận trên ô Mizige (米字格)',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  HiButton(
                    text: 'Luyện viết',
                    size: HiButtonSize.sm,
                    variant: HiButtonVariant.secondary,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const HanziWritingScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Pronunciation Lab & Shadowing Quick Access Row
            Row(
              children: [
                Expanded(
                  child: HiCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.record_voice_over_rounded,
                          color: AppColors.limeGreen,
                          size: 28,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Luyện phát âm',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Âm vị & Thanh điệu',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        HiButton(
                          text: 'Luyện âm',
                          size: HiButtonSize.sm,
                          variant: HiButtonVariant.secondary,
                          isFullWidth: true,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PronunciationLabScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: HiCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.speed_rounded,
                          color: Colors.blueAccent,
                          size: 28,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Shadowing',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Nói đuổi & Nhịp độ',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        HiButton(
                          text: 'Luyện nói',
                          size: HiButtonSize.sm,
                          variant: HiButtonVariant.secondary,
                          isFullWidth: true,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ShadowingScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Reading Comprehension & Smart Dictionary Quick Access Row
            Row(
              children: [
                Expanded(
                  child: HiCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.menu_book_rounded,
                          color: AppColors.limeGreen,
                          size: 28,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Luyện đọc hiểu',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Tương tác & Tra từ',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        HiButton(
                          text: 'Đọc hiểu',
                          size: HiButtonSize.sm,
                          variant: HiButtonVariant.secondary,
                          isFullWidth: true,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ReadingPassageListScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: HiCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.search_rounded,
                          color: Colors.amber,
                          size: 28,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Từ điển',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Tra cứu offline',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        HiButton(
                          text: 'Tra từ',
                          size: HiButtonSize.sm,
                          variant: HiButtonVariant.secondary,
                          isFullWidth: true,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const DictionaryScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),

            // Grammar Module Banner Card
            HiCard(
              backgroundColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_stories_rounded,
                    color: AppColors.limeGreen,
                    size: AppDimensions.iconLg,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ngữ pháp tiếng Hán',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Cấu trúc câu, ví dụ đối chiếu L1 & bài tập áp dụng',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  HiButton(
                    text: 'Học ngữ pháp',
                    size: HiButtonSize.sm,
                    variant: HiButtonVariant.primary,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const GrammarListScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Practice Engine Banner Card
            HiCard(
              backgroundColor: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
              child: Row(
                children: [
                  const Icon(
                    Icons.quiz_rounded,
                    color: Colors.deepPurpleAccent,
                    size: AppDimensions.iconLg,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Luyện tập tương tác (Practice Engine)',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '7 dạng bài tập chuẩn mực: trắc nghiệm, ghép cặp, điền từ...',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  HiButton(
                    text: 'Luyện tập',
                    size: HiButtonSize.sm,
                    variant: HiButtonVariant.primary,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PracticeSessionScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Listening Comprehension Banner Card
            HiCard(
              backgroundColor: AppColors.limeGreen.withAlpha(20),
              child: Row(
                children: [
                  const Icon(
                    Icons.headphones_rounded,
                    color: AppColors.limeGreen,
                    size: AppDimensions.iconLg,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Luyện nghe hiểu hội thoại',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hội thoại chuẩn người bản xứ, tùy chỉnh tốc độ và câu hỏi hiểu',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  HiButton(
                    text: 'Nghe ngay',
                    size: HiButtonSize.sm,
                    variant: HiButtonVariant.primary,
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ListeningScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Unit 1
            Text(
              'Chương 1: Khởi Đầu & Phát Âm Cơ Bản',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildLessonCard(
              unitNumber: 1,
              title: 'Thanh điệu và phát âm Pinyin',
              annotatedSnippet: '汉语[hànyǔ]，拼音[pīnyīn]',
              vocabCount: 15,
              status: HiChipStatus.success,
              statusText: 'Đã hoàn thành',
              progress: 1.0,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildLessonCard(
              unitNumber: 2,
              title: 'Chào hỏi và Lời cảm ơn',
              annotatedSnippet: '你好[nǐ hǎo]，谢谢[xièxie]！',
              vocabCount: 12,
              status: HiChipStatus.warning,
              statusText: 'Đang học (60%)',
              progress: 0.6,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildLessonCard(
              unitNumber: 3,
              title: 'Gia đình và Con số',
              annotatedSnippet: '爸爸[bàba]，妈妈[māma]',
              vocabCount: 20,
              status: HiChipStatus.neutral,
              statusText: 'Chưa mở khóa',
              progress: 0.0,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Unit 2
            Text(
              'Chương 2: Đời Sống Hàng Ngày',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _buildLessonCard(
              unitNumber: 4,
              title: 'Ăn uống và Gọi món tại nhà hàng',
              annotatedSnippet: '米饭[mǐfàn]，吃[chī]面条[miàntiáo]',
              vocabCount: 18,
              status: HiChipStatus.neutral,
              statusText: 'Chưa mở khóa',
              progress: 0.0,
            ),
            const SizedBox(height: AppSpacing.huge),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonCard({
    required int unitNumber,
    required String title,
    required String annotatedSnippet,
    required int vocabCount,
    required HiChipStatus status,
    required String statusText,
    required double progress,
  }) {
    final theme = Theme.of(context);

    return HiCard(
      onTap: () {
        HiSnackBar.showInfo(context, 'Mở bài học $unitNumber: $title');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bài $unitNumber',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
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
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          RubyText.fromAnnotatedString(
            annotatedText: annotatedSnippet,
            showPinyin: true,
          ),
          const SizedBox(height: AppSpacing.md),
          HiLinearProgress(value: progress),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$vocabCount từ vựng',
                style: theme.textTheme.bodySmall,
              ),
              Text(
                '${(progress * 100).toInt()}%',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
