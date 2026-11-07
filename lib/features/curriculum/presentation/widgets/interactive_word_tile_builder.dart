import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/theme.dart';

/// Represents a single word token in the interactive builder, uniquely identified
/// by [id] so duplicate words in a sentence are tracked independently.
class WordTileToken {
  final int id;
  final String text;

  const WordTileToken({
    required this.id,
    required this.text,
  });
}

/// Gamified micro-widget inspired by Duolingo & HelloChinese for sentence building.
///
/// Preserves compound Chinese words (e.g., `[学生]` remains a single chip rather than
/// splitting into `[学]` and `[生]`).
class InteractiveWordTileBuilder extends StatefulWidget {
  /// The Vietnamese translation or context prompt (e.g., "Tôi là học sinh").
  final String prompt;

  /// Optional Pinyin or grammar hint displayed under the prompt.
  final String? hint;

  /// Ordered list of correct word tokens that form the target sentence
  /// (e.g., `['我', '是', '学生']`).
  final List<String> correctTokens;

  /// Pool of word chips available to the learner, including correct tokens and distractors
  /// (e.g., `['我', '是', '学生', '不', '老师']`).
  final List<String> wordPool;

  /// Whether to shuffle the initial source pool. Defaults to false for deterministic order
  /// when pre-shuffled pools are supplied.
  final bool shufflePool;

  /// Optional callback invoked when the learner taps "Kiểm tra" with `true` (correct)
  /// or `false` (incorrect).
  final ValueChanged<bool>? onResult;

  /// Optional callback invoked when the learner answers correctly.
  final VoidCallback? onCompleted;

  const InteractiveWordTileBuilder({
    super.key,
    required this.prompt,
    required this.correctTokens,
    required this.wordPool,
    this.hint,
    this.shufflePool = false,
    this.onResult,
    this.onCompleted,
  });

  /// Safe tokenizer utility that preserves multi-character Chinese compound words
  /// from [knownWords] instead of splitting them into individual characters.
  static List<String> tokenizePreservingCompounds(
    String sentence, {
    List<String> knownWords = const [],
  }) {
    final cleaned = sentence.trim();
    if (cleaned.isEmpty) return const [];

    if (cleaned.contains(' ')) {
      return cleaned
          .split(RegExp(r'\s+'))
          .where((token) => token.isNotEmpty)
          .toList();
    }

    if (knownWords.isEmpty) {
      return cleaned.runes.map((r) => String.fromCharCode(r)).toList();
    }

    // Sort known compound words by descending length for greedy longest-match
    final sortedCompounds = List<String>.from(knownWords)
      ..removeWhere((w) => w.trim().isEmpty)
      ..sort((a, b) => b.length.compareTo(a.length));

    final result = <String>[];
    var index = 0;
    while (index < cleaned.length) {
      String? matched;
      for (final word in sortedCompounds) {
        if (cleaned.startsWith(word, index)) {
          matched = word;
          break;
        }
      }
      if (matched != null) {
        result.add(matched);
        index += matched.length;
      } else {
        final char = cleaned[index];
        if (char.trim().isNotEmpty) {
          result.add(char);
        }
        index += 1;
      }
    }
    return result;
  }

  @override
  State<InteractiveWordTileBuilder> createState() =>
      _InteractiveWordTileBuilderState();
}

class _InteractiveWordTileBuilderState extends State<InteractiveWordTileBuilder>
    with SingleTickerProviderStateMixin {
  late List<WordTileToken> _allTokens;
  final List<WordTileToken> _selectedTokens = [];
  bool? _isCorrect;
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _initTokens();
  }

  @override
  void didUpdateWidget(covariant InteractiveWordTileBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.prompt != widget.prompt ||
        oldWidget.wordPool != widget.wordPool ||
        oldWidget.correctTokens != widget.correctTokens) {
      _selectedTokens.clear();
      _isCorrect = null;
      _initTokens();
    }
  }

  void _initTokens() {
    final pool = List<String>.from(widget.wordPool);
    if (widget.shufflePool) {
      pool.shuffle();
    }
    _allTokens = List.generate(
      pool.length,
      (index) => WordTileToken(id: index, text: pool[index]),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  bool _isTokenSelected(WordTileToken token) {
    return _selectedTokens.any((t) => t.id == token.id);
  }

  void _selectToken(WordTileToken token) {
    if (_isTokenSelected(token)) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedTokens.add(token);
      if (_isCorrect != null) {
        _isCorrect = null;
      }
    });
  }

  void _deselectToken(WordTileToken token) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedTokens.removeWhere((t) => t.id == token.id);
      if (_isCorrect != null) {
        _isCorrect = null;
      }
    });
  }

  void _handleCheck() {
    if (_selectedTokens.isEmpty) return;

    final userSentence = _selectedTokens.map((t) => t.text).join();
    final targetSentence = widget.correctTokens.join();
    final isMatch = userSentence == targetSentence;

    setState(() {
      _isCorrect = isMatch;
    });

    if (isMatch) {
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.lightImpact();
      widget.onResult?.call(true);
      widget.onCompleted?.call();
    } else {
      HapticFeedback.mediumImpact();
      _shakeController.forward(from: 0);
      widget.onResult?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color borderColor;
    final Color targetBgColor;
    if (_isCorrect == true) {
      borderColor = AppColors.success;
      targetBgColor = isDark
          ? AppColors.successContainerDark
          : AppColors.successContainerLight;
    } else if (_isCorrect == false) {
      borderColor = AppColors.error;
      targetBgColor =
          isDark ? AppColors.errorContainerDark : AppColors.errorContainerLight;
    } else {
      borderColor = isDark ? AppColors.darkForestBorder : AppColors.border;
      targetBgColor =
          isDark ? AppColors.darkForestSurface : AppColors.inputBackground;
    }

    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        final sineValue =
            math.sin(_shakeController.value * math.pi * 3) * (1 - _shakeController.value);
        return Transform.translate(
          offset: Offset(sineValue * 8, 0),
          child: child,
        );
      },
      child: HiCard(
        backgroundColor:
            isDark ? AppColors.darkForestCard : AppColors.cardBackground,
        borderColor: borderColor,
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header instruction badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlueLight,
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.touch_app_rounded,
                        size: 14,
                        color: AppColors.primaryBlueDark,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Sắp xếp câu tiếng Trung',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.primaryBlueDark,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Prompt sentence
            Text(
              widget.prompt,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.primaryText,
              ),
            ),
            if (widget.hint != null && widget.hint!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                widget.hint!,
                style: AppTypography.pinyin(
                  color: isDark ? Colors.white70 : AppColors.secondaryText,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),

            // Target Area with dashed lines
            CustomPaint(
              painter: _DashedBaselinePainter(
                lineColor: borderColor,
              ),
              child: AnimatedContainer(
                key: const ValueKey('word_tile_target_area'),
                duration: const Duration(milliseconds: 200),
                constraints: const BoxConstraints(minHeight: 88),
                padding: AppSpacing.edgeInsetsMd,
                decoration: BoxDecoration(
                  color: targetBgColor,
                  borderRadius: AppRadius.borderMd,
                  border: Border.all(
                    color: borderColor,
                    width: _isCorrect != null ? 1.5 : 1.0,
                  ),
                ),
                child: _selectedTokens.isEmpty
                    ? Center(
                        child: Text(
                          'Chạm vào các từ bên dưới để ghép thành câu',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.mutedText,
                          ),
                        ),
                      )
                    : Wrap(
                        spacing: AppSpacing.sm,
                        runSpacing: AppSpacing.sm,
                        children: _selectedTokens.map((token) {
                          return _buildWordChip(
                            key: ValueKey('target_chip_${token.id}_${token.text}'),
                            label: token.text,
                            isSelectedInTarget: true,
                            onTap: () => _deselectToken(token),
                          );
                        }).toList(),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Source Pool Area
            Container(
              key: const ValueKey('word_tile_source_pool'),
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                alignment: WrapAlignment.center,
                children: _allTokens.map((token) {
                  final used = _isTokenSelected(token);
                  return _buildSourcePoolSlot(token, used);
                }).toList(),
              ),
            ),

            // Feedback Banner (Correct / Incorrect + Correct Answer)
            if (_isCorrect != null) ...[
              const SizedBox(height: AppSpacing.md),
              Container(
                key: const ValueKey('word_tile_feedback_banner'),
                padding: AppSpacing.edgeInsetsMd,
                decoration: BoxDecoration(
                  color: _isCorrect!
                      ? (isDark
                          ? AppColors.successContainerDark
                          : AppColors.successContainerLight)
                      : (isDark
                          ? AppColors.errorContainerDark
                          : AppColors.errorContainerLight),
                  borderRadius: AppRadius.borderMd,
                  border: Border.all(
                    color: _isCorrect! ? AppColors.success : AppColors.error,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _isCorrect!
                          ? Icons.check_circle_rounded
                          : Icons.error_outline_rounded,
                      color: _isCorrect! ? AppColors.success : AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isCorrect!
                                ? 'Chính xác! Tuyệt vời!'
                                : 'Chưa chính xác. Hãy xem đáp án đúng bên dưới:',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: _isCorrect!
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                          ),
                          if (!_isCorrect!) ...[
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Đáp án đúng: ${widget.correctTokens.join(' ')}',
                              key: const ValueKey('word_tile_correct_answer'),
                              style: AppTypography.hanziSmall(
                                color: isDark
                                    ? Colors.white
                                    : AppColors.primaryText,
                              ).copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.lg),

            // Check Button
            HiButton(
              key: const ValueKey('word_tile_check_button'),
              text: 'Kiểm tra',
              isFullWidth: true,
              onPressed: _selectedTokens.isEmpty ? null : _handleCheck,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourcePoolSlot(WordTileToken token, bool used) {
    if (used) {
      // Placeholder outline showing where the chip came from
      return Container(
        key: ValueKey('source_placeholder_${token.id}'),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.divider.withAlpha(120),
          borderRadius: AppRadius.borderMd,
          border: Border.all(
            color: AppColors.border,
            style: BorderStyle.solid,
          ),
        ),
        child: Opacity(
          opacity: 0.0,
          child: Text(
            token.text,
            style: AppTypography.hanziSmall(),
          ),
        ),
      );
    }

    return _buildWordChip(
      key: ValueKey('source_chip_${token.id}_${token.text}'),
      label: token.text,
      isSelectedInTarget: false,
      onTap: () => _selectToken(token),
    );
  }

  Widget _buildWordChip({
    required Key key,
    required String label,
    required bool isSelectedInTarget,
    required VoidCallback onTap,
  }) {
    return Material(
      key: key,
      color: isSelectedInTarget
          ? AppColors.primaryBlueLight
          : AppColors.cardBackground,
      borderRadius: AppRadius.borderMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.borderMd,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadius.borderMd,
            border: Border.all(
              color: isSelectedInTarget
                  ? AppColors.primaryBlueDark
                  : AppColors.border,
              width: 1.5,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000),
                offset: Offset(0, 2),
                blurRadius: 2,
              ),
            ],
          ),
          child: Text(
            label,
            style: AppTypography.hanziSmall(
              color: isSelectedInTarget
                  ? AppColors.primaryBlueDark
                  : AppColors.primaryText,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

/// Draws subtle horizontal dashed guide lines inside the target answer box.
class _DashedBaselinePainter extends CustomPainter {
  final Color lineColor;

  const _DashedBaselinePainter({required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor.withAlpha(110)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    final yPositions = [size.height * 0.52, size.height * 0.88];

    for (final y in yPositions) {
      double startX = AppSpacing.md;
      final endX = size.width - AppSpacing.md;
      while (startX < endX) {
        canvas.drawLine(
          Offset(startX, y),
          Offset(math.min(startX + dashWidth, endX), y),
          paint,
        );
        startX += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBaselinePainter oldDelegate) {
    return oldDelegate.lineColor != lineColor;
  }
}
