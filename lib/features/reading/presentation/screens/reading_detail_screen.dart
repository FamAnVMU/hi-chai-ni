import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/network/ai/ai.dart';
import '../../../../core/theme/theme.dart';
import '../../../dictionary/data/dictionary_repository.dart';
import '../../../dictionary/presentation/widgets/dictionary_detail_sheet.dart';
import '../../../settings/presentation/screens/ai_settings_screen.dart';
import '../../data/reading_repository.dart';
import '../../domain/models/reading_models.dart';
import '../widgets/reading_mode_selector.dart';
import '../widgets/reading_questions_section.dart';

/// Interactive reading screen with multi-mode display, word tap dictionary lookup,
/// comprehension questions, and AI contextual assistance.
class ReadingDetailScreen extends StatefulWidget {
  final ReadingPassage passage;
  final ReadingRepository? repository;
  final DictionaryRepository? dictionaryRepository;

  const ReadingDetailScreen({
    super.key,
    required this.passage,
    this.repository,
    this.dictionaryRepository,
  });

  @override
  State<ReadingDetailScreen> createState() => _ReadingDetailScreenState();
}

class _ReadingDetailScreenState extends State<ReadingDetailScreen> {
  late final ReadingRepository _repo;
  late final DictionaryRepository _dictRepo;

  ReadingDisplayMode _displayMode = ReadingDisplayMode.full;
  late final List<RubySegment> _segments;

  Timer? _readingTimer;
  int _readingTimeSeconds = 0;
  ReadingProgress? _existingProgress;
  bool _isLoading = true;
  CancelToken? _aiCancelToken;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final db = AppDatabase.instance.database;
    _repo = widget.repository ?? DefaultReadingRepository(db);
    _dictRepo = widget.dictionaryRepository ?? DefaultDictionaryRepository(db);

    _segments = widget.passage.buildRubySegments();
    _startTimer();
    _loadProgress();
  }

  void _startTimer() {
    _readingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _readingTimeSeconds++;
        });
      }
    });
  }

  Future<void> _loadProgress() async {
    final progress = await _repo.getProgress(widget.passage.id);
    if (mounted) {
      setState(() {
        _existingProgress = progress;
        if (progress != null) {
          _readingTimeSeconds = progress.readingTimeSeconds;
        }
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _aiCancelToken?.cancel();
    _readingTimer?.cancel();
    _saveProgress(isCompleted: _existingProgress?.isCompleted ?? false);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _saveProgress({
    required bool isCompleted,
    Map<String, int>? answers,
    double? score,
  }) async {
    final currentOffset = _scrollController.hasClients ? _scrollController.offset : 0.0;
    await _repo.saveReadingSession(
      passageId: widget.passage.id,
      readingTimeSeconds: _readingTimeSeconds,
      lastScrollOffset: currentOffset,
      answers: answers ?? _existingProgress?.answers ?? {},
      isCompleted: isCompleted,
      score: score ?? _existingProgress?.score,
    );
  }

  Future<void> _handleWordTap(RubySegment segment) async {
    final hanzi = segment.text.trim();
    if (hanzi.isEmpty || segment.isPunctuation) return;

    // Search dictionary by word
    var entry = await _dictRepo.getWordByExactHanzi(hanzi);
    if (entry == null) {
      final searchList = await _dictRepo.search(hanzi, limit: 1);
      if (searchList.isNotEmpty) {
        entry = searchList.first;
      }
    }

    if (!mounted) return;

    if (entry != null) {
      DictionaryDetailSheet.show(
        context,
        entry: entry,
        repository: _dictRepo,
        contextSentence: widget.passage.contentCn,
      );
    } else {
      // Fallback popup if not in vocabulary database
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$hanzi ${segment.pinyin != null ? "[${segment.pinyin}]" : ""}: Chưa có định nghĩa chi tiết.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _handleAskAi() async {
    final controller = TextEditingController();
    final question = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: AppColors.primaryBlueDark),
                const SizedBox(width: 8),
                Text(
                  'Hỏi AI về Bài Đọc',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: controller,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Đặt câu hỏi về từ vựng, ngữ pháp hoặc văn hóa trong bài...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('Giải thích cấu trúc ngữ pháp'),
                  onPressed: () => controller.text = 'Giải thích cấu trúc ngữ pháp tiêu biểu trong bài đọc này.',
                ),
                ActionChip(
                  label: const Text('Từ vựng khó cần lưu ý'),
                  onPressed: () => controller.text = 'Những từ vựng quan trọng nhất trong bài đọc này là gì?',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              icon: const Icon(Icons.send_rounded),
              label: const Text('Gửi câu hỏi'),
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );

    if (question != null && question.isNotEmpty && mounted) {
      _aiCancelToken?.cancel();
      _aiCancelToken = CancelToken();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('AI Tutor đang phân tích đoạn văn...'),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  _aiCancelToken?.cancel();
                  Navigator.of(dialogCtx).pop();
                },
                child: const Text('Hủy bỏ'),
              ),
            ],
          ),
        ),
      );

      try {
        final explanation = await _repo.askAiAboutPassage(
          passageText: widget.passage.contentCn,
          userQuestion: question,
          cancelToken: _aiCancelToken,
        );

        if (!mounted) return;
        Navigator.of(context).pop(); // dismiss loading dialog

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: AppColors.primaryBlueDark),
                SizedBox(width: 8),
                Text('Phản Hồi Từ AI Tutor'),
              ],
            ),
            content: SingleChildScrollView(
              child: SelectableText(explanation),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Đã hiểu'),
              ),
            ],
          ),
        );
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop(); // dismiss loading dialog

        if (e is AiCancelledException) {
          return;
        }

        final isAuthError =
            e is AiAuthenticationException || e.toString().toLowerCase().contains('api key');
        final errorMsg = isAuthError
            ? 'Chưa cấu hình API Key. Vui lòng thiết lập khóa Gemini API trong phần Cài đặt để sử dụng tính năng này.'
            : (e is AiNetworkException
                ? 'Không thể kết nối đến máy chủ AI. Vui lòng kiểm tra lại kết nối mạng.'
                : 'Lỗi kết nối AI: $e');

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Không Thể Kết Nối AI'),
              ],
            ),
            content: Text(errorMsg),
            actions: [
              if (isAuthError)
                FilledButton.icon(
                  icon: const Icon(Icons.settings, size: 16),
                  label: const Text('Cài đặt AI'),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                    );
                  },
                ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Đóng'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final showPinyin = _displayMode == ReadingDisplayMode.full ||
        _displayMode == ReadingDisplayMode.hanziAndPinyin;
    final showTranslation = _displayMode == ReadingDisplayMode.full ||
        _displayMode == ReadingDisplayMode.hanziAndTranslation;

    final minutes = _readingTimeSeconds ~/ 60;
    final seconds = _readingTimeSeconds % 60;
    final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.passage.titleCn),
        actions: [
          // Timer Chip
          Center(
            child: Container(
              margin: const EdgeInsets.only(right: AppSpacing.md),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    timeStr,
                    style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Display Mode Selector Bar
                Container(
                  color: theme.colorScheme.surface,
                  child: ReadingModeSelector(
                    currentMode: _displayMode,
                    onModeChanged: (mode) {
                      setState(() => _displayMode = mode);
                    },
                  ),
                ),
                const Divider(height: 1),

                // Main Reading & Comprehension Scroll View
                Expanded(
                  child: ListView(
                    controller: _scrollController,
                    padding: AppSpacing.screenPadding,
                    children: [
                      // Passage Header Metadata
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlueLight,
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppColors.border, width: 0.8),
                            ),
                            child: Text(
                              'HSK ${widget.passage.hskLevel}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryBlueDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Chip(
                            label: Text(widget.passage.topic),
                            visualDensity: VisualDensity.compact,
                          ),
                          const Spacer(),
                          Text(
                            '${widget.passage.wordCount} chữ Hán',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Interactive Reading Content Card
                      HiCard(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RubyText(
                              segments: _segments,
                              showPinyin: showPinyin,
                              spacing: AppSpacing.xs,
                              runSpacing: AppSpacing.md,
                              hanziStyle: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 18,
                                height: 1.6,
                                fontWeight: FontWeight.w500,
                              ),
                              pinyinStyle: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              onSegmentTap: _handleWordTap,
                            ),

                            // Vietnamese Translation (if enabled in current mode)
                            if (showTranslation && widget.passage.translationVi.isNotEmpty) ...[
                              const SizedBox(height: AppSpacing.lg),
                              const Divider(height: 1),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: [
                                  const Icon(Icons.translate_rounded, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Bản dịch tiếng Việt',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                widget.passage.translationVi,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  height: 1.5,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),

                      // Comprehension Questions
                      ReadingQuestionsSection(
                        questions: widget.passage.questions,
                        initialAnswers: _existingProgress?.answers ?? {},
                        isSubmitted: _existingProgress?.isCompleted ?? false,
                        onSubmitted: (answers, score) async {
                          await _saveProgress(
                            isCompleted: true,
                            answers: answers,
                            score: score,
                          );
                          setState(() {
                            _existingProgress = ReadingProgress(
                              id: 'updated',
                              passageId: widget.passage.id,
                              isCompleted: true,
                              readingTimeSeconds: _readingTimeSeconds,
                              answers: answers,
                              score: score,
                              updatedAt: DateTime.now(),
                            );
                          });

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Đã hoàn thành bài đọc! Điểm: ${score.toStringAsFixed(0)}%'),
                              backgroundColor: score >= 70 ? Colors.green : Colors.orange,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Hỏi AI về bài đọc'),
        onPressed: _handleAskAi,
      ),
    );
  }
}
