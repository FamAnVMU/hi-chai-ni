import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../dictionary/presentation/widgets/quick_dictionary_sheet.dart';
import '../../domain/srs_models.dart';

/// Smooth 3D-flipping flashcard widget presenting Hanzi on the front
/// and detailed Pinyin, meanings, audio, and examples on the back.
class FlashcardCard extends StatefulWidget {
  final SrsFlashcardItem card;
  final bool isFlipped;
  final bool showPinyinOnFront;
  final VoidCallback onFlip;
  final VoidCallback onTogglePinyin;
  final VoidCallback? onPlayAudio;

  const FlashcardCard({
    super.key,
    required this.card,
    required this.isFlipped,
    this.showPinyinOnFront = true,
    required this.onFlip,
    required this.onTogglePinyin,
    this.onPlayAudio,
  });

  @override
  State<FlashcardCard> createState() => _FlashcardCardState();
}

class _FlashcardCardState extends State<FlashcardCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flipController;
  late final Animation<double> _flipAnimation;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: widget.isFlipped ? 1.0 : 0.0,
    );
    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void didUpdateWidget(covariant FlashcardCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFlipped != oldWidget.isFlipped) {
      if (widget.isFlipped) {
        _flipController.forward();
      } else {
        _flipController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _flipController.dispose();
    super.dispose();
  }

  void _handleAudioPlayback(BuildContext context) {
    if (widget.onPlayAudio != null) {
      widget.onPlayAudio!();
      return;
    }

    if (widget.card.audioUri != null && widget.card.audioUri!.isNotEmpty) {
      HiSnackBar.showSuccess(
        context,
        'Đang phát âm thanh: ${widget.card.simplified} (${widget.card.pinyin})',
      );
    } else {
      HiSnackBar.showInfo(
        context,
        'Chưa có file phát âm gốc cho từ "${widget.card.simplified}". Đang dùng bộ đọc hệ thống.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _flipAnimation,
        builder: (context, _) {
          final angle = _flipAnimation.value * math.pi;
          final isBackVisible = angle >= (math.pi / 2);

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001) // 3D Perspective
              ..rotateY(angle),
            child: isBackVisible
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()..rotateY(math.pi),
                    child: _buildBackFace(context),
                  )
                : _buildFrontFace(context),
          );
        },
      ),
    );
  }

  Widget _buildFrontFace(BuildContext context) {
    final theme = Theme.of(context);
    final card = widget.card;

    return Semantics(
      label:
          'Mặt trước thẻ từ vựng: ${card.simplified}. Chạm để lật xem nghĩa.',
      button: true,
      onTap: widget.onFlip,
      child: GestureDetector(
        onTap: widget.onFlip,
        behavior: HitTestBehavior.opaque,
        child: HiCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          backgroundColor: AppColors.cardBackground,
          borderColor: AppColors.border,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 320),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Action & Status Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        HiChip(
                          label: 'HSK ${card.hskLevel}',
                          status: HiChipStatus.info,
                        ),
                        if (card.strokeCount != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          HiChip(
                            label: '${card.strokeCount} nét',
                            status: HiChipStatus.neutral,
                          ),
                        ],
                      ],
                    ),
                    IconButton(
                      icon: Icon(
                        widget.showPinyinOnFront
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.primaryBlueDark,
                        size: AppDimensions.iconSm,
                      ),
                      tooltip: widget.showPinyinOnFront
                          ? 'Ẩn Pinyin'
                          : 'Hiện Pinyin',
                      onPressed: widget.onTogglePinyin,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // Center Hanzi & Pinyin
                Column(
                  children: [
                    if (widget.showPinyinOnFront) ...[
                      Text(
                        card.pinyin,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppColors.primaryBlueDark,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    Text(
                      card.simplified,
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontSize: 56,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryText,
                        fontFamilyFallback: const ['Noto Sans SC', 'Heiti SC'],
                      ),
                    ),
                    if (card.traditional != null &&
                        card.traditional != card.simplified) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Phồn thể: ${card.traditional}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppColors.mutedText,
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // Bottom Flip Invitation
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.touch_app_rounded,
                      size: AppDimensions.iconSm,
                      color: AppColors.mutedText,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'Chạm vào thẻ để lật xem đáp án',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.mutedText,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackFace(BuildContext context) {
    final theme = Theme.of(context);
    final card = widget.card;

    return Semantics(
      label:
          'Mặt sau thẻ từ vựng: ${card.simplified}, phiên âm ${card.pinyin}, nghĩa ${card.meaningVi}',
      child: HiCard(
        padding: const EdgeInsets.all(AppSpacing.xl),
        backgroundColor: AppColors.cardBackground,
        borderColor: AppColors.secondaryBlue,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 320),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Action Row: HSK & Part of Speech & Tools
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      HiChip(
                        label: 'HSK ${card.hskLevel}',
                        status: HiChipStatus.info,
                      ),
                      if (card.partOfSpeech != null &&
                          card.partOfSpeech!.isNotEmpty) ...[
                        const SizedBox(width: AppSpacing.xs),
                        HiChip(
                          label: card.partOfSpeech!,
                          status: HiChipStatus.neutral,
                        ),
                      ],
                    ],
                  ),
                  Row(
                    children: [
                      IconButton.filledTonal(
                        icon: const Icon(
                          Icons.volume_up_rounded,
                          size: AppDimensions.iconSm,
                          color: AppColors.primaryBlueDark,
                        ),
                        tooltip: 'Phát âm',
                        onPressed: () => _handleAudioPlayback(context),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      IconButton.outlined(
                        icon: const Icon(
                          Icons.menu_book_rounded,
                          size: AppDimensions.iconSm,
                          color: AppColors.primaryBlueDark,
                        ),
                        tooltip: 'Mở chi tiết từ điển',
                        onPressed: () {
                          QuickDictionarySheet.show(
                            context,
                            initialWord: card.simplified,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // Word & Pronunciation
              Column(
                children: [
                  RubyText(
                    segments: [
                      RubySegment(
                        text: card.simplified,
                        pinyin: card.pinyin,
                      ),
                    ],
                    hanziStyle: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                      fontFamilyFallback: const ['Noto Sans SC', 'Heiti SC'],
                    ),
                    pinyinStyle: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.primaryBlueDark,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    card.meaningVi,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.md),

              // Example Sentence Section
              if (card.exampleCn != null && card.exampleCn!.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.inputBackground,
                    borderRadius: AppRadius.borderMd,
                    border: Border.all(
                      color: AppColors.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.format_quote_rounded,
                            size: AppDimensions.iconSm,
                            color: AppColors.primaryBlueDark,
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Text(
                            'Ví dụ câu:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.primaryBlueDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      RubyText.fromAnnotatedString(
                        annotatedText: card.exampleCn!,
                        showPinyin: true,
                        hanziStyle: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText,
                          fontFamilyFallback: const ['Noto Sans SC', 'Heiti SC'],
                        ),
                      ),
                      if (card.exampleVi != null &&
                          card.exampleVi!.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          card.exampleVi!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.secondaryText,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.sm),

              // Re-flip button
              Center(
                child: TextButton.icon(
                  onPressed: widget.onFlip,
                  icon: const Icon(Icons.flip_rounded, size: AppDimensions.iconSm, color: AppColors.primaryBlueDark),
                  label: const Text(
                    'Lật lại mặt trước',
                    style: TextStyle(color: AppColors.primaryBlueDark),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
