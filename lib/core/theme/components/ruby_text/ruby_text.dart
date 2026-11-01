import 'package:flutter/material.dart';
import '../../tokens/app_colors.dart';
import '../../tokens/app_dimensions.dart';
import '../../tokens/app_radius.dart';
import '../../tokens/app_spacing.dart';
import '../../tokens/app_typography.dart';
import 'ruby_segment.dart';

export 'ruby_segment.dart';

/// RubyText renders Chinese Hanzi with phonetic Pinyin annotations positioned above.
///
/// Key Architectural Features:
/// 1. Guaranteed Word-Level Line Breaks: Hanzi and its corresponding Pinyin are
///    bound atomically, so Pinyin never drifts or breaks onto a different line.
/// 2. Punctuation Baseline Alignment: Chinese and Western punctuation (，。！？)
///    naturally align with the bottom Hanzi text baseline via `WrapCrossAlignment.end`.
/// 3. Zero-Clipping Diacritics: Tone marks (ā, á, ǎ, à, ō, ó, ǒ, ò, ē, é, ě, è, ī, í, ǐ, ì, ū, ú, ǔ, ù, ǖ, ǘ, ǚ, ǜ)
///    render with generous line-height to prevent Android system clipping.
/// 4. Polyphone Defense: Does not perform naive automated pinyin deduction.
///    Strictly relies on verified segment data from the dictionary/dataset.
/// 5. Tap and Audio States: Tapping delegates to `onSegmentTap` or `onPronounceTap`
///    with zero embedded API calls.
class RubyText extends StatelessWidget {
  /// The list of segments constituting the sentence or phrase
  final List<RubySegment> segments;

  /// Whether to display the Pinyin annotation row
  final bool showPinyin;

  /// Whether to display Traditional Chinese characters if available in segment
  final bool showTraditional;

  /// Custom style for the base Hanzi characters
  final TextStyle? hanziStyle;

  /// Custom style for the Pinyin annotation
  final TextStyle? pinyinStyle;

  /// Horizontal spacing between words/segments
  final double spacing;

  /// Vertical spacing between wrapped lines
  final double runSpacing;

  /// Alignment of the text wrap
  final WrapAlignment alignment;

  /// Callback when a word/character segment is tapped
  final ValueChanged<RubySegment>? onSegmentTap;

  /// Callback when pronunciation audio is requested for a segment
  final ValueChanged<RubySegment>? onPronounceTap;

  /// Word ID of the currently active/selected segment
  final String? activeWordId;

  /// Whether audio is currently loading/buffering for the active segment
  final bool isAudioLoading;

  /// Custom highlight color for the active segment
  final Color? activeColor;

  const RubyText({
    super.key,
    required this.segments,
    this.showPinyin = true,
    this.showTraditional = false,
    this.hanziStyle,
    this.pinyinStyle,
    this.spacing = AppSpacing.xs,
    this.runSpacing = AppSpacing.md,
    this.alignment = WrapAlignment.start,
    this.onSegmentTap,
    this.onPronounceTap,
    this.activeWordId,
    this.isAudioLoading = false,
    this.activeColor,
  });

  /// Factory constructor to render directly from bracket-annotated syntax:
  /// `你好[nǐ hǎo]，世界[shìjiè]！`
  factory RubyText.fromAnnotatedString({
    Key? key,
    required String annotatedText,
    bool showPinyin = true,
    bool showTraditional = false,
    TextStyle? hanziStyle,
    TextStyle? pinyinStyle,
    double spacing = AppSpacing.xs,
    double runSpacing = AppSpacing.md,
    WrapAlignment alignment = WrapAlignment.start,
    ValueChanged<RubySegment>? onSegmentTap,
    ValueChanged<RubySegment>? onPronounceTap,
    String? activeWordId,
    bool isAudioLoading = false,
    Color? activeColor,
  }) {
    return RubyText(
      key: key,
      segments: RubySegment.fromAnnotatedString(annotatedText),
      showPinyin: showPinyin,
      showTraditional: showTraditional,
      hanziStyle: hanziStyle,
      pinyinStyle: pinyinStyle,
      spacing: spacing,
      runSpacing: runSpacing,
      alignment: alignment,
      onSegmentTap: onSegmentTap,
      onPronounceTap: onPronounceTap,
      activeWordId: activeWordId,
      isAudioLoading: isAudioLoading,
      activeColor: activeColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Resolve base styles
    final defaultHanziStyle = (hanziStyle ?? AppTypography.hanziMedium()).copyWith(
      color: hanziStyle?.color ?? theme.colorScheme.onSurface,
    );

    final defaultPinyinStyle = (pinyinStyle ?? AppTypography.pinyin()).copyWith(
      color: pinyinStyle?.color ??
          (isDark ? AppColors.limeGreen : theme.colorScheme.primary),
    );

    return Wrap(
      alignment: alignment,
      crossAxisAlignment: WrapCrossAlignment.end, // Aligns punctuation with Hanzi baseline
      spacing: spacing,
      runSpacing: runSpacing,
      children: segments.map((segment) {
        return _buildSegmentWidget(
          context,
          segment: segment,
          hanziStyle: defaultHanziStyle,
          pinyinStyle: defaultPinyinStyle,
          isDark: isDark,
        );
      }).toList(),
    );
  }

  Widget _buildSegmentWidget(
    BuildContext context, {
    required RubySegment segment,
    required TextStyle hanziStyle,
    required TextStyle pinyinStyle,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final hasPinyin = showPinyin && segment.pinyin != null && segment.pinyin!.isNotEmpty;
    final isActive = segment.wordId != null && segment.wordId == activeWordId;

    // Determine the Hanzi character(s) to show (Traditional vs Simplified)
    final textToShow = (showTraditional && segment.traditionalText != null && segment.traditionalText!.isNotEmpty)
        ? segment.traditionalText!
        : segment.text;

    Widget coreWidget;

    if (!hasPinyin || segment.isPunctuation) {
      // Punctuation or unannotated text: sits directly on the baseline
      coreWidget = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.0),
        child: Text(
          textToShow,
          style: hanziStyle,
        ),
      );
    } else {
      // Chinese word with Pinyin: build character-by-character or word-cluster
      final syllables = segment.pinyin!.split(RegExp(r'\s+'));
      final characters = textToShow.characters.toList();

      if (syllables.length == characters.length && characters.length > 1) {
        // Exact 1-to-1 syllable-to-character match for multi-character compound word:
        // Render each (Syllable, Char) pair inside an unbreakable Row
        coreWidget = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(characters.length, (i) {
            return _buildRubyUnit(
              hanzi: characters[i],
              pinyin: syllables[i],
              hanziStyle: hanziStyle,
              pinyinStyle: pinyinStyle,
            );
          }),
        );
      } else {
        // Single character or composite phrase: render pinyin above whole text
        coreWidget = _buildRubyUnit(
          hanzi: textToShow,
          pinyin: segment.pinyin!,
          hanziStyle: hanziStyle,
          pinyinStyle: pinyinStyle,
        );
      }
    }

    // Wrap in active state indicator / tap handler if interactive
    final isInteractive = !segment.isPunctuation && (onSegmentTap != null || onPronounceTap != null);

    if (isInteractive || isActive) {
      final highlightColor = activeColor ??
          (isDark
              ? AppColors.limeGreen.withAlpha(50)
              : theme.colorScheme.primaryContainer.withAlpha(180));

      final activeBorderColor = isActive
          ? (isDark ? AppColors.limeGreen : theme.colorScheme.primary)
          : Colors.transparent;

      Widget interactiveContent = coreWidget;

      if (isActive && isAudioLoading) {
        interactiveContent = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            coreWidget,
            const SizedBox(width: AppSpacing.xs),
            SizedBox(
              height: AppDimensions.iconXs,
              width: AppDimensions.iconXs,
              child: CircularProgressIndicator(
                strokeWidth: 1.8,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? AppColors.limeGreen : theme.colorScheme.primary,
                ),
              ),
            ),
          ],
        );
      }

      return Material(
        color: isActive ? highlightColor : Colors.transparent,
        borderRadius: AppRadius.borderSm,
        child: InkWell(
          onTap: onSegmentTap != null ? () => onSegmentTap!(segment) : null,
          onLongPress: onPronounceTap != null ? () => onPronounceTap!(segment) : null,
          borderRadius: AppRadius.borderSm,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 1.0),
            decoration: BoxDecoration(
              borderRadius: AppRadius.borderSm,
              border: Border.all(
                color: activeBorderColor,
                width: 1.0,
              ),
            ),
            child: interactiveContent,
          ),
        ),
      );
    }

    return coreWidget;
  }

  /// Builds an individual Ruby unit: Pinyin vertically stacked above Hanzi
  Widget _buildRubyUnit({
    required String hanzi,
    required String pinyin,
    required TextStyle hanziStyle,
    required TextStyle pinyinStyle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Pinyin with ample line height to prevent diacritic clipping
        Text(
          pinyin,
          style: pinyinStyle,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.visible,
        ),
        const SizedBox(height: 1.0),
        // Hanzi character
        Text(
          hanzi,
          style: hanziStyle,
          textAlign: TextAlign.center,
          maxLines: 1,
        ),
      ],
    );
  }
}
