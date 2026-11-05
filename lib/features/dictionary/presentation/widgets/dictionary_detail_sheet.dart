import 'package:flutter/material.dart';
import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/network/ai/ai.dart';
import '../../../../core/theme/theme.dart';
import '../../../hanzi/hanzi.dart';
import '../../../sentences/sentences.dart';
import '../../../settings/presentation/screens/ai_settings_screen.dart';
import '../../data/dictionary_repository.dart';
import '../../domain/models/dictionary_models.dart';

/// Modal bottom sheet displaying detailed dictionary entry information:
/// Hanzi, Pinyin, HSK Level, Senses, Examples, Audio pronunciation,
/// Save/Bookmark toggle with notes, and optional AI contextual explanation.
class DictionaryDetailSheet extends StatefulWidget {
  final DictionaryEntry entry;
  final DictionaryRepository repository;
  final String? contextSentence;

  const DictionaryDetailSheet({
    super.key,
    required this.entry,
    required this.repository,
    this.contextSentence,
  });

  static Future<void> show(
    BuildContext context, {
    required DictionaryEntry entry,
    required DictionaryRepository repository,
    String? contextSentence,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DictionaryDetailSheet(
        entry: entry,
        repository: repository,
        contextSentence: contextSentence,
      ),
    );
  }

  @override
  State<DictionaryDetailSheet> createState() => _DictionaryDetailSheetState();
}

class _DictionaryDetailSheetState extends State<DictionaryDetailSheet> {
  late DictionaryEntry _entry;
  bool _isAudioPlaying = false;
  String? _aiExplanation;
  String? _aiError;
  bool _isAiAuthError = false;
  bool _isLoadingAi = false;
  final AudioPlayerService _audioPlayer = DefaultAudioPlayerService();

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _handlePlayAudio() async {
    if (_entry.audioUri == null || _entry.audioUri!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chưa có audio phát âm cho từ này.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    setState(() => _isAudioPlaying = true);
    try {
      await _audioPlayer.play(_entry.audioUri!);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể phát audio lúc này.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isAudioPlaying = false);
    }
  }

  Future<void> _handleToggleSave() async {
    final newSaved = await widget.repository.toggleSaveWord(_entry);
    setState(() {
      _entry = _entry.copyWith(isSaved: newSaved);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newSaved ? 'Đã lưu vào danh sách từ vựng' : 'Đã bỏ lưu từ vựng'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _handleEditNote() async {
    final controller = TextEditingController(text: _entry.customNote ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ghi chú cho "${_entry.simplified}"'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Nhập ghi chú cá nhân (ngữ cảnh, lưu ý...).',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Lưu ghi chú'),
          ),
        ],
      ),
    );

    if (result != null) {
      await widget.repository.updateWordNote(_entry.id, result.isEmpty ? null : result);
      setState(() {
        _entry = _entry.copyWith(customNote: result.isEmpty ? null : result, isSaved: true);
      });
    }
  }

  Future<void> _handleAskAi() async {
    setState(() {
      _isLoadingAi = true;
      _aiError = null;
    });
    try {
      final explanation = await widget.repository.explainWordWithAi(
        _entry.simplified,
        contextSentence: widget.contextSentence,
      );
      if (mounted) {
        setState(() {
          _aiExplanation = explanation;
          _isLoadingAi = false;
        });
      }
    } catch (e) {
      if (mounted) {
        final isAuth = e is AiAuthenticationException || e.toString().toLowerCase().contains('api key');
        final errorMsg = isAuth
            ? 'Chưa cấu hình API Key. Vui lòng thiết lập khóa Gemini API trong phần Cài đặt để sử dụng tính năng này.'
            : (e is AiNetworkException
                ? 'Không thể kết nối đến máy chủ AI. Vui lòng kiểm tra lại kết nối mạng.'
                : 'Lỗi khi hỏi AI: $e');
        setState(() {
          _aiError = errorMsg;
          _isAiAuthError = isAuth;
          _isLoadingAi = false;
        });
      }
    }
  }

  void _handleOpenWriting() {
    final chars = _entry.simplified
        .split('')
        .where((c) => c.trim().isNotEmpty && (c.codeUnitAt(0) >= 0x4e00 && c.codeUnitAt(0) <= 0x9fff))
        .toList();
    if (chars.isEmpty) return;

    final db = widget.repository.database;
    if (db == null) return;
    final hanziRepo = DefaultHanziRepository(HanziDao(db));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HanziWritingScreen(
          initialCharacter: chars.first,
          wordCharacters: chars,
          wordTitle: _entry.simplified,
          repository: hanziRepo,
        ),
      ),
    );
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

            // Header Row: Word Info, Audio, Bookmark
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RubyText(
                          segments: [
                            RubySegment.word(
                              hanzi: _entry.simplified,
                              pinyin: _entry.pinyin,
                            ),
                          ],
                          hanziStyle: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.primaryBlueDark : theme.colorScheme.primary,
                          ),
                          pinyinStyle: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primaryBlueDark.withAlpha(isDark ? 60 : 35),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _entry.hskLevel > 0 ? 'HSK ${_entry.hskLevel}' : 'Từ điển',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.primaryBlueDark : AppColors.primaryBlueDark,
                                ),
                              ),
                            ),
                            if (_entry.hanviet != null && _entry.hanviet!.isNotEmpty) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withAlpha(isDark ? 60 : 35),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Hán-Việt: ${_entry.hanviet}',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.amber[200] : Colors.amber[900],
                                  ),
                                ),
                              ),
                            ],
                            if (_entry.traditional != null && _entry.traditional != _entry.simplified) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Phồn thể: ${_entry.traditional}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Audio Button
                  IconButton.filledTonal(
                    icon: _isAudioPlaying
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _entry.audioUri != null
                                ? Icons.volume_up_rounded
                                : Icons.volume_off_rounded,
                            color: _entry.audioUri != null
                                ? AppColors.primaryBlueDark
                                : theme.colorScheme.onSurfaceVariant.withAlpha(100),
                          ),
                    onPressed: _handlePlayAudio,
                    tooltip: 'Nghe phát âm',
                  ),
                  const SizedBox(width: AppSpacing.xs),

                  // Bookmark Button
                  IconButton.filledTonal(
                    icon: Icon(
                      _entry.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: _entry.isSaved ? Colors.amber : null,
                    ),
                    onPressed: _handleToggleSave,
                    tooltip: _entry.isSaved ? 'Đã lưu' : 'Lưu từ vựng',
                  ),
                  const SizedBox(width: AppSpacing.xs),

                  // Handwriting / Stroke Order Button
                  IconButton.filledTonal(
                    icon: const Icon(
                      Icons.draw_rounded,
                      color: Color(0xFF2563EB),
                    ),
                    onPressed: _handleOpenWriting,
                    tooltip: 'Luyện viết chữ Hán',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content List (Senses, Custom Note, AI Explanations)
            Flexible(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  // Custom Note Card (if saved)
                  if (_entry.customNote != null || _entry.isSaved) ...[
                    HiCard(
                      backgroundColor: theme.colorScheme.surfaceContainerHighest.withAlpha(70),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.note_alt_outlined, size: 16, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Ghi chú cá nhân',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: _handleEditNote,
                                child: Text(
                                  _entry.customNote == null ? 'Thêm ghi chú' : 'Sửa',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_entry.customNote != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _entry.customNote!,
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Senses List
                  Text(
                    'Định Nghĩa & Từ Loại',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  if (_entry.senses.isEmpty)
                    Text(
                      'Chưa có dữ liệu chi tiết cho từ này.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    ..._entry.senses.asMap().entries.map((item) {
                      final idx = item.key + 1;
                      final sense = item.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$idx. ',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.secondaryContainer.withAlpha(120),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    sense.partOfSpeech,
                                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 10),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Text(
                                    sense.meaningVi,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (sense.exampleCn != null && sense.exampleCn!.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Container(
                                margin: const EdgeInsets.only(left: 16),
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                  border: Border(
                                    left: BorderSide(
                                      color: isDark ? AppColors.primaryBlueDark : theme.colorScheme.primary,
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      sense.exampleCn!,
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (sense.examplePinyin != null)
                                      Text(
                                        sense.examplePinyin!,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    if (sense.exampleVi != null)
                                      Text(
                                        sense.exampleVi!,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        TextButton.icon(
                                          icon: const Icon(Icons.headphones_rounded, size: 14),
                                          label: const Text('Luyện nghe', style: TextStyle(fontSize: 11)),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          onPressed: () {
                                            final db = widget.repository.database;
                                            if (db != null) {
                                              final item = SentenceItem(
                                                id: 'dict_${_entry.id}_$idx',
                                                chinese: sense.exampleCn!,
                                                pinyin: sense.examplePinyin ?? '',
                                                translationVi: sense.exampleVi ?? '',
                                                hskLevel: _entry.hskLevel > 0 ? _entry.hskLevel : 1,
                                              );
                                              final repo = DefaultSentenceRepository(SentenceDao(db));
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => SentenceListeningScreen(
                                                    sentence: item,
                                                    sentenceList: [item],
                                                    repository: repo,
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        TextButton.icon(
                                          icon: const Icon(Icons.record_voice_over_rounded, size: 14),
                                          label: const Text('Shadowing', style: TextStyle(fontSize: 11)),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          onPressed: () {
                                            final db = widget.repository.database;
                                            if (db != null) {
                                              final item = SentenceItem(
                                                id: 'dict_${_entry.id}_$idx',
                                                chinese: sense.exampleCn!,
                                                pinyin: sense.examplePinyin ?? '',
                                                translationVi: sense.exampleVi ?? '',
                                                hskLevel: _entry.hskLevel > 0 ? _entry.hskLevel : 1,
                                              );
                                              final repo = DefaultSentenceRepository(SentenceDao(db));
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => SentenceShadowingScreen(
                                                    sentence: item,
                                                    repository: repo,
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: AppSpacing.sm),

                  // AI Explanation Section
                  if (_aiExplanation != null) ...[
                    HiCard(
                      backgroundColor: isDark
                          ? AppColors.cardBackground
                          : theme.colorScheme.primaryContainer.withAlpha(60),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.primaryBlueDark),
                              const SizedBox(width: 6),
                              Text(
                                'AI Tutor Phân Tích Bổ Sung',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? AppColors.primaryBlueDark : theme.colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            _aiExplanation!,
                            style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // AI Error Section (Friendly Banner with Action)
                  if (_aiError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer.withAlpha(80),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(
                          color: theme.colorScheme.error.withAlpha(120),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _aiError!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onErrorContainer,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_isAiAuthError) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                icon: const Icon(Icons.settings, size: 16),
                                label: const Text('Mở Cài Đặt AI'),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
                                  );
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Verified Graded Examples
                  if (_entry.examples.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Câu Ví Dụ Chuẩn HSK',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    ..._entry.examples.map((ex) => Container(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: const Border(
                              left: BorderSide(
                                color: AppColors.primaryBlueDark,
                                width: 3,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ex.exampleCn,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                ex.examplePinyin,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              if (ex.exampleVi != null && ex.exampleVi!.isNotEmpty)
                                Text(
                                  ex.exampleVi!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                  ),
                                )
                              else if (ex.exampleEn != null && ex.exampleEn!.isNotEmpty)
                                Text(
                                  ex.exampleEn!,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontStyle: FontStyle.italic,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        )),
                    const SizedBox(height: AppSpacing.sm),
                  ],

                  // Attribution & Open Source License
                  if (_entry.source != null) ...[
                    Center(
                      child: Text(
                        'Nguồn: ${_entry.source} • Giấy phép: ${_entry.license ?? "Open Source"}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Ask AI Button
                  HiButton(
                    text: _isLoadingAi ? 'Đang hỏi AI...' : 'Hỏi AI giải thích ngữ cảnh',
                    icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                    variant: HiButtonVariant.secondary,
                    isFullWidth: true,
                    isLoading: _isLoadingAi,
                    onPressed: _handleAskAi,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
