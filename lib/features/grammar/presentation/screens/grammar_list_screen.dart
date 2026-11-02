import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/grammar_models.dart';
import '../providers/grammar_providers.dart';
import 'grammar_detail_screen.dart';

/// Screen listing Chinese grammar points with HSK filtering, tag chips, and search.
class GrammarListScreen extends ConsumerWidget {
  const GrammarListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final grammarListAsync = ref.watch(grammarListProvider);
    final progressMapAsync = ref.watch(grammarProgressMapProvider);
    final selectedHsk = ref.watch(selectedGrammarHskProvider);
    final selectedTag = ref.watch(selectedGrammarTagProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ngữ Pháp Tiếng Hán'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar & Filter Chips
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  HiTextField(
                    hintText: 'Tìm điểm ngữ pháp, cấu trúc (把, 比, 是...)...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    onChanged: (q) => ref.read(grammarSearchQueryProvider.notifier).setQuery(q),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // HSK Level Filters
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
                        ...[1, 2, 3, 4, 5].map((lvl) {
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
                  const SizedBox(height: AppSpacing.xs),

                  // Popular Tag Filters
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: HiChip(
                            label: 'Tất cả chủ đề',
                            isSelected: selectedTag == null,
                            onTap: () => ref.read(selectedGrammarTagProvider.notifier).selectTag(null),
                          ),
                        ),
                        ...['câu_phán_đoán', 'câu_hỏi', 'giới_từ_địa_điểm', 'câu_so_sánh', 'câu_chữ_bả'].map((t) {
                          return Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.xs),
                            child: HiChip(
                              label: '#$t',
                              isSelected: selectedTag == t,
                              onTap: () => ref.read(selectedGrammarTagProvider.notifier).selectTag(t),
                            ),
                          );
                        }),
                      ],
                    ),
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
                      child: Text(
                        'Không tìm thấy điểm ngữ pháp phù hợp.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
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
                      color: AppColors.primaryBlueLight,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      'HSK ${item.hskLevel}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primaryBlueDark,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      item.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                  Icon(statusIcon, color: statusColor, size: 18),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                item.structure,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryBlueDark,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.meaningVi,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
