import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../hanzi_writing/presentation/screens/hanzi_writing_screen.dart';
import '../../data/hanzi_repository.dart';
import '../../domain/models/hanzi_models.dart';

/// Screen for browsing, searching, and practicing Chinese characters across HSK 1–6
class HanziCharacterListScreen extends StatefulWidget {
  final HanziRepository repository;
  final int initialHskLevel;

  const HanziCharacterListScreen({
    super.key,
    required this.repository,
    this.initialHskLevel = 1,
  });

  @override
  State<HanziCharacterListScreen> createState() => _HanziCharacterListScreenState();
}

class _HanziCharacterListScreenState extends State<HanziCharacterListScreen> {
  late int _selectedHskLevel;
  bool _filterReviewOnly = false;
  String _searchQuery = '';
  List<HanziCharacter> _characters = [];
  Map<String, HanziWritingProgress> _progressMap = {};
  bool _isLoading = true;
  Timer? _debounceTimer;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedHskLevel = widget.initialHskLevel;
    _loadCharacters();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCharacters() async {
    setState(() {
      _isLoading = true;
    });

    List<HanziCharacter> chars;
    if (_searchQuery.isNotEmpty) {
      chars = await widget.repository.searchCharacters(_searchQuery);
    } else if (_filterReviewOnly) {
      final reviews = await widget.repository.getCharactersNeedingReview();
      final glyphs = reviews.map((r) => r.character).toList();
      chars = await widget.repository.getCharactersByGlyphs(glyphs);
    } else {
      chars = await widget.repository.getCharactersByHskLevel(_selectedHskLevel, limit: 300);
    }

    final charGlyphs = chars.map((c) => c.character).toList();
    final map = await widget.repository.getProgressForCharacters(charGlyphs);

    if (mounted) {
      setState(() {
        _characters = chars;
        _progressMap = map;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _searchQuery = val.trim();
        });
        _loadCharacters();
      }
    });
  }

  void _openWritingScreen(HanziCharacter c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HanziWritingScreen(
          initialCharacter: c.character,
        ),
      ),
    ).then((_) => _loadCharacters());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kho chữ Hán & Luyện viết'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm chữ Hán, Pinyin, Hán-Việt...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: context.hiInputSurface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // HSK Level Tabs & Filter
          if (_searchQuery.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Review filter
                    FilterChip(
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history, size: 16),
                          SizedBox(width: 4),
                          Text('Cần ôn tập'),
                        ],
                      ),
                      selected: _filterReviewOnly,
                      onSelected: (val) {
                        setState(() {
                          _filterReviewOnly = val;
                        });
                        _loadCharacters();
                      },
                    ),
                    const SizedBox(width: 8),
                    // HSK 1-6
                    for (int lvl = 1; lvl <= 6; lvl++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('HSK $lvl'),
                          selected: !_filterReviewOnly && _selectedHskLevel == lvl,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _filterReviewOnly = false;
                                _selectedHskLevel = lvl;
                              });
                              _loadCharacters();
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),

          const Divider(height: 1),

          // Character Grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _characters.isEmpty
                    ? Center(
                        child: Text(
                          _filterReviewOnly
                              ? 'Chưa có chữ nào cần ôn tập hôm nay!'
                              : 'Không tìm thấy chữ Hán nào phù hợp.',
                          style: TextStyle(color: context.hiSecondaryText),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _characters.length,
                        itemBuilder: (ctx, idx) {
                          final c = _characters[idx];
                          final p = _progressMap[c.character];
                          return _buildCharacterCard(c, p);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCharacterCard(HanziCharacter c, HanziWritingProgress? p) {
    final borderColor = p?.masteryLevel == 'mastered'
        ? context.hiSuccessFg.withAlpha(140)
        : (p?.mistakesCount != null && p!.mistakesCount > 0
            ? context.hiWarningFg.withAlpha(140)
            : context.hiBorderColor);

    return Semantics(
      button: true,
      label:
          'Chữ ${c.character}, ${c.pinyin}${c.hanviet.isNotEmpty ? ', âm Hán-Việt ${c.hanviet}' : ''}, ${c.strokeCount} nét',
      child: InkWell(
        onTap: () => _openWritingScreen(c),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: context.hiCardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor,
              width: p != null ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(context.isDarkMode ? 24 : 5),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Character Glyph
                Text(
                  c.character,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: context.hiPrimaryText,
                  ),
                ),
                const SizedBox(height: 2),
                // Pinyin
                Text(
                  c.pinyin,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: context.hiAccentColor,
                  ),
                ),
                if (c.hanviet.isNotEmpty)
                  Text(
                    c.hanviet,
                    style: TextStyle(fontSize: 11, color: context.hiSecondaryText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 4),
                // Badges row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${c.strokeCount} nét',
                      style: TextStyle(fontSize: 10, color: context.hiSecondaryText),
                    ),
                    if (p != null && p.practiceCount + p.testCount > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: p.bestAccuracyScore >= 80
                              ? context.hiSuccessBg
                              : context.hiWarningBg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${p.bestAccuracyScore.toInt()}%',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: p.bestAccuracyScore >= 80
                                ? context.hiSuccessFg
                                : context.hiWarningFg,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
