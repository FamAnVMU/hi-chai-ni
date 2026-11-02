import '../../../curriculum/presentation/screens/curriculum_syllabus_screen.dart';
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
import '../../../content_packs/presentation/screens/content_pack_manager_screen.dart';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.download_for_offline_outlined),
            tooltip: 'Kho học liệu HSK',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const ContentPackManagerScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            // Official HSK 1 Curriculum Banner Card
            HiCard(
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
                          'Giáo Trình HSK 1 Chuẩn',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlueDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '15 bài học liên hoàn • 150 từ vựng • 45 ngữ pháp',
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
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CurriculumSyllabusScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

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

            // Placement Test Card
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

            // Adaptive Roadmap Card
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

            // Hanzi Writing Practice Card
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

            // Pronunciation Lab & Shadowing Quick Access Row
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

            // Reading Comprehension & Smart Dictionary Quick Access Row
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

            // Grammar Module Banner Card
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

            // Practice Engine Banner Card
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

            // Listening Comprehension Banner Card
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

            // Unit 1
            Text(
              'Chương 1: Khởi Đầu & Phát Âm Cơ Bản',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
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
                color: AppColors.primaryText,
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
      padding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: AppColors.cardBackground,
      borderColor: AppColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
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
      backgroundColor: AppColors.cardBackground,
      borderColor: AppColors.border,
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
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
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
