import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/grammar_models.dart';
import '../providers/grammar_providers.dart';
import 'grammar_detail_screen.dart';

/// Screen listing Chinese grammar points with dual-mode HSK level & topic filtering,
/// real-time search, and learner mastery progress status.
class GrammarListScreen extends ConsumerWidget {
  const GrammarListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final grammarListAsync = ref.watch(grammarListProvider);
    final progressMapAsync = ref.watch(grammarProgressMapProvider);
    final selectedHsk = ref.watch(selectedGrammarHskProvider);
    final selectedTopic = ref.watch(selectedGrammarTopicProvider);
    final topicsAsync = ref.watch(grammarTopicsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ngữ Pháp Tiếng Hán'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: AppColors.border, height: 1.0),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar & Filter Section
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HiTextField(
                    hintText: 'Tìm ngữ pháp (把, 比, 了, 着, 在, vì sao...)...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    onChanged: (q) => ref.read(grammarSearchQueryProvider.notifier).setQuery(q),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // 1. HSK Level Filters (HSK 1 to 6)
                  Text(
                    'Phân cấp theo trình độ (HSK 1–6):',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: HiChip(
                            label: 'Tất cả HSK',
                            isSelected: selectedHsk == null,
                            onTap: () => ref.read(selectedGrammarHskProvider.notifier).selectLevel(null),
                          ),
                        ),
                        ...[1, 2, 3, 4, 5, 6].map((lvl) {
                          return Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.xs),
                            child: HiChip(
                              label: 'HSK $lvl',
                              isSelected: selectedHsk == lvl,
                              onTap: () => ref.read(selectedGrammarHskProvider.notifier).selectLevel(lvl),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // 2. Grammatical Topic Filters
                  Text(
                    'Phân loại theo chủ đề ngữ pháp:',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  topicsAsync.when(
                    loading: () => const SizedBox(height: 32, child: Center(child: LinearProgressIndicator())),
                    error: (e, s) => const SizedBox.shrink(),
                    data: (topics) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: AppSpacing.xs),
                              child: HiChip(
                                label: 'Tất cả chủ đề',
                                isSelected: selectedTopic == null,
                                onTap: () => ref.read(selectedGrammarTopicProvider.notifier).selectTopic(null),
                              ),
                            ),
                            ...topics.map((top) {
                              final isSel = selectedTopic == top.code;
                              return Padding(
                                padding: const EdgeInsets.only(right: AppSpacing.xs),
                                child: HiChip(
                                  label: top.nameZh.isNotEmpty ? '${top.nameZh} ${top.nameVi.split(" ")[0]}' : top.nameVi,
                                  isSelected: isSel,
                                  onTap: () => ref.read(selectedGrammarTopicProvider.notifier).selectTopic(top.code),
                                ),
                              );
                            }),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Grammar Items List
            Expanded(
              child: grammarListAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Lỗi tải ngữ pháp: $err')),
                data: (items) {
                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off_rounded, size: 48, color: AppColors.mutedText),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Không tìm thấy điểm ngữ pháp phù hợp.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final progressMap = progressMapAsync.value ?? {};

                  return ListView.builder(
                    padding: AppSpacing.screenPadding,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final progress = progressMap[item.id];
                      return _buildGrammarListItem(context, item, progress);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrammarListItem(
    BuildContext context,
    GrammarItem item,
    GrammarProgress? progress,
  ) {
    final theme = Theme.of(context);
    final status = progress?.status ?? GrammarProgressStatus.unlearned;

    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case GrammarProgressStatus.mastered:
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle_rounded;
        break;
      case GrammarProgressStatus.learning:
        statusColor = AppColors.warning;
        statusIcon = Icons.timelapse_rounded;
        break;
      case GrammarProgressStatus.unlearned:
        statusColor = AppColors.mutedText;
        statusIcon = Icons.radio_button_unchecked_rounded;
        break;
    }

    final isGushi = item.source.contains('Gushi') || item.source.contains('HSK 3.0');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => GrammarDetailScreen(grammarId: item.id),
            ),
          );
        },
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isGushi
                          ? AppColors.primaryBlueLight
                          : AppColors.secondaryBackground,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      'HSK ${item.hskLevel}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isGushi ? AppColors.primaryBlueDark : AppColors.primaryText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  if (item.topicNameVi.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withAlpha(120),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        item.topicNameVi.split(' ')[0],
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Expanded(
                    child: Text(
                      item.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(statusIcon, color: statusColor, size: 18),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                item.structure,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlueDark,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.explanationVi.isNotEmpty ? item.explanationVi : item.meaningVi,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.verified_rounded, size: 12, color: AppColors.success),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.source,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.mutedText,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${item.examples.length} ví dụ',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.mutedText,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
