import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/audio/audio.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/theme/theme.dart';
import '../../data/reading_repository.dart';
import '../../domain/models/reading_models.dart';
import 'reading_detail_screen.dart';

/// Screen displaying the list of interactive reading passages with HSK filtering,
/// topic categorization, estimated time, and reading progress indicators.
class ReadingPassageListScreen extends StatefulWidget {
  final ReadingRepository? repository;
  final AudioPlayerService? audioPlayer;
  const ReadingPassageListScreen({super.key, this.repository, this.audioPlayer});

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

  AudioPlayerService? _audioPlayer;
  String? _playingAudioUri;
  bool _isPlaying = false;
  StreamSubscription<AudioPlaybackStatus>? _audioSub;

  static const List<String> _levelOptions = ['Tất cả', 'HSK 1', 'HSK 2', 'HSK 3', 'HSK 4+'];
  static const List<String> _topicOptions = [
    'Tất cả',
    'Đời sống',
    'Ẩm thực',
    'Du lịch',
    'Ngụ ngôn',
    'Văn hóa',
    'Khoa học',
  ];

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? DefaultReadingRepository(AppDatabase.instance.database);
    if (widget.audioPlayer != null) {
      _audioPlayer = widget.audioPlayer;
    }
    _loadData();
  }

  @override
  void dispose() {
    _audioSub?.cancel();
    _audioPlayer?.stop();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    // When HSK 4+ is selected, query without level constraint and filter in memory
    final hskQuery = (_selectedHskLevel != null && _selectedHskLevel! < 4) ? _selectedHskLevel : null;
    final passages = await _repo.getPassages(hskLevel: hskQuery);

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

  Future<void> _toggleAudio(ReadingPassage passage) async {
    final uri = passage.audioUri;
    if (uri == null || uri.isEmpty) return;

    if (_playingAudioUri == uri && _isPlaying) {
      await _audioPlayer?.pause();
      setState(() => _isPlaying = false);
    } else {
      _audioPlayer ??= widget.audioPlayer ?? DefaultAudioPlayerService();
      _audioSub ??= _audioPlayer?.statusStream.listen((status) {
        if (mounted) {
          setState(() {
            _isPlaying = status == AudioPlaybackStatus.playing;
          });
        }
      });
      await _audioPlayer?.play(uri);
      setState(() {
        _playingAudioUri = uri;
        _isPlaying = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final filteredPassages = _passages.where((p) {
      if (_selectedHskLevel != null) {
        if (_selectedHskLevel == 4) {
          if (p.hskLevel < 4) return false;
        } else {
          if (p.hskLevel != _selectedHskLevel) return false;
        }
      }
      if (_selectedTopic != null && _selectedTopic != 'Tất cả') {
        final pTopic = p.topic.toLowerCase();
        final sTopic = _selectedTopic!.toLowerCase();
        final matches = pTopic == sTopic ||
            pTopic.contains(sTopic) ||
            (sTopic.contains('ngụ ngôn') && pTopic.contains('ngụ ngôn'));
        if (!matches) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện Đọc Hiểu Tương Tác'),
      ),
      body: Column(
        children: [
          // Filter Bars (Level & Topic)
          Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: HSK Levels (Segmented Tabs)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
                  child: Row(
                    children: _levelOptions.map((levelLabel) {
                      int? targetLevel;
                      if (levelLabel == 'HSK 1') targetLevel = 1;
                      if (levelLabel == 'HSK 2') targetLevel = 2;
                      if (levelLabel == 'HSK 3') targetLevel = 3;
                      if (levelLabel == 'HSK 4+') targetLevel = 4;

                      final isSelected = (targetLevel == null && _selectedHskLevel == null) ||
                          (targetLevel != null && _selectedHskLevel == targetLevel);

                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: FilterChip(
                          label: Text(levelLabel),
                          selected: isSelected,
                          showCheckmark: false,
                          selectedColor: AppColors.primaryBlueDark,
                          labelStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : AppColors.primaryText,
                          ),
                          backgroundColor: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                          side: BorderSide(
                            color: isSelected ? AppColors.primaryBlueDark : AppColors.border,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          onSelected: (_) {
                            setState(() => _selectedHskLevel = targetLevel);
                            _loadData();
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 2),

                // Bottom Row: Topic Horizontal Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 2),
                  child: Row(
                    children: _topicOptions.map((topicLabel) {
                      final isSelected = (_selectedTopic == null && topicLabel == 'Tất cả') ||
                          (_selectedTopic == topicLabel);

                      return Padding(
                        padding: const EdgeInsets.only(right: AppSpacing.xs),
                        child: ActionChip(
                          label: Text(topicLabel),
                          backgroundColor: isSelected
                              ? AppColors.primaryBlueLight
                              : theme.colorScheme.surface,
                          side: BorderSide(
                            color: isSelected ? AppColors.primaryBlueDark : AppColors.border,
                            width: isSelected ? 1.5 : 1.0,
                          ),
                          labelStyle: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppColors.primaryBlueDark : AppColors.secondaryText,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          onPressed: () {
                            setState(() {
                              _selectedTopic = topicLabel == 'Tất cả' ? null : topicLabel;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),

          // Passage List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredPassages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_stories_outlined, size: 48, color: AppColors.mutedText),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'Không có bài đọc nào cho bộ lọc này.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
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
                            final isAudioPlaying = _isPlaying && _playingAudioUri == passage.audioUri;

                            return HiCard(
                              onTap: () async {
                                _audioPlayer?.stop();
                                setState(() => _isPlaying = false);
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
                                  // Top row: HSK Level Badge, Topic Chip, and Completion Status
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryBlueLight,
                                          borderRadius: BorderRadius.circular(AppRadius.xs),
                                          border: Border.all(color: AppColors.secondaryBlue),
                                        ),
                                        child: Text(
                                          'HSK ${passage.hskLevel}',
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryBlueDark,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                                          borderRadius: BorderRadius.circular(AppRadius.xs),
                                        ),
                                        child: Text(
                                          passage.topic,
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            color: AppColors.secondaryText,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const Spacer(),

                                      // Completion badge if completed
                                      if (progress != null && progress.isCompleted)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.successContainerLight,
                                            borderRadius: BorderRadius.circular(AppRadius.full),
                                            border: Border.all(color: AppColors.success.withAlpha(90)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.check_circle_rounded, size: 12, color: AppColors.success),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Đã đọc xong ${progress.score != null ? "(${progress.score!.toStringAsFixed(0)}%)" : ""}',
                                                style: theme.textTheme.labelSmall?.copyWith(
                                                  color: AppColors.success,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: AppSpacing.sm),

                                  // Bilingual Title: Chinese bold + Vietnamese translation below
                                  Text(
                                    passage.titleCn,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryText,
                                      fontSize: 17,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    passage.translationVi,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.secondaryText,
                                      height: 1.3,
                                    ),
                                  ),

                                  // In-progress Reading Progress Bar
                                  if (progress != null && !progress.isCompleted) ...[
                                    const SizedBox(height: AppSpacing.sm),
                                    _buildProgressBar(progress, passage, theme),
                                  ],

                                  const SizedBox(height: AppSpacing.md),
                                  const Divider(height: 1, color: AppColors.divider),
                                  const SizedBox(height: AppSpacing.sm),

                                  // Bottom Meta Row: Character Count, Estimated Time, Audio Button & Read CTA
                                  Row(
                                    children: [
                                      const Icon(Icons.text_fields_rounded, size: 14, color: AppColors.secondaryText),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${passage.wordCount} chữ Hán',
                                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondaryText),
                                      ),
                                      const SizedBox(width: AppSpacing.md),
                                      const Icon(Icons.schedule_rounded, size: 14, color: AppColors.secondaryText),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${passage.estimatedMinutes} phút',
                                        style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondaryText),
                                      ),
                                      const Spacer(),

                                      // Direct "Nghe bài đọc" button if audio file is available
                                      if (passage.audioUri != null && passage.audioUri!.isNotEmpty) ...[
                                        InkWell(
                                          onTap: () => _toggleAudio(passage),
                                          borderRadius: BorderRadius.circular(AppRadius.full),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: isAudioPlaying
                                                  ? AppColors.primaryBlueDark
                                                  : AppColors.primaryBlueLight,
                                              borderRadius: BorderRadius.circular(AppRadius.full),
                                              border: Border.all(color: AppColors.secondaryBlue),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  isAudioPlaying ? Icons.pause_rounded : Icons.headphones_rounded,
                                                  size: 14,
                                                  color: isAudioPlaying ? Colors.white : AppColors.primaryBlueDark,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  isAudioPlaying ? 'Dừng' : 'Nghe bài đọc',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: isAudioPlaying ? Colors.white : AppColors.primaryBlueDark,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                      ],

                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Đọc ngay',
                                            style: theme.textTheme.labelMedium?.copyWith(
                                              color: AppColors.primaryBlueDark,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.primaryBlueDark),
                                        ],
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

  Widget _buildProgressBar(ReadingProgress progress, ReadingPassage passage, ThemeData theme) {
    final estTotalSeconds = passage.estimatedMinutes * 60;
    final double percent = estTotalSeconds > 0
        ? (progress.readingTimeSeconds / estTotalSeconds).clamp(0.08, 0.95)
        : 0.2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Đang đọc dở (${(percent * 100).toInt()}%)',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${progress.readingTimeSeconds}s / ${passage.estimatedMinutes}p',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: AppColors.secondaryText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: AppColors.warningContainerLight,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.warning),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
