import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/theme.dart';

/// Represents a single Hanzi <-> Vietnamese meaning pair for [InteractiveMatchingPairs].
class MatchingPairItem {
  final String id;
  final String hanzi;
  final String meaningVi;
  final String? pinyin;

  const MatchingPairItem({
    required this.id,
    required this.hanzi,
    required this.meaningVi,
    this.pinyin,
  });
}

/// Gamified 4x2 matching pairs micro-widget inspired by Duolingo & HelloChinese.
///
/// Displays up to 4 Chinese words and 4 shuffled Vietnamese meanings.
/// Tapping a matching pair highlights them in green and fades them out;
/// tapping a mismatched pair shakes and flashes red before resetting.
class InteractiveMatchingPairs extends StatefulWidget {
  final List<MatchingPairItem> pairs;
  final VoidCallback? onCompleted;
  final bool shuffle;
  final String title;

  const InteractiveMatchingPairs({
    super.key,
    required this.pairs,
    this.onCompleted,
    this.shuffle = true,
    this.title = 'Ghép cặp từ vựng tương ứng',
  });

  /// Convenience constructor from a simple `Hanzi -> Meaning` map.
  factory InteractiveMatchingPairs.fromMap({
    Key? key,
    required Map<String, String> pairsMap,
    VoidCallback? onCompleted,
    bool shuffle = true,
  }) {
    final entries = pairsMap.entries.toList();
    return InteractiveMatchingPairs(
      key: key,
      pairs: List.generate(
        entries.length,
        (i) => MatchingPairItem(
          id: 'pair_$i',
          hanzi: entries[i].key,
          meaningVi: entries[i].value,
        ),
      ),
      onCompleted: onCompleted,
      shuffle: shuffle,
    );
  }

  @override
  State<InteractiveMatchingPairs> createState() =>
      _InteractiveMatchingPairsState();
}

class _InteractiveMatchingPairsState extends State<InteractiveMatchingPairs>
    with SingleTickerProviderStateMixin {
  late List<MatchingPairItem> _hanziColumn;
  late List<MatchingPairItem> _meaningColumn;

  String? _selectedHanziId;
  String? _selectedMeaningId;
  String? _mismatchHanziId;
  String? _mismatchMeaningId;
  final Set<String> _matchedIds = {};

  Timer? _mismatchResetTimer;
  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _prepareColumns();
  }

  @override
  void didUpdateWidget(covariant InteractiveMatchingPairs oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pairs != widget.pairs) {
      _mismatchResetTimer?.cancel();
      _selectedHanziId = null;
      _selectedMeaningId = null;
      _mismatchHanziId = null;
      _mismatchMeaningId = null;
      _matchedIds.clear();
      _prepareColumns();
    }
  }

  void _prepareColumns() {
    final activePairs = widget.pairs.take(4).toList();
    _hanziColumn = List<MatchingPairItem>.from(activePairs);
    _meaningColumn = List<MatchingPairItem>.from(activePairs);

    if (widget.shuffle && _meaningColumn.length > 1) {
      _meaningColumn.shuffle(math.Random(42));
      // Ensure shuffled order differs from original when possible
      if (_meaningColumn.every((item) =>
          _meaningColumn.indexOf(item) == _hanziColumn.indexOf(item))) {
        final first = _meaningColumn.removeAt(0);
        _meaningColumn.add(first);
      }
    }
  }

  @override
  void dispose() {
    _mismatchResetTimer?.cancel();
    _shakeController.dispose();
    super.dispose();
  }

  void _onTapHanzi(MatchingPairItem item) {
    if (_matchedIds.contains(item.id)) return;
    _clearMismatchImmediately();
    HapticFeedback.selectionClick();

    setState(() {
      if (_selectedHanziId == item.id) {
        _selectedHanziId = null;
      } else {
        _selectedHanziId = item.id;
      }
    });

    _checkPairIfReady();
  }

  void _onTapMeaning(MatchingPairItem item) {
    if (_matchedIds.contains(item.id)) return;
    _clearMismatchImmediately();
    HapticFeedback.selectionClick();

    setState(() {
      if (_selectedMeaningId == item.id) {
        _selectedMeaningId = null;
      } else {
        _selectedMeaningId = item.id;
      }
    });

    _checkPairIfReady();
  }

  void _clearMismatchImmediately() {
    if (_mismatchHanziId != null || _mismatchMeaningId != null) {
      _mismatchResetTimer?.cancel();
      _mismatchHanziId = null;
      _mismatchMeaningId = null;
    }
  }

  void _checkPairIfReady() {
    final hanziId = _selectedHanziId;
    final meaningId = _selectedMeaningId;
    if (hanziId == null || meaningId == null) return;

    if (hanziId == meaningId) {
      // Correct match
      SystemSound.play(SystemSoundType.click);
      HapticFeedback.lightImpact();

      setState(() {
        _matchedIds.add(hanziId);
        _selectedHanziId = null;
        _selectedMeaningId = null;
      });

      if (_matchedIds.length == _hanziColumn.length && _hanziColumn.isNotEmpty) {
        widget.onCompleted?.call();
      }
    } else {
      // Mismatch -> shake & flash red, then recover
      HapticFeedback.mediumImpact();
      setState(() {
        _mismatchHanziId = hanziId;
        _mismatchMeaningId = meaningId;
        _selectedHanziId = null;
        _selectedMeaningId = null;
      });
      _shakeController.forward(from: 0);

      _mismatchResetTimer?.cancel();
      _mismatchResetTimer = Timer(const Duration(milliseconds: 450), () {
        if (mounted) {
          setState(() {
            _mismatchHanziId = null;
            _mismatchMeaningId = null;
          });
        }
      });
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
          // Header row with title & progress badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.primaryText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryBlueLight,
                  borderRadius: AppRadius.borderSm,
                ),
                child: Text(
                  '${_matchedIds.length}/${_hanziColumn.length} cặp',
                  key: const ValueKey('matching_pairs_progress'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.primaryBlueDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // 2-Column Grid of 4 Hanzi cards (left) and 4 Vietnamese meaning cards (right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: Hanzi
              Expanded(
                child: Column(
                  children: _hanziColumn.map((item) {
                    final isMatched = _matchedIds.contains(item.id);
                    final isSelected = _selectedHanziId == item.id;
                    final isMismatch = _mismatchHanziId == item.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _buildPairTile(
                        key: ValueKey('hanzi_tile_${item.id}'),
                        text: item.hanzi,
                        subtitle: item.pinyin,
                        isHanzi: true,
                        isMatched: isMatched,
                        isSelected: isSelected,
                        isMismatch: isMismatch,
                        onTap: () => _onTapHanzi(item),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Right column: Vietnamese Meanings
              Expanded(
                child: Column(
                  children: _meaningColumn.map((item) {
                    final isMatched = _matchedIds.contains(item.id);
                    final isSelected = _selectedMeaningId == item.id;
                    final isMismatch = _mismatchMeaningId == item.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _buildPairTile(
                        key: ValueKey('meaning_tile_${item.id}'),
                        text: item.meaningVi,
                        isHanzi: false,
                        isMatched: isMatched,
                        isSelected: isSelected,
                        isMismatch: isMismatch,
                        onTap: () => _onTapMeaning(item),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPairTile({
    required Key key,
    required String text,
    String? subtitle,
    required bool isHanzi,
    required bool isMatched,
    required bool isSelected,
    required bool isMismatch,
    required VoidCallback onTap,
  }) {
    final Color bgColor;
    final Color borderColor;
    final Color textColor;

    if (isMatched) {
      bgColor = AppColors.successContainerLight;
      borderColor = AppColors.success;
      textColor = AppColors.success;
    } else if (isMismatch) {
      bgColor = AppColors.errorContainerLight;
      borderColor = AppColors.error;
      textColor = AppColors.error;
    } else if (isSelected) {
      bgColor = AppColors.primaryBlueLight;
      borderColor = AppColors.primaryBlueDark;
      textColor = AppColors.primaryBlueDark;
    } else {
      bgColor = AppColors.cardBackground;
      borderColor = AppColors.border;
      textColor = AppColors.primaryText;
    }

    Widget tile = IgnorePointer(
      ignoring: isMatched,
      child: AnimatedOpacity(
        key: key,
        duration: const Duration(milliseconds: 250),
        opacity: isMatched ? 0.25 : 1.0,
        child: Material(
          color: bgColor,
          borderRadius: AppRadius.borderMd,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.borderMd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints: const BoxConstraints(minHeight: 64),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadius.borderMd,
                border: Border.all(
                  color: borderColor,
                  width: (isSelected || isMismatch || isMatched) ? 2.0 : 1.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    text,
                    textAlign: TextAlign.center,
                    style: isHanzi
                        ? AppTypography.hanziMedium(color: textColor)
                        : AppTypography.vietnameseMeaning(color: textColor)
                            .copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: AppTypography.pinyin(
                        color: textColor.withAlpha(200),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (isMismatch) {
      return AnimatedBuilder(
        animation: _shakeController,
        builder: (context, child) {
          final offset = math.sin(_shakeController.value * math.pi * 3) *
              (1 - _shakeController.value) *
              6;
          return Transform.translate(
            offset: Offset(offset, 0),
            child: child,
          );
        },
        child: tile,
      );
    }

    return tile;
  }
}
