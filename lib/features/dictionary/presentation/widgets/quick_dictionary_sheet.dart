import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/theme.dart';
import '../../data/dictionary_repository.dart';
import '../../domain/models/dictionary_models.dart';
import 'dictionary_detail_sheet.dart';

/// Interactive modal bottom sheet for instant offline dictionary lookup.
class QuickDictionarySheet extends StatefulWidget {
  final String? initialWord;
  final DictionaryRepository? repository;
  const QuickDictionarySheet({super.key, this.initialWord, this.repository});

  static Future<void> show(BuildContext context, {String? initialWord, DictionaryRepository? repository}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickDictionarySheet(initialWord: initialWord, repository: repository),
    );
  }

  @override
  State<QuickDictionarySheet> createState() => _QuickDictionarySheetState();
}

class _QuickDictionarySheetState extends State<QuickDictionarySheet> {
  final TextEditingController _searchController = TextEditingController();
  List<DictionaryEntry> _results = [];
  bool _isLoading = false;
  String _searchedKeyword = '';
  DictionaryRepository? _repository;

  @override
  void initState() {
    super.initState();
    try {
      _repository = widget.repository ?? DefaultDictionaryRepository(AppDatabase.instance.database);
    } catch (_) {
      _repository = null;
    }
    final word = widget.initialWord?.trim();
    if (word != null && word.isNotEmpty) {
      _searchController.text = word;
      _performSearch(word);
    } else {
      _performSearch('你好'); // Pre-populate with common greeting as sample
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (mounted) {
        setState(() {
          _results = [];
          _searchedKeyword = '';
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _searchedKeyword = trimmed;
    });

    try {
      if (_repository != null) {
        final entries = await _repository!.search(trimmed, limit: 25);
        if (mounted) {
          setState(() {
            _results = entries;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _results = [];
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(80),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Title & Close Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.primaryBlueDark,
                        size: AppDimensions.iconMd,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Tra Cứu Từ Điển Nhanh',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Search Bar Input
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
              child: TextField(
                controller: _searchController,
                autofocus: widget.initialWord == null,
                decoration: InputDecoration(
                  hintText: 'Nhập chữ Hán, Pinyin hoặc nghĩa tiếng Việt...',
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                ),
                onChanged: (val) => _performSearch(val),
                onSubmitted: (val) => _performSearch(val),
              ),
            ),

            const SizedBox(height: AppSpacing.xs),

            // Results List
            Flexible(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.xl),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _results.isEmpty && _searchedKeyword.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
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
                                'Không tìm thấy kết quả phù hợp cho "$_searchedKeyword"',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                'Thử tìm với pinyin không dấu hoặc nghĩa tiếng Việt.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                          itemCount: _results.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _results[index];
                            final primarySense = item.senses.isNotEmpty ? item.senses.first : null;

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              title: Row(
                                children: [
                                  Text(
                                    item.simplified,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? AppColors.primaryBlueDark : theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Text(
                                    item.pinyin,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryBlueDark.withAlpha(isDark ? 60 : 35),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'HSK ${item.hskLevel}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? AppColors.primaryBlueDark : AppColors.primaryBlueDark,
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
                                if (_repository != null) {
                                  DictionaryDetailSheet.show(
                                    context,
                                    entry: item,
                                    repository: _repository!,
                                  );
                                }
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
}
