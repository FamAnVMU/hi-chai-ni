import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/audio/tts_service.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/curriculum_models.dart';

/// Bottom Sheet providing quick pedagogical notes for the current lesson:
/// 1. Focus Vocabulary (Từ vựng trọng tâm)
/// 2. Grammar Tips & Formula (Bí kíp ngữ pháp)
/// 3. Situational Dialogue (Hội thoại mẫu)
class LessonQuickNotesSheet extends StatefulWidget {
  final CurriculumLesson lesson;
  final List<Map<String, dynamic>>? vocabList;
  final List<Map<String, dynamic>>? grammarList;
  final List<Map<String, dynamic>>? dialogueLines;
  final AudioPlayerService? audioPlayerOverride;
  final TtsService? ttsServiceOverride;

  const LessonQuickNotesSheet({
    super.key,
    required this.lesson,
    this.vocabList,
    this.grammarList,
    this.dialogueLines,
    this.audioPlayerOverride,
    this.ttsServiceOverride,
  });

  /// Static helper to display the sheet modally with rounded top corners.
  static Future<void> show(
    BuildContext context, {
    required CurriculumLesson lesson,
    List<Map<String, dynamic>>? vocabList,
    List<Map<String, dynamic>>? grammarList,
    List<Map<String, dynamic>>? dialogueLines,
    AudioPlayerService? audioPlayer,
    TtsService? ttsService,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => LessonQuickNotesSheet(
        lesson: lesson,
        vocabList: vocabList,
        grammarList: grammarList,
        dialogueLines: dialogueLines,
        audioPlayerOverride: audioPlayer,
        ttsServiceOverride: ttsService,
      ),
    );
  }

  @override
  State<LessonQuickNotesSheet> createState() => _LessonQuickNotesSheetState();
}

class _LessonQuickNotesSheetState extends State<LessonQuickNotesSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final AudioPlayerService _audioPlayer;
  late final TtsService _ttsService;
  late final bool _ownsAudioPlayer;
  late final bool _ownsTts;

  String? _playingWord;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _ownsAudioPlayer = widget.audioPlayerOverride == null;
    _ownsTts = widget.ttsServiceOverride == null;
    _audioPlayer = widget.audioPlayerOverride ?? DefaultAudioPlayerService();
    _ttsService = widget.ttsServiceOverride ?? DefaultTtsService();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _audioPlayer.stop();
    _ttsService.stop();
    if (_ownsAudioPlayer) {
      _audioPlayer.dispose();
    }
    if (_ownsTts) {
      _ttsService.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> _resolveVocab() {
    if (widget.vocabList != null && widget.vocabList!.isNotEmpty) {
      return widget.vocabList!;
    }
    for (final seg in widget.lesson.segments) {
      if (seg.segmentType.toLowerCase() == 'vocabulary') {
        final list = (seg.contentPayload?['words'] as List<dynamic>?)
            ?.whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        if (list != null && list.isNotEmpty) return list;
      }
    }
    return [
      {
        'hanzi': widget.lesson.titleZh.isNotEmpty ? widget.lesson.titleZh : '你好',
        'pinyin': widget.lesson.pinyin.isNotEmpty ? widget.lesson.pinyin : 'nǐ hǎo',
        'meaning_vi': widget.lesson.titleVi.isNotEmpty ? widget.lesson.titleVi : 'Xin chào',
      }
    ];
  }

  List<Map<String, dynamic>> _resolveGrammar() {
    if (widget.grammarList != null && widget.grammarList!.isNotEmpty) {
      return widget.grammarList!;
    }
    for (final seg in widget.lesson.segments) {
      if (seg.segmentType.toLowerCase() == 'grammar') {
        final list = ((seg.contentPayload?['points'] ??
                seg.contentPayload?['grammar_points']) as List<dynamic>?)
            ?.whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        if (list != null && list.isNotEmpty) return list;
      }
    }
    return [
      {
        'title': 'Cấu trúc câu khẳng định với 是',
        'structure': 'A + 是 + B = A là B',
        'explanation': 'Dùng để liên kết chủ ngữ A với định danh B (nghề nghiệp, quốc tịch, danh tính).',
        'examples': [
          {
            'sentence_zh': '我是学生。',
            'pinyin': 'Wǒ shì xuésheng.',
            'meaning_vi': 'Tôi là học sinh.',
          }
        ]
      }
    ];
  }

  List<Map<String, dynamic>> _resolveDialogue() {
    if (widget.dialogueLines != null && widget.dialogueLines!.isNotEmpty) {
      return widget.dialogueLines!;
    }
    for (final seg in widget.lesson.segments) {
      if (seg.segmentType.toLowerCase() == 'dialogue') {
        final list = ((seg.contentPayload?['lines'] ??
                seg.contentPayload?['dialogue']?['lines']) as List<dynamic>?)
            ?.whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        if (list != null && list.isNotEmpty) return list;
      }
    }
    return [
      {
        'speaker': 'A',
        'text_zh': '你好！很高兴认识你。',
        'pinyin': 'Nǐ hǎo! Hěn gāoxìng rènshí nǐ.',
        'text_vi': 'Xin chào! Rất vui được làm quen với bạn.',
      },
      {
        'speaker': 'B',
        'text_zh': '你好！我也很高兴认识你。',
        'pinyin': 'Nǐ hǎo! Wǒ yě hěn gāoxìng rènshí nǐ.',
        'text_vi': 'Chào bạn! Tôi cũng rất vui được làm quen với bạn.',
      }
    ];
  }

  Future<void> _playPronunciation(String hanzi, String? audioUri) async {
    setState(() => _playingWord = hanzi);
    try {
      bool playedAudio = false;
      if (audioUri != null && audioUri.isNotEmpty) {
        final isLocalFile = !audioUri.startsWith('http') &&
            !audioUri.startsWith('assets/') &&
            !audioUri.startsWith('audio/');
        final fileExists = isLocalFile ? File(audioUri).existsSync() : true;

        if (fileExists || widget.audioPlayerOverride != null) {
          try {
            await _audioPlayer.play(audioUri);
            playedAudio = true;
          } catch (_) {
            playedAudio = false;
          }
        }
      }

      if (!playedAudio) {
        final available = await _ttsService.isLanguageAvailable('zh-CN');
        if (available) {
          await _ttsService.speak(hanzi, language: 'zh-CN');
        }
      }
    } catch (_) {
      // Ignored gracefully
    } finally {
      if (mounted) {
        setState(() => _playingWord = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 16,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag Handle
              const SizedBox(height: 10),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.xs, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlueLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: AppColors.primaryBlueDark,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cẩm nang bài học: ${widget.lesson.titleVi}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Tra cứu nhanh từ vựng, ngữ pháp và hội thoại',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.secondaryText),
                      tooltip: 'Đóng',
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xs),

              // Tab Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primaryBlueDark,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.secondaryText,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Từ vựng trọng tâm'),
                    Tab(text: 'Bí kíp ngữ pháp'),
                    Tab(text: 'Hội thoại mẫu'),
                  ],
                ),
              ),

              const Divider(color: AppColors.border, height: 1),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildVocabTab(scrollController),
                    _buildGrammarTab(scrollController),
                    _buildDialogueTab(scrollController),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVocabTab(ScrollController scrollController) {
    final words = _resolveVocab();

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: words.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final w = words[index];
        final hanzi = (w['hanzi'] ?? w['simplified'] ?? '').toString();
        final pinyin = (w['pinyin'] ?? '').toString();
        final meaning = (w['meaning'] ?? w['meaning_vi'] ?? '').toString();
        final audioUri = (w['audio_uri'] ?? w['audio_path'])?.toString();
        final isPlaying = _playingWord == hanzi;

        return HiCard(
          backgroundColor: AppColors.cardBackground,
          borderColor: AppColors.border,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hanzi,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pinyin,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryBlueDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      meaning,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  isPlaying ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                  color: isPlaying ? AppColors.primaryBlueDark : AppColors.primaryBlue,
                  size: 26,
                ),
                tooltip: 'Phát âm $hanzi',
                onPressed: () => _playPronunciation(hanzi, audioUri),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGrammarTab(ScrollController scrollController) {
    final points = _resolveGrammar();

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: points.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        final p = points[index];
        final title = (p['title'] ?? '').toString();
        final structure = (p['structure'] ?? p['formula'] ?? '').toString();
        final explanation = (p['explanation'] ?? p['explanation_vi'] ?? '').toString();
        final rawExamples = (p['examples'] as List<dynamic>?) ?? [];
        final examples = rawExamples.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList();

        return HiCard(
          backgroundColor: AppColors.cardBackground,
          borderColor: AppColors.border,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlueDark,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              if (structure.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlueLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    structure,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryBlueDark,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
              ],

              if (explanation.isNotEmpty) ...[
                Text(
                  explanation,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              if (examples.isNotEmpty) ...[
                const Text(
                  'Ví dụ minh họa:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.mutedText,
                  ),
                ),
                const SizedBox(height: 4),
                ...examples.map((ex) {
                  final sZh = (ex['sentence_zh'] ?? ex['hanzi'] ?? ex['chinese'] ?? '').toString();
                  final py = (ex['pinyin'] ?? '').toString();
                  final sVi = (ex['meaning_vi'] ?? ex['meaning'] ?? ex['vietnamese'] ?? '').toString();

                  return Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.mainBackground,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sZh,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryText,
                          ),
                        ),
                        if (py.isNotEmpty)
                          Text(
                            py,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryBlueDark,
                            ),
                          ),
                        if (sVi.isNotEmpty)
                          Text(
                            sVi,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDialogueTab(ScrollController scrollController) {
    final lines = _resolveDialogue();

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: lines.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final line = lines[index];
        final speaker = (line['speaker'] ?? 'A').toString().trim().toUpperCase();
        final textZh = (line['text_zh'] ?? line['hanzi'] ?? line['chinese'] ?? '').toString();
        final pinyin = (line['pinyin'] ?? '').toString();
        final textVi = (line['text_vi'] ?? line['meaning'] ?? line['vietnamese'] ?? '').toString();

        final isSpeakerA = speaker == 'A';

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isSpeakerA ? MainAxisAlignment.start : MainAxisAlignment.end,
          children: [
            if (isSpeakerA) ...[
              const CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.primaryBlueDark,
                child: Text(
                  'A',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isSpeakerA ? AppColors.primaryBlueLight : AppColors.secondaryBackground,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isSpeakerA ? 4 : 16),
                    bottomRight: Radius.circular(isSpeakerA ? 16 : 4),
                  ),
                  border: Border.all(
                    color: isSpeakerA ? AppColors.primaryBlue.withValues(alpha: 0.2) : AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                      isSpeakerA ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                  children: [
                    Text(
                      textZh,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                      ),
                    ),
                    if (pinyin.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        pinyin,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primaryBlueDark,
                        ),
                      ),
                    ],
                    if (textVi.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        textVi,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!isSpeakerA) ...[
              const SizedBox(width: AppSpacing.xs),
              const CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.success,
                child: Text(
                  'B',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
