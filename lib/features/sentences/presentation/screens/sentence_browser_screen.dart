import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/audio_pack_manager.dart';
import '../../data/sentence_dao.dart';
import '../../data/sentence_repository.dart';
import '../../domain/models/sentence_models.dart';
import 'audio_pack_manager_screen.dart';
import 'sentence_listening_screen.dart';
import 'sentence_reading_screen.dart';
import 'sentence_shadowing_screen.dart';

/// Screen for browsing, searching, and practicing Chinese sentences across HSK 1–6
class SentenceBrowserScreen extends StatefulWidget {
  final SentenceRepository repository;
  final SentenceDao dao;
  final int initialHskLevel;

  const SentenceBrowserScreen({
    super.key,
    required this.repository,
    required this.dao,
    this.initialHskLevel = 1,
  });

  @override
  State<SentenceBrowserScreen> createState() => _SentenceBrowserScreenState();
}

class _SentenceBrowserScreenState extends State<SentenceBrowserScreen> {
  late int _selectedHskLevel;
  bool _humanAudioOnly = false;
  bool _filterReviewOnly = false;
  String _searchQuery = '';
  List<SentenceItem> _sentences = [];
  Map<String, SentencePracticeProgress> _progressMap = {};
  bool _isLoading = true;
  Timer? _debounceTimer;

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedHskLevel = widget.initialHskLevel;
    _loadSentences();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSentences() async {
    setState(() => _isLoading = true);

    List<SentenceItem> list;
    if (_searchQuery.isNotEmpty) {
      list = await widget.repository.searchSentences(_searchQuery);
    } else if (_filterReviewOnly) {
      final reviews = await widget.repository.getSentencesNeedingReview();
      final sentenceIds = reviews.map((r) => r.sentenceId).toList();
      list = await widget.repository.getSentencesByIds(sentenceIds);
    } else {
      list = await widget.repository.getSentencesByHskLevel(
        _selectedHskLevel,
        limit: 100,
        humanAudioOnly: _humanAudioOnly,
      );
    }

    final sentenceIds = list.map((s) => s.id).toList();
    final progMap = await widget.repository.getProgressForSentences(sentenceIds);

    if (mounted) {
      setState(() {
        _sentences = list;
        _progressMap = progMap;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _searchQuery = val.trim());
        _loadSentences();
      }
    });
  }

  void _openListening(SentenceItem s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SentenceListeningScreen(
          sentence: s,
          sentenceList: _sentences,
          repository: widget.repository,
        ),
      ),
    ).then((_) => _loadSentences());
  }

  void _openShadowing(SentenceItem s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SentenceShadowingScreen(
          sentence: s,
          repository: widget.repository,
        ),
      ),
    ).then((_) => _loadSentences());
  }

  void _openReading(SentenceItem s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SentenceReadingScreen(
          sentence: s,
          repository: widget.repository,
        ),
      ),
    ).then((_) => _loadSentences());
  }

  void _openAudioPackManager() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AudioPackManagerScreen(
          packManager: AudioPackManager(widget.dao),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kho Câu & Luyện Nghe'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.cloud_download_outlined),
            tooltip: 'Quản lý gói âm thanh ngoại tuyến',
            onPressed: _openAudioPackManager,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Tìm câu theo chữ Hán, Pinyin, nghĩa...',
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              onChanged: _onSearchChanged,
            ),
          ),

          // Filters row
          if (_searchQuery.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    FilterChip(
                      label: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.record_voice_over, size: 16),
                          SizedBox(width: 4),
                          Text('Giọng người thật'),
                        ],
                      ),
                      selected: _humanAudioOnly,
                      onSelected: (val) {
                        setState(() => _humanAudioOnly = val);
                        _loadSentences();
                      },
                    ),
                    const SizedBox(width: 8),
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
                        setState(() => _filterReviewOnly = val);
                        _loadSentences();
                      },
                    ),
                    const SizedBox(width: 8),
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
                              _loadSentences();
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),

          const Divider(height: 1),

          // Sentence List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sentences.isEmpty
                    ? const Center(child: Text('Không tìm thấy câu ví dụ phù hợp.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sentences.length,
                        itemBuilder: (ctx, idx) {
                          final s = _sentences[idx];
                          final p = _progressMap[s.id];
                          return _buildSentenceCard(s, p);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSentenceCard(SentenceItem s, SentencePracticeProgress? p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: p?.masteryLevel == 'mastered' ? Colors.green.shade300 : Colors.grey.shade200,
          width: p?.masteryLevel == 'mastered' ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(5), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Level badge & Audio source badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'HSK ${s.hskLevel}',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue.shade700),
                ),
              ),
              () {
                final isStudioTts = s.contributor.toLowerCase().contains('edge_tts') ||
                    s.contributor.toLowerCase().contains('xiaoxiao') ||
                    s.audios.any((a) => a.audioType == AudioType.studioSimulation);

                if (isStudioTts) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.graphic_eq_rounded, size: 13, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'AI Studio (Edge TTS)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade800),
                        ),
                      ],
                    ),
                  );
                } else if (s.hasHumanAudio) {
                  final speaker = s.contributor.isNotEmpty && !s.contributor.toLowerCase().contains('edge')
                      ? s.contributor
                      : 'Tatoeba';
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.record_voice_over, size: 13, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Người thật ($speaker)',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                        ),
                      ],
                    ),
                  );
                } else {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.smart_toy_outlined, size: 13, color: Colors.grey),
                        SizedBox(width: 4),
                        Text(
                          'Giọng OS TTS',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
              }(),
            ],
          ),

          const SizedBox(height: 8),

          // Chinese Text
          Text(
            s.chinese,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),

          // Pinyin
          Text(
            s.pinyin,
            style: const TextStyle(fontSize: 13, color: Color(0xFF2563EB), fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),

          // Translation
          Text(
            s.translationVi.isNotEmpty ? s.translationVi : s.translationEn,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Action buttons row: Luyện nghe, Shadowing, Luyện đọc
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.headphones, size: 18),
                label: const Text('Luyện nghe', style: TextStyle(fontSize: 12)),
                onPressed: () => _openListening(s),
              ),
              TextButton.icon(
                icon: const Icon(Icons.mic, size: 18),
                label: const Text('Shadowing', style: TextStyle(fontSize: 12)),
                onPressed: () => _openShadowing(s),
              ),
              TextButton.icon(
                icon: const Icon(Icons.menu_book, size: 18),
                label: const Text('Luyện đọc', style: TextStyle(fontSize: 12)),
                onPressed: () => _openReading(s),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
