import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/dao/vocabulary_dao.dart';
import '../../../../core/theme/theme.dart';

/// Interactive modal bottom sheet for instant offline dictionary lookup.
class QuickDictionarySheet extends StatefulWidget {
  const QuickDictionarySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const QuickDictionarySheet(),
    );
  }

  @override
  State<QuickDictionarySheet> createState() => _QuickDictionarySheetState();
}

class _QuickDictionarySheetState extends State<QuickDictionarySheet> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  String _searchedKeyword = '';

  @override
  void initState() {
    super.initState();
    _performSearch('你好'); // Pre-populate with common greeting as sample
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
      final db = AppDatabase.instance.database;
      final dao = VocabularyDao(db);
      final list = await dao.searchVocabularies(trimmed, limit: 20);

      // Fetch senses for each result
      final fullResults = <Map<String, dynamic>>[];
      for (final item in list) {
        final id = item['id'] as String;
        final withSenses = await dao.getVocabularyWithSenses(id);
        if (withSenses != null) {
          fullResults.add(withSenses);
        } else {
          fullResults.add(item);
        }
      }

      if (mounted) {
        setState(() {
          _results = fullResults;
          _isLoading = false;
        });
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
    final mediaQuery = MediaQuery.of(context);

    return Container(
      height: mediaQuery.size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.sm),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header & Search Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.limeGreen,
                    size: AppDimensions.iconMd,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Tra Cứu Từ Điển Offline',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: HiTextField(
                controller: _searchController,
                hintText: 'Nhập chữ Hán, Pinyin (ví dụ: ni, hao, 你)...',
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
                onChanged: (val) => _performSearch(val),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Results List
            Expanded(
              child: _isLoading
                  ? const Center(child: HiLoadingIndicator(message: 'Đang tra cứu từ điển...'))
                  : _results.isEmpty
                      ? Center(
                          child: HiEmptyState(
                            title: _searchedKeyword.isEmpty
                                ? 'Nhập từ cần tra cứu'
                                : 'Không tìm thấy kết quả',
                            description: _searchedKeyword.isEmpty
                                ? 'Tra cứu tức thì hơn 1,200 từ vựng HSK hoàn toàn offline.'
                                : 'Không có từ nào khớp với "$_searchedKeyword". Hãy thử từ khác.',
                            icon: Icons.search_off_rounded,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          itemCount: _results.length,
                          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final item = _results[index];
                            final simplified = item['simplified'] as String? ?? '';
                            final pinyin = item['pinyin'] as String? ?? '';
                            final hsk = item['hsk_level'] as int? ?? 1;
                            final senses = item['senses'] as List<dynamic>? ?? [];
                            final firstSense = senses.isNotEmpty ? senses.first as Map<String, dynamic> : null;
                            final meaningVi = firstSense?['meaning_vi'] as String? ?? 'Nghĩa từ vựng';
                            final exampleCn = firstSense?['example_cn'] as String?;

                            return HiCard(
                              padding: const EdgeInsets.all(AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      RubyText(
                                        segments: [
                                          RubySegment(
                                            text: simplified,
                                            pinyin: pinyin,
                                          ),
                                        ],
                                        hanziStyle: theme.textTheme.headlineSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const Spacer(),
                                      HiChip(
                                        label: 'HSK $hsk',
                                        status: HiChipStatus.neutral,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    meaningVi,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (exampleCn != null && exampleCn.isNotEmpty) ...[
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      'Ví dụ: $exampleCn',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
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
