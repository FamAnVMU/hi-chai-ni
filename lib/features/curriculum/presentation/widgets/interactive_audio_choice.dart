import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/audio/tts_service.dart';
import '../../../../core/theme/theme.dart';

/// Represents a selectable Hanzi option with optional Pinyin and Vietnamese meaning
/// for [InteractiveAudioChoice].
class AudioChoiceOption {
  final String id;
  final String hanzi;
  final String? pinyin;
  final String? meaningVi;

  const AudioChoiceOption({
    required this.id,
    required this.hanzi,
    this.pinyin,
    this.meaningVi,
  });
}

/// Gamified listening micro-widget inspired by Duolingo & HelloChinese.
///
/// Features a large centered speaker button in [AppColors.primaryBlueDark]
/// and 3–4 selectable Hanzi cards with Pinyin/meaning that verify immediately on tap.
class InteractiveAudioChoice extends StatefulWidget {
  final List<AudioChoiceOption> options;
  final String correctOptionId;
  final String? audioText;
  final String prompt;
  final VoidCallback? onPlayAudio;
  final ValueChanged<bool>? onResult;
  final VoidCallback? onCompleted;
  final TtsService? ttsServiceOverride;

  const InteractiveAudioChoice({
    super.key,
    required this.options,
    required this.correctOptionId,
    this.audioText,
    this.prompt = 'Nghe phát âm và chọn từ đúng',
    this.onPlayAudio,
    this.onResult,
    this.onCompleted,
    this.ttsServiceOverride,
  });

  @override
  State<InteractiveAudioChoice> createState() => _InteractiveAudioChoiceState();
}

class _InteractiveAudioChoiceState extends State<InteractiveAudioChoice> {
  String? _selectedOptionId;
  bool? _isCorrect;
  bool _isPlayingAudio = false;
  TtsService? _ttsService;
  bool _ownsTts = false;

  @override
  void initState() {
    super.initState();
    if (widget.ttsServiceOverride != null) {
      _ttsService = widget.ttsServiceOverride;
      _ownsTts = false;
    }
  }

  @override
  void didUpdateWidget(covariant InteractiveAudioChoice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.correctOptionId != widget.correctOptionId ||
        oldWidget.options != widget.options) {
      _selectedOptionId = null;
      _isCorrect = null;
    }
  }

  @override
  void dispose() {
    if (_ownsTts) {
      _ttsService?.dispose();
    }
    super.dispose();
  }

  bool _isOptionCorrect(AudioChoiceOption option) {
    return option.id == widget.correctOptionId ||
        option.hanzi == widget.correctOptionId;
  }

  Future<void> _handlePlaySpeaker() async {
    HapticFeedback.selectionClick();
    setState(() {
      _isPlayingAudio = true;
    });

    if (widget.onPlayAudio != null) {
      widget.onPlayAudio!();
    } else {
      final targetOption = widget.options.firstWhere(
        _isOptionCorrect,
        orElse: () => widget.options.first,
      );
      final textToSpeak = widget.audioText ?? targetOption.hanzi;
      try {
        _ttsService ??= DefaultTtsService();
        _ownsTts = widget.ttsServiceOverride == null;
        await _ttsService!.speak(textToSpeak, language: 'zh-CN');
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _isPlayingAudio = false;
      });
    }
  }

  void _handleSelectOption(AudioChoiceOption option) {
    final correct = _isOptionCorrect(option);

    setState(() {
      _selectedOptionId = option.id;
      _isCorrect = correct;
    });

    if (correct) {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.lightImpact();
      widget.onResult?.call(true);
      widget.onCompleted?.call();
    } else {
      HapticFeedback.mediumImpact();
      widget.onResult?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return HiCard(
      backgroundColor:
          isDark ? AppColors.darkForestCard : AppColors.cardBackground,
      borderColor: isDark ? AppColors.darkForestBorder : AppColors.border,
      padding: AppSpacing.cardPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Prompt header
          Text(
            widget.prompt,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.primaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Centered Large Speaker Button in AppColors.primaryBlueDark
          Center(
            child: Material(
              key: const ValueKey('audio_choice_speaker_button'),
              color: AppColors.primaryBlueLight,
              shape: const CircleBorder(
                side: BorderSide(
                  color: AppColors.primaryBlueDark,
                  width: 2.0,
                ),
              ),
              child: InkWell(
                onTap: _handlePlaySpeaker,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 88,
                  height: 88,
                  child: Center(
                    child: Icon(
                      _isPlayingAudio
                          ? Icons.volume_up_rounded
                          : Icons.volume_up_rounded,
                      size: 44,
                      color: AppColors.primaryBlueDark,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Chạm vào loa để nghe phát âm',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.secondaryText,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // 3-4 Option Cards
          ...widget.options.map((option) {
            final isSelected = _selectedOptionId == option.id;
            final isOptionRight = _isOptionCorrect(option);

            Color borderColor = AppColors.border;
            Color bgColor = AppColors.cardBackground;
            Color textColor = AppColors.primaryText;
            IconData? trailingIcon;
            Color? trailingIconColor;

            if (_selectedOptionId != null) {
              if (isSelected && isOptionRight) {
                borderColor = AppColors.success;
                bgColor = AppColors.successContainerLight;
                textColor = AppColors.success;
                trailingIcon = Icons.check_circle_rounded;
                trailingIconColor = AppColors.success;
              } else if (isSelected && !isOptionRight) {
                borderColor = AppColors.error;
                bgColor = AppColors.errorContainerLight;
                textColor = AppColors.error;
                trailingIcon = Icons.cancel_rounded;
                trailingIconColor = AppColors.error;
              } else if (isOptionRight) {
                borderColor = AppColors.success;
                bgColor = AppColors.successContainerLight.withAlpha(140);
                trailingIcon = Icons.check_circle_outline_rounded;
                trailingIconColor = AppColors.success;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: HiCard(
                key: ValueKey('audio_option_${option.id}'),
                onTap: () => _handleSelectOption(option),
                backgroundColor: bgColor,
                borderColor: borderColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                option.hanzi,
                                style: AppTypography.hanziMedium(
                                  color: textColor,
                                ),
                              ),
                              if (option.pinyin != null &&
                                  option.pinyin!.isNotEmpty) ...[
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  '(${option.pinyin!})',
                                  style: AppTypography.pinyin(
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (option.meaningVi != null &&
                              option.meaningVi!.isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              option.meaningVi!,
                              style: AppTypography.vietnameseMeaning(
                                color: AppColors.secondaryText,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (trailingIcon != null)
                      Icon(
                        trailingIcon,
                        color: trailingIconColor,
                        size: 24,
                      ),
                  ],
                ),
              ),
            );
          }),

          // Immediate Feedback text
          if (_isCorrect != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              _isCorrect!
                  ? 'Chính xác! Bạn nghe rất chuẩn!'
                  : 'Chưa chính xác. Hãy thử nghe lại nhé!',
              key: const ValueKey('audio_choice_feedback_text'),
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: _isCorrect! ? AppColors.success : AppColors.error,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
