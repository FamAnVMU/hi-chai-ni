import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/theme.dart';
import '../../data/dictionary_repository.dart';
import '../../domain/models/dictionary_models.dart';
import '../widgets/dictionary_detail_sheet.dart';

/// Full-screen Smart Offline Dictionary:
/// Multi-mode search (Hanzi, Pinyin, Vietnamese meaning),
/// Saved words with notes, and search history.
class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  late final DictionaryRepository _repository;

  List<DictionaryEntry> _searchResults = [];
  bool _isSearching = false;
  String _currentQuery = '';

  List<UserSavedWord> _savedWords = [];
  bool _isLoadingSaved = false;

  List<DictionaryHistoryItem> _historyItems = [];
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _repository = DefaultDictionaryRepository(AppDatabase.instance.database);

    _tabController.addListener(() {
      if (_tabController.index == 1) {
        _loadSavedWords();
      } else if (_tabController.index == 2) {
        _loadHistory();
      }
    });

    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
        _currentQuery = '';
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _currentQuery = trimmed;
    });

    try {
      final list = await _repository.search(trimmed, limit: 30);
      if (mounted) {
        setState(() {
          _searchResults = list;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  Future<void> _loadSavedWords() async {
    setState(() => _isLoadingSaved = true);
    final words = await _repository.getSavedWords();
    if (mounted) {
      setState(() {
        _savedWords = words;
        _isLoadingSaved = false;
      });
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoadingHistory = true);
    final history = await _repository.getRecentSearches();
    if (mounted) {
      setState(() {
        _historyItems = history;
        _isLoadingHistory = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Từ Điển Thông Minh'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.limeGreen,
          labelColor: isDark ? AppColors.limeGreen : theme.colorScheme.primary,
          tabs: const [
            Tab(text: 'Tra cứu', icon: Icon(Icons.search_rounded)),
            Tab(text: 'Đã lưu', icon: Icon(Icons.bookmark_rounded)),
            Tab(text: 'Lịch sử', icon: Icon(Icons.history_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 0: Search Tab
          _buildSearchTab(theme, isDark),

          // Tab 1: Saved Words Tab
          _buildSavedWordsTab(theme, isDark),

          // Tab 2: History Tab
          _buildHistoryTab(theme, isDark),
        ],
      ),
    );
  }

  Widget _buildSearchTab(ThemeData theme, bool isDark) {
    return Column(
      children: [
        // Search Input Field
        Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Nhập chữ Hán, Pinyin (ni3 hao3 / nihao), nghĩa tiếng Việt...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch('');
                      },
                    )
                  : null,
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (val) => _performSearch(val),
            onSubmitted: (val) => _performSearch(val),
          ),
        ),

        // Body: Suggestions or Results
        Expanded(
          child: _isSearching
              ? const Center(child: CircularProgressIndicator())
              : _searchResults.isEmpty && _currentQuery.isNotEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(120),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Không tìm thấy từ vựng cho "$_currentQuery"',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _searchResults.isEmpty
                      ? _buildSearchQuickSuggestions(theme)
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          itemCount: _searchResults.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final entry = _searchResults[index];
                            final primarySense = entry.senses.isNotEmpty ? entry.senses.first : null;

                            return ListTile(
                              title: Row(
                                children: [
                                  Text(
                                    entry.simplified,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppColors.limeGreen : theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    entry.pinyin,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.limeGreen.withAlpha(isDark ? 60 : 35),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'HSK ${entry.hskLevel}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppColors.limeGreen : const Color(0xFF2E5B0E),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: primarySense != null
                                  ? Text(
                                      '${primarySense.partOfSpeech}: ${primarySense.meaningVi}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                DictionaryDetailSheet.show(
                                  context,
                                  entry: entry,
                                  repository: _repository,
                                );
                              },
                            );
                          },
                        ),
        ),
      ],
    );
  }

  Widget _buildSearchQuickSuggestions(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          'Gợi Ý Tra Cứu Nhanh',
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: ['你好', '朋友', '学习', '中国', '看书', '谢谢', '高兴', '喜欢'].map((w) {
            return ActionChip(
              label: Text(w),
              onPressed: () {
                _searchController.text = w;
                _performSearch(w);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        if (_historyItems.isNotEmpty) ...[
          Text(
            'Lịch Sử Gần Đây',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: _historyItems.take(6).map((h) {
              return ActionChip(
                avatar: const Icon(Icons.history_rounded, size: 14),
                label: Text(h.query),
                onPressed: () {
                  _searchController.text = h.query;
                  _performSearch(h.query);
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildSavedWordsTab(ThemeData theme, bool isDark) {
    if (_isLoadingSaved) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_savedWords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_outline_rounded,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant.withAlpha(120),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Chưa có từ vựng nào được lưu.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Nhấn biểu tượng bookmark khi xem chi tiết để lưu từ.',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadSavedWords,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _savedWords.length,
        separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) {
          final word = _savedWords[index];
          return HiCard(
            child: ListTile(
              title: Row(
                children: [
                  Text(
                    word.simplified,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.limeGreen : theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    word.pinyin,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              subtitle: word.customNote != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Ghi chú: ${word.customNote!}',
                        style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                      ),
                    )
                  : null,
              trailing: IconButton(
                icon: const Icon(Icons.bookmark_rounded, color: Colors.amber),
                onPressed: () async {
                  final entry = await _repository.getWordById(word.vocabularyId);
                  if (entry != null) {
                    await _repository.toggleSaveWord(entry);
                    _loadSavedWords();
                  }
                },
              ),
              onTap: () async {
                final entry = await _repository.getWordById(word.vocabularyId);
                if (entry != null && context.mounted) {
                  DictionaryDetailSheet.show(
                    context,
                    entry: entry,
                    repository: _repository,
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildHistoryTab(ThemeData theme, bool isDark) {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_historyItems.isEmpty) {
      return Center(
        child: Text(
          'Chưa có lịch sử tra cứu.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_historyItems.length} lần tra cứu gần nhất',
                style: theme.textTheme.labelMedium,
              ),
              TextButton.icon(
                icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                label: const Text('Xóa hết'),
                onPressed: () async {
                  await _repository.clearSearchHistory();
                  _loadHistory();
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            itemCount: _historyItems.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _historyItems[index];
              return ListTile(
                leading: const Icon(Icons.history_rounded),
                title: Text(item.query),
                subtitle: Text('Kiểu tra: ${item.searchType}'),
                onTap: () {
                  _tabController.animateTo(0);
                  _searchController.text = item.query;
                  _performSearch(item.query);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
