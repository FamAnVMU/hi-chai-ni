import 'package:flutter/material.dart';
import '../../data/hanzi_repository.dart';
import '../../domain/models/hanzi_models.dart';
import 'hanzi_writing_screen.dart';

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

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedHskLevel = widget.initialHskLevel;
    _loadCharacters();
  }

  @override
  void dispose() {
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
    setState(() {
      _searchQuery = val;
    });
    _loadCharacters();
  }

  void _openWritingScreen(HanziCharacter c) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HanziWritingScreen(
          initialCharacter: c.character,
          repository: widget.repository,
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
                fillColor: Colors.grey.shade100,
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
                          style: const TextStyle(color: Colors.grey),
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
    return InkWell(
      onTap: () => _openWritingScreen(c),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: p?.masteryLevel == 'mastered'
                ? Colors.green.shade300
                : (p?.mistakesCount != null && p!.mistakesCount > 0
                    ? Colors.orange.shade300
                    : Colors.grey.shade200),
            width: p != null ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Character Glyph
            Text(
              c.character,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            // Pinyin
            Text(
              c.pinyin,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
            ),
            if (c.hanviet.isNotEmpty)
              Text(
                c.hanviet,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
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
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                if (p != null && p.practiceCount + p.testCount > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: p.bestAccuracyScore >= 80 ? Colors.green.shade50 : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${p.bestAccuracyScore.toInt()}%',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: p.bestAccuracyScore >= 80 ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
