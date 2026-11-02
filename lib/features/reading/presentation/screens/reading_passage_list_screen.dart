import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/theme.dart';
import '../../data/reading_repository.dart';
import '../../domain/models/reading_models.dart';
import 'reading_detail_screen.dart';

/// Screen displaying the list of interactive reading passages with HSK filtering,
/// topic categorization, estimated time, and reading progress indicators.
class ReadingPassageListScreen extends StatefulWidget {
  final ReadingRepository? repository;
  const ReadingPassageListScreen({super.key, this.repository});

  @override
  State<ReadingPassageListScreen> createState() => _ReadingPassageListScreenState();
}

class _ReadingPassageListScreenState extends State<ReadingPassageListScreen> {
  late final ReadingRepository _repo;
  int? _selectedHskLevel;
  String? _selectedTopic;

  List<ReadingPassage> _passages = [];
  Map<String, ReadingProgress> _progressMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DefaultReadingRepository(AppDatabase.instance.database);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final passages = await _repo.getPassages(hskLevel: _selectedHskLevel);

    final map = <String, ReadingProgress>{};
    for (final p in passages) {
      final prog = await _repo.getProgress(p.id);
      if (prog != null) {
        map[p.id] = prog;
      }
    }

    if (mounted) {
      setState(() {
        _passages = passages;
        _progressMap = map;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredPassages = _passages.where((p) {
      if (_selectedTopic != null && p.topic != _selectedTopic) return false;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện Đọc Hiểu Tương Tác'),
      ),
      body: Column(
        children: [
          // Filter Chips Row (HSK Levels)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Tất cả cấp độ'),
                  selected: _selectedHskLevel == null,
                  onSelected: (_) {
                    setState(() => _selectedHskLevel = null);
                    _loadData();
                  },
                ),
                const SizedBox(width: AppSpacing.xs),
                ...[1, 2, 3, 4, 5].map((lvl) {
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: FilterChip(
                      label: Text('HSK $lvl'),
                      selected: _selectedHskLevel == lvl,
                      onSelected: (_) {
                        setState(() => _selectedHskLevel = lvl);
                        _loadData();
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1),

          // Passage List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredPassages.isEmpty
                    ? Center(
                        child: Text(
                          'Không có bài đọc nào cho bộ lọc này.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.separated(
                          padding: AppSpacing.screenPadding,
                          itemCount: filteredPassages.length,
                          separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                          itemBuilder: (context, index) {
                            final passage = filteredPassages[index];
                            final progress = _progressMap[passage.id];

                            return HiCard(
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ReadingDetailScreen(
                                      passage: passage,
                                      repository: _repo,
                                    ),
                                  ),
                                );
                                _loadData();
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryBlueDark.withAlpha(isDark ? 60 : 35),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'HSK ${passage.hskLevel}',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? AppColors.primaryBlueDark : AppColors.primaryBlueDark,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Text(
                                        passage.topic,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      const Spacer(),

                                      // Progress Indicator Badge
                                      if (progress != null && progress.isCompleted)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withAlpha(isDark ? 60 : 35),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Đã hoàn thành ${progress.score != null ? "(${progress.score!.toStringAsFixed(0)}%)" : ""}',
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: Colors.green,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        )
                                      else if (progress != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.withAlpha(isDark ? 60 : 35),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            'Đang đọc dở (${progress.readingTimeSeconds}s)',
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.sm),

                                  // Passage Title
                                  Text(
                                    passage.titleCn,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),

                                  // Snippet
                                  Text(
                                    passage.translationVi,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),

                                  // Bottom Meta Row: word count & questions count
                                  Row(
                                    children: [
                                      const Icon(Icons.menu_book_rounded, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${passage.wordCount} chữ Hán',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      const Icon(Icons.quiz_outlined, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${passage.questions.length} câu hỏi',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Bắt đầu đọc',
                                        style: theme.textTheme.labelMedium?.copyWith(
                                          color: isDark ? AppColors.primaryBlueDark : theme.colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 2),
                                      Icon(
                                        Icons.arrow_forward_ios_rounded,
                                        size: 12,
                                        color: isDark ? AppColors.primaryBlueDark : theme.colorScheme.primary,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
