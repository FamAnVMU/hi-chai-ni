import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';

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
