import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/audio/audio_recorder_service.dart';
import '../../../../core/audio/tts_service.dart';
import '../../../../core/audio/unified_audio_playback_service.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/cat_item.dart';
import '../../domain/models/cat_skill.dart';

/// Card rendering adaptive question formats (Multiple Choice, Pinyin Input, Speaking).
class CatQuestionCard extends StatefulWidget {
  final CatItem item;
  final ValueChanged<dynamic> onAnswerSubmitted;

  const CatQuestionCard({
    super.key,
    required this.item,
    required this.onAnswerSubmitted,
  });

  @override
  State<CatQuestionCard> createState() => _CatQuestionCardState();
}

class _CatQuestionCardState extends State<CatQuestionCard> {
  final TextEditingController _textController = TextEditingController();
  late List<int> _shuffledIndices;
  int? _selectedOptionIndex;
  bool _isSpeakingActive = false;
  bool _hasRecordedAttempt = false;
  String? _recordingStatusText;
  DefaultTtsService? _tts;
  AudioRecorderService? _recorder;

  @override
  void initState() {
    super.initState();
    _shuffledIndices = _buildShuffledIndices(widget.item);
  }

  List<int> _buildShuffledIndices(CatItem item) {
    final indices = List<int>.generate(item.options.length, (i) => i);
    if (indices.length > 1) {
      indices.shuffle(math.Random(item.id.hashCode));
    }
    return indices;
  }

  @override
  void didUpdateWidget(covariant CatQuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _textController.clear();
      _shuffledIndices = _buildShuffledIndices(widget.item);
      _selectedOptionIndex = null;
      _isSpeakingActive = false;
      _hasRecordedAttempt = false;
      _recordingStatusText = null;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _recorder?.dispose();
    super.dispose();
  }

  String _extractSpokenFallback(CatItem item) {
    const itemAudioText = <String, String>{
      'TONE_001': 'mā, mà',
      'TONE_002': 'mí, mǐ',
      'PIN_001': '妈',
      'PIN_002': '你',
      'PIN_003': '好',
      'LIST_001': '谢谢',
      'LIST_002': '请问，洗手间在哪里？',
      'LIST_003': '服务员，请给我两双筷子。',
    };
    if (itemAudioText.containsKey(item.id)) {
      return itemAudioText[item.id]!;
    }
    if (item.correctAnswerText != null && item.correctAnswerText!.trim().isNotEmpty) {
      return item.correctAnswerText!.trim();
    }
    if (item.annotatedPrompt != null && item.annotatedPrompt!.isNotEmpty) {
      return item.annotatedPrompt!.replaceAll(RegExp(r'\[[^\]]*\]'), '').trim();
    }
    final zhMatches =
        RegExp(r'[\u4e00-\u9fff]+').allMatches(item.explanationVi).map((m) => m.group(0)!).toList();
    if (zhMatches.isNotEmpty) {
      return zhMatches.join('，');
    }
    return item.prompt;
  }

  Future<void> _playItemAudio(CatItem item) async {
    final uri = item.audioUri;
    if (uri != null && uri.isNotEmpty) {
      try {
        if (uri.startsWith('assets/')) {
          // Verify asset exists before invoking audio plugin
          await rootBundle.load(uri);
        }
        await UnifiedAudioPlaybackService.instance.playAudio(uri);
        return;
      } catch (_) {
        // Fall through cleanly to TTS synthesis if audio asset is missing offline
      }
    }

    final text = _extractSpokenFallback(item);
    try {
      _tts ??= DefaultTtsService();
      await _tts!.speak(text, language: 'zh-CN');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể phát âm thanh lúc này.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _toggleSpeakingRecording(CatItem item) async {
    if (_isSpeakingActive) {
      String? recordedPath;
      try {
        recordedPath = await _recorder?.stopRecording();
      } catch (_) {
        recordedPath = null;
      }
      if (!mounted) return;
      setState(() {
        _isSpeakingActive = false;
        _hasRecordedAttempt = true;
        _recordingStatusText = recordedPath != null
            ? 'Đã lưu bản ghi âm. Vui lòng tự đánh giá hoặc gửi kiểm tra bên dưới.'
            : 'Đã hoàn tất lượt đọc thử. Vui lòng chọn mức tự đánh giá bên dưới.';
      });
      return;
    }

    setState(() {
      _isSpeakingActive = true;
      _recordingStatusText = 'Đang chuẩn bị micro...';
    });

    try {
      _recorder ??= DefaultAudioRecorderService();
      await _recorder!.startRecording();
      if (mounted) {
        setState(() {
          _recordingStatusText = 'Đang ghi âm... Hãy đọc to câu mẫu rồi nhấn dừng.';
        });
      }
    } catch (_) {
      // Simulator / desktop without mic hardware: still allow reference audio + honest self-assessment
      if (mounted) {
        setState(() {
          _isSpeakingActive = false;
          _hasRecordedAttempt = true;
          _recordingStatusText =
              'Thiết bị chưa sẵn sàng micro. Hãy nghe phát âm mẫu và tự đánh giá bên dưới.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;

    return HiCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sub-type indicator if applicable
          if (item.writingSubType != null) ...[
            Text(
              item.writingSubType!.labelVi,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.primaryBlueDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],

          // Question Prompt Text
          Text(
            item.prompt,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Annotated Chinese sentence with RubyText (hidden for listening questions)
          if (item.annotatedPrompt != null && item.skill != CatSkill.listening) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                borderRadius: AppRadius.borderMd,
              ),
              child: RubyText.fromAnnotatedString(
                annotatedText: item.annotatedPrompt!,
                showPinyin: true,
                hanziStyle: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Audio prompt if applicable
          if (item.audioUri != null || item.skill == CatSkill.listening) ...[
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primaryBlueLight.withAlpha(50),
                borderRadius: AppRadius.borderMd,
                border: Border.all(color: AppColors.primaryBlueLight),
              ),
              child: Row(
                children: [
                  IconButton.filled(
                    icon: const Icon(Icons.volume_up_rounded),
                    tooltip: 'Nghe lại phát âm',
                    onPressed: () => _playItemAudio(item),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Nhấn để nghe câu hỏi âm thanh (ẩn chữ Hán & phụ đề)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.primaryBlueDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Formats:
          // A. Multiple Choice & Stroke Order (shuffled deterministically, preserving original index)
          if (item.options.isNotEmpty) ...[
            ...List.generate(_shuffledIndices.length, (displayPos) {
              final originalIndex = _shuffledIndices[displayPos];
              final optionText = item.options[originalIndex];
              final isSelected = _selectedOptionIndex == originalIndex;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedOptionIndex = originalIndex);
                    widget.onAnswerSubmitted(originalIndex);
                  },
                  borderRadius: AppRadius.borderMd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryBlueLight
                          : AppColors.cardBackground,
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryBlueDark
                            : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: isSelected
                              ? AppColors.primaryBlueDark
                              : AppColors.inputBackground,
                          child: Text(
                            String.fromCharCode(65 + displayPos), // A, B, C, D
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isSelected ? Colors.white : AppColors.secondaryText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            optionText,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ]

          // B. Pinyin Input
          else if (item.type == CatItemType.pinyinInput) ...[
            HiTextField(
              controller: _textController,
              hintText: 'Nhập Pinyin (ví dụ: hanyu, nihao)...',
              prefixIcon: const Icon(Icons.keyboard_outlined),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  widget.onAnswerSubmitted(val.trim());
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            HiButton(
              text: 'Xác nhận câu trả lời',
              icon: const Icon(Icons.check_rounded),
              variant: HiButtonVariant.primary,
              onPressed: () {
                if (_textController.text.trim().isNotEmpty) {
                  widget.onAnswerSubmitted(_textController.text.trim());
                }
              },
            ),
          ]

          // C. Speaking Prompt
          else if (item.type == CatItemType.speakingPrompt) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                borderRadius: AppRadius.borderMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isSpeakingActive ? Icons.mic_rounded : Icons.mic_none_rounded,
                        color: _isSpeakingActive ? Colors.redAccent : AppColors.primaryBlueDark,
                        size: AppDimensions.iconXl,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      IconButton.outlined(
                        icon: const Icon(Icons.volume_up_rounded),
                        tooltip: 'Nghe phát âm mẫu',
                        onPressed: () => _playItemAudio(item),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _recordingStatusText ??
                        'Nhấn ghi âm để đọc to câu trên, nghe mẫu để đối chiếu và tự đánh giá trung thực',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  HiButton(
                    text: _isSpeakingActive ? 'Dừng ghi âm' : 'Bắt đầu ghi âm',
                    icon: Icon(_isSpeakingActive ? Icons.stop_rounded : Icons.mic_rounded),
                    variant: _isSpeakingActive ? HiButtonVariant.secondary : HiButtonVariant.primary,
                    onPressed: () => _toggleSpeakingRecording(item),
                  ),
                  if (_hasRecordedAttempt || !_isSpeakingActive) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Tự đánh giá khả năng đọc của bạn:',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    HiButton(
                      text: 'Đọc đúng & rõ thanh điệu',
                      variant: HiButtonVariant.primary,
                      onPressed: _isSpeakingActive
                          ? null
                          : () => widget.onAnswerSubmitted('passed'),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    HiButton(
                      text: 'Gửi bản ghi chờ kiểm tra',
                      variant: HiButtonVariant.secondary,
                      onPressed: _isSpeakingActive
                          ? null
                          : () => widget.onAnswerSubmitted('speech_sample_recorded'),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    HiButton(
                      text: 'Chưa đọc được câu này',
                      variant: HiButtonVariant.secondary,
                      onPressed: _isSpeakingActive
                          ? null
                          : () => widget.onAnswerSubmitted(false),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
