import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/audio/audio_player_service.dart';
import '../../../../core/audio/tts_service.dart';
import '../../../../core/audio/unified_audio_playback_service.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/curriculum_models.dart';
import '../../domain/models/micro_card_model.dart';
import '../../domain/engine/lesson_micro_card_adapter.dart';
import 'lesson_celebration_view.dart';
import 'lesson_content_empty_state.dart';

/// Interactive micro-learning lesson player providing a continuous 5–7 minute gamified journey.
/// Features progress capsule, combo streak counter, retry queue (no heart penalty), and celebration.
class GamifiedLessonPlayer extends StatefulWidget {
  final CurriculumLesson lesson;
  final List<MicroCardModel>? initialCards;
  final void Function(String cardId, dynamic answer)? onAnswerRecorded;
  final void Function(double scorePercent)? onScoreCalculated;
  final Future<void> Function()? onFinishLesson;
  final Future<void> Function(
    double accuracy,
    List<Map<String, dynamic>> questionResults,
    int elapsedSeconds,
  )? onLessonCompleted;
  final int xpReward;
  final int currentStreakDays;
  final String? nextLessonTitle;
  final AudioPlayerService? audioPlayerOverride;
  final TtsService? ttsServiceOverride;

  const GamifiedLessonPlayer({
    super.key,
    required this.lesson,
    this.initialCards,
    this.onAnswerRecorded,
    this.onScoreCalculated,
    this.onFinishLesson,
    this.onLessonCompleted,
    this.xpReward = 25,
    this.currentStreakDays = 0,
    this.nextLessonTitle,
    this.audioPlayerOverride,
    this.ttsServiceOverride,
  });

  @override
  State<GamifiedLessonPlayer> createState() => _GamifiedLessonPlayerState();
}

class _GamifiedLessonPlayerState extends State<GamifiedLessonPlayer> {
  late final TtsService _ttsService;
  late final bool _ownsTts;
  final Stopwatch _sessionStopwatch = Stopwatch();

  late List<MicroCardModel> _activeDeck;
  final List<MicroCardModel> _retryQueue = [];
  final Map<String, int> _failureCount = {};
  final List<Map<String, dynamic>> _questionResults = [];
  final Set<String> _recordedQuestionCardIds = {};

  int _totalUniqueCards = 0;
  int _completedCount = 0;
  int _comboCount = 0;
  int _maxCombo = 0;
  int _totalAttempts = 0;
  bool _isFinished = false;
  bool _isCompleting = false;

  // Feedback banner state for current card
  bool? _isCurrentAnswerCorrect;
  String? _feedbackText;
  bool _isAnswerSubmitted = false;

  // State for Sentence Builder Card
  List<String> _assembledChips = [];
  List<String> _availableChips = [];

  // State for Matching Pairs Card
  String? _selectedHanzi;
  int? _selectedRightIndex;
  List<MapEntry<String, String>> _shuffledRightPairs = [];
  final Set<String> _matchedPairs = {};
  final Set<int> _matchedRightIndices = {};

  // State for Choice / Quiz selection
  int? _selectedOptionIndex;

  @override
  void initState() {
    super.initState();
    _ownsTts = widget.ttsServiceOverride == null;
    _ttsService = widget.ttsServiceOverride ?? DefaultTtsService();
    _sessionStopwatch.start();

    final cards = widget.initialCards ?? const LessonMicroCardAdapter().adapt(widget.lesson);
    _activeDeck = List<MicroCardModel>.from(cards);
    _totalUniqueCards = _activeDeck.length;

    _resetCardState();
  }

  @override
  void didUpdateWidget(covariant GamifiedLessonPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCards == null &&
        _totalUniqueCards == 0 &&
        widget.lesson.segments.isNotEmpty) {
      final cards = const LessonMicroCardAdapter().adapt(widget.lesson);
      if (cards.isNotEmpty) {
        setState(() {
          _activeDeck = List<MicroCardModel>.from(cards);
          _totalUniqueCards = _activeDeck.length;
          _resetCardState();
        });
      }
    }
  }

  @override
  void dispose() {
    _sessionStopwatch.stop();
    _ttsService.stop();
    if (_ownsTts) {
      _ttsService.dispose();
    }
    super.dispose();
  }

  void _resetCardState() {
    _isAnswerSubmitted = false;
    _isCurrentAnswerCorrect = null;
    _feedbackText = null;
    _selectedOptionIndex = null;
    _selectedHanzi = null;
    _selectedRightIndex = null;
    _shuffledRightPairs = [];
    _matchedPairs.clear();
    _matchedRightIndices.clear();

    if (_activeDeck.isNotEmpty) {
      final currentCard = _activeDeck.first;
      if (currentCard.type == MicroCardType.sentenceBuilder) {
        _assembledChips = [];
        _availableChips = List<String>.from(currentCard.sentenceChips);
      } else if (currentCard.type == MicroCardType.matchingPairs) {
        final entries = currentCard.pairs.entries.toList();
        _shuffledRightPairs = List<MapEntry<String, String>>.from(entries);
        if (_shuffledRightPairs.length > 1) {
          _shuffledRightPairs.shuffle(math.Random(currentCard.id.hashCode));
          final allSameOrder = List.generate(
            entries.length,
            (i) => entries[i].key == _shuffledRightPairs[i].key,
          ).every((eq) => eq);
          if (allSameOrder) {
            final first = _shuffledRightPairs.removeAt(0);
            _shuffledRightPairs.add(first);
          }
        }
      }
    }
  }

  Future<void> _playCardAudio(MicroCardModel card) async {
    final audioUrl = card.audioUrl?.trim() ?? '';
    final fallbackText = (card.audioText ?? card.hanzi ?? '').trim();

    if (audioUrl.isNotEmpty) {
      try {
        if (widget.audioPlayerOverride != null) {
          await widget.audioPlayerOverride!.play(audioUrl);
        } else {
          await UnifiedAudioPlaybackService.instance.playAudio(audioUrl);
        }
        return;
      } catch (_) {
        // Fallback immediately to TTS if file missing / playback error
      }
    }

    if (fallbackText.isNotEmpty) {
      await _speak(fallbackText);
    }
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _ttsService.speak(text, language: 'zh-CN');
    } catch (_) {}
  }

  void _handleAnswer(bool isCorrect, dynamic answerPayload) {
    if (_isAnswerSubmitted) return;

    final currentCard = _activeDeck.first;
    _totalAttempts++;
    widget.onAnswerRecorded?.call(currentCard.id, answerPayload);

    // Record card outcome once for downstream SRS/Pipeline evaluation
    if (currentCard.type != MicroCardType.reveal &&
        !_recordedQuestionCardIds.contains(currentCard.id)) {
      _recordedQuestionCardIds.add(currentCard.id);
      _questionResults.add({
        'id': currentCard.id,
        'target_word': currentCard.hanzi,
        'prompt': currentCard.prompt ?? currentCard.hanzi ?? '',
        'user_answer': answerPayload?.toString(),
        'selected_option': answerPayload?.toString(),
        'is_correct': isCorrect,
        'score': isCorrect ? 1.0 : 0.0,
      });
    } else if (!isCorrect && currentCard.type != MicroCardType.reveal) {
      // Update existing entry if retried and failed
      final idx = _questionResults.indexWhere((r) => r['id'] == currentCard.id);
      if (idx != -1) {
        _questionResults[idx]['is_correct'] = false;
        _questionResults[idx]['score'] = 0.0;
      }
    }

    setState(() {
      _isAnswerSubmitted = true;
      _isCurrentAnswerCorrect = isCorrect;

      if (isCorrect) {
        _comboCount++;
        if (_comboCount > _maxCombo) {
          _maxCombo = _comboCount;
        }
        HapticFeedback.lightImpact();
        _feedbackText = 'Chính xác! Tiếp tục phát huy.';
      } else {
        _comboCount = 0;
        HapticFeedback.mediumImpact();

        final cardFails = (_failureCount[currentCard.id] ?? 0) + 1;
        _failureCount[currentCard.id] = cardFails;

        // Add to retry queue if under retry limit (max 3 times to prevent infinite loops)
        if (cardFails < 3) {
          _retryQueue.add(currentCard);
        }

        if (currentCard.type == MicroCardType.audioChoice) {
          _feedbackText = 'Chưa đúng. Đáp án là: "${currentCard.hanzi}" (${currentCard.meaning ?? ''})';
        } else if (currentCard.type == MicroCardType.sentenceBuilder) {
          _feedbackText = 'Chưa đúng. Câu chuẩn là: "${currentCard.targetSentence ?? ''}"';
        } else if (currentCard.type == MicroCardType.miniQuiz) {
          final correctOpt = (currentCard.correctIndex != null &&
                  currentCard.correctIndex! < currentCard.options.length)
              ? currentCard.options[currentCard.correctIndex!]
              : '';
          _feedbackText = 'Chưa đúng. Đáp án: "$correctOpt"';
        } else {
          _feedbackText = 'Chưa chính xác. Đừng lo, thẻ này sẽ quay lại ở cuối bài!';
        }
      }
    });
  }

  void _advanceToNextCard() {
    if (_activeDeck.isEmpty) return;

    _activeDeck.removeAt(0);
    if (_isCurrentAnswerCorrect == true) {
      _completedCount++;
    }

    // Refill activeDeck from retryQueue if activeDeck is now empty
    if (_activeDeck.isEmpty && _retryQueue.isNotEmpty) {
      _activeDeck.addAll(_retryQueue);
      _retryQueue.clear();
    }

    if (_activeDeck.isEmpty) {
      _sessionStopwatch.stop();
      setState(() {
        _isFinished = true;
      });
    } else {
      setState(() {
        _resetCardState();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_totalUniqueCards == 0) {
      return LessonContentEmptyState(
        title: 'Đang chuẩn bị thẻ học vi mô',
        message: 'Nội dung thẻ học vi mô cho bài học này đang được hoàn thiện.',
        buttonText: 'Hoàn thành bài học',
        onAction: widget.onFinishLesson,
      );
    }

    if (_isFinished) {
      final firstAttemptCorrect = (_totalUniqueCards - _failureCount.length).clamp(0, _totalUniqueCards);
      final empiricalAccuracy = _totalUniqueCards > 0
          ? (firstAttemptCorrect / _totalUniqueCards).clamp(0.0, 1.0)
          : 0.0;
      final elapsedSeconds = _sessionStopwatch.elapsed.inSeconds.clamp(1, 7200);

      return LessonCelebrationView(
        lesson: widget.lesson,
        xpGained: empiricalAccuracy >= 0.8 ? widget.xpReward : 0,
        streakDays: widget.currentStreakDays,
        nextLessonTitle: widget.nextLessonTitle,
        totalCards: _completedCount,
        maxCombo: _maxCombo,
        totalAttempts: _totalAttempts,
        accuracyRate: empiricalAccuracy,
        isSubmitting: _isCompleting,
        onContinue: _isCompleting
            ? null
            : () async {
                setState(() => _isCompleting = true);
                try {
                  widget.onScoreCalculated?.call(empiricalAccuracy);
                  if (widget.onLessonCompleted != null) {
                    await widget.onLessonCompleted!(
                      empiricalAccuracy,
                      List<Map<String, dynamic>>.from(_questionResults),
                      elapsedSeconds,
                    );
                  } else if (widget.onFinishLesson != null) {
                    await widget.onFinishLesson!();
                  } else if (mounted) {
                    Navigator.of(context).pop(true);
                  }
                } finally {
                  if (mounted) {
                    setState(() => _isCompleting = false);
                  }
                }
              },
      );
    }

    final currentCard = _activeDeck.first;
    final progressValue = _totalUniqueCards > 0
        ? (_completedCount / _totalUniqueCards).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        // Top Header: Capsule Progress Bar & Combo Badge
        _buildHeader(progressValue),

        // Main Card Surface
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: _buildCardContent(currentCard),
          ),
        ),

        // Bottom Feedback & Action Banner
        _buildBottomBanner(currentCard),
      ],
    );
  }

  Widget _buildHeader(double progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      child: Column(
        children: [
          Row(
            children: [
              // Progress Capsule Bar
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.border.withAlpha(120),
                    color: AppColors.success,
                  ),
                ),
              ),

              // Combo Streak Badge
              if (_comboCount >= 2) ...[
                const SizedBox(width: AppSpacing.sm),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9800).withAlpha(100),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 12)),
                      const SizedBox(width: 2),
                      Text(
                        'Combo $_comboCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardContent(MicroCardModel card) {
    switch (card.type) {
      case MicroCardType.reveal:
        return _buildRevealCard(card);
      case MicroCardType.audioChoice:
        return _buildAudioChoiceCard(card);
      case MicroCardType.sentenceBuilder:
        return _buildSentenceBuilderCard(card);
      case MicroCardType.matchingPairs:
        return _buildMatchingPairsCard(card);
      case MicroCardType.miniQuiz:
        return _buildMiniQuizCard(card);
    }
  }

  // --- CARD 1: REVEAL CARD ---
  Widget _buildRevealCard(MicroCardModel card) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primaryBlueLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            '🌟 TỪ MỚI CỐT LÕI',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryBlueDark),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Hanzi Large (scaled down safely for multi-character words and large font scaling)
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            card.hanzi ?? '',
            style: const TextStyle(
              fontSize: 54,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryText,
              fontFamilyFallback: ['Noto Sans SC', 'Heiti SC'],
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),

        // Pinyin & Han-Viet
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              card.pinyin ?? '',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlueDark,
              ),
            ),
            if (card.hanViet != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.inputBackground,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '[${card.hanViet}]',
                  style: const TextStyle(fontSize: 13, color: AppColors.secondaryText),
                ),
              ),
            ],
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.volume_up_rounded, color: AppColors.primaryBlueDark, size: 24),
              onPressed: () => _playCardAudio(card),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),

        // Meaning Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nghĩa tiếng Việt:',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                card.meaning ?? '',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.primaryText),
              ),
              if (card.explanation != null) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Text(
                  'Ví dụ:',
                  style: theme.textTheme.labelSmall?.copyWith(color: AppColors.secondaryText),
                ),
                Text(
                  card.explanation!,
                  style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // --- CARD 2: AUDIO CHOICE CARD ---
  Widget _buildAudioChoiceCard(MicroCardModel card) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: AppSpacing.sm),
        Text(
          card.prompt ?? 'Nghe phát âm và chọn chữ Hán chính xác:',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryText),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),

        // Large Audio Button
        GestureDetector(
          onTap: () => _playCardAudio(card),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primaryBlueLight,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withAlpha(40),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.volume_up_rounded,
              size: 38,
              color: AppColors.primaryBlueDark,
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Chạm để nghe lại',
          style: TextStyle(fontSize: 11, color: AppColors.secondaryText),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Option Buttons
        ...List.generate(card.options.length, (idx) {
          final opt = card.options[idx];
          final isSelected = _selectedOptionIndex == idx;
          final isCorrect = card.correctIndex == idx;

          Color bgColor = AppColors.cardBackground;
          Color borderColor = AppColors.border;
          Color textColor = AppColors.primaryText;

          if (_isAnswerSubmitted) {
            if (isCorrect) {
              bgColor = AppColors.successContainerLight;
              borderColor = AppColors.success;
              textColor = AppColors.success;
            } else if (isSelected) {
              bgColor = AppColors.errorContainerLight;
              borderColor = AppColors.error;
              textColor = AppColors.error;
            }
          } else if (isSelected) {
            bgColor = AppColors.primaryBlueLight;
            borderColor = AppColors.primaryBlueDark;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            width: double.infinity,
            child: InkWell(
              onTap: _isAnswerSubmitted
                  ? null
                  : () {
                      setState(() {
                        _selectedOptionIndex = idx;
                      });
                      _handleAnswer(isCorrect, opt);
                    },
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: borderColor, width: isSelected || (_isAnswerSubmitted && isCorrect) ? 2 : 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    if (_isAnswerSubmitted && isCorrect)
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
                    else if (_isAnswerSubmitted && isSelected && !isCorrect)
                      const Icon(Icons.cancel_rounded, color: AppColors.error, size: 20),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  // --- CARD 3: SENTENCE BUILDER CARD ---
  Widget _buildSentenceBuilderCard(MicroCardModel card) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          card.prompt ?? 'Sắp xếp các từ thành câu hoàn chỉnh:',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryText),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),

        // Assembled Sentence Slot
        Container(
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.inputBackground,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: _isAnswerSubmitted
                  ? (_isCurrentAnswerCorrect == true ? AppColors.success : AppColors.error)
                  : AppColors.primaryBlueDark.withAlpha(60),
              width: 1.5,
            ),
          ),
          child: _assembledChips.isEmpty
              ? const Center(
                  child: Text(
                    'Chạm vào các từ bên dưới để ghép câu',
                    style: TextStyle(color: AppColors.secondaryText, fontSize: 13),
                  ),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _assembledChips.map((chip) {
                    return InkWell(
                      onTap: _isAnswerSubmitted
                          ? null
                          : () {
                              setState(() {
                                _assembledChips.remove(chip);
                                _availableChips.add(chip);
                              });
                            },
                      child: Chip(
                        label: Text(
                          chip,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        backgroundColor: AppColors.primaryBlueLight,
                        deleteIcon: _isAnswerSubmitted ? null : const Icon(Icons.close_rounded, size: 14),
                        onDeleted: _isAnswerSubmitted
                            ? null
                            : () {
                                setState(() {
                                  _assembledChips.remove(chip);
                                  _availableChips.add(chip);
                                });
                              },
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: AppSpacing.lg),

        // Available Chips Bank
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: _availableChips.map((chip) {
            return ActionChip(
              label: Text(
                chip,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              backgroundColor: AppColors.cardBackground,
              side: const BorderSide(color: AppColors.border),
              onPressed: _isAnswerSubmitted
                  ? null
                  : () {
                      setState(() {
                        _availableChips.remove(chip);
                        _assembledChips.add(chip);
                      });
                    },
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.xl),

        // Check Button for Sentence Builder
        if (!_isAnswerSubmitted)
          HiButton(
            text: 'Kiểm tra',
            variant: HiButtonVariant.primary,
            onPressed: _assembledChips.isEmpty
                ? null
                : () {
                    final punctRegex = RegExp(r'[\s。，！？、；：“”‘’（）\(\)\[\]《》〈〉\.,!?;:"\x27]');
                    final assembledStr = _assembledChips.join('').replaceAll(punctRegex, '');
                    final targetStr = (card.targetSentence ?? '').replaceAll(punctRegex, '');
                    final isCorrect = assembledStr == targetStr;
                    _handleAnswer(isCorrect, assembledStr);
                  },
          ),
      ],
    );
  }

  // --- CARD 4: MATCHING PAIRS CARD ---
  Widget _buildMatchingPairsCard(MicroCardModel card) {
    final pairs = card.pairs;
    final hanzis = pairs.keys.toList();
    final rightEntries = _shuffledRightPairs.isNotEmpty
        ? _shuffledRightPairs
        : pairs.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          card.prompt ?? 'Chạm để nối chữ Hán với nghĩa tiếng Việt tương ứng:',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primaryText),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.md),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Column: Hanzi
            Expanded(
              child: Column(
                children: hanzis.map((hz) {
                  final isMatched = _matchedPairs.contains(hz);
                  final isSelected = _selectedHanzi == hz;

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    width: double.infinity,
                    child: InkWell(
                      onTap: isMatched || _isAnswerSubmitted
                          ? null
                          : () {
                              setState(() {
                                _selectedHanzi = hz;
                                _checkMatchingAttempt(card, rightEntries);
                              });
                            },
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isMatched
                              ? AppColors.successContainerLight
                              : (isSelected ? AppColors.primaryBlueLight : AppColors.cardBackground),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: isMatched
                                ? AppColors.success
                                : (isSelected ? AppColors.primaryBlueDark : AppColors.border),
                            width: isSelected || isMatched ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          hz,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isMatched ? AppColors.success : AppColors.primaryText,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // Right Column: Meanings (shuffled independently by index to prevent duplicate-meaning deadlocks)
            Expanded(
              child: Column(
                children: List.generate(rightEntries.length, (rightIdx) {
                  final entry = rightEntries[rightIdx];
                  final isMatched = _matchedRightIndices.contains(rightIdx);
                  final isSelected = _selectedRightIndex == rightIdx;

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    width: double.infinity,
                    child: InkWell(
                      onTap: isMatched || _isAnswerSubmitted
                          ? null
                          : () {
                              setState(() {
                                _selectedRightIndex = rightIdx;
                                _checkMatchingAttempt(card, rightEntries);
                              });
                            },
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                        decoration: BoxDecoration(
                          color: isMatched
                              ? AppColors.successContainerLight
                              : (isSelected ? AppColors.primaryBlueLight : AppColors.cardBackground),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: isMatched
                                ? AppColors.success
                                : (isSelected ? AppColors.primaryBlueDark : AppColors.border),
                            width: isSelected || isMatched ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isMatched ? AppColors.success : AppColors.primaryText,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _checkMatchingAttempt(
    MicroCardModel card,
    List<MapEntry<String, String>> rightEntries,
  ) {
    if (_selectedHanzi == null || _selectedRightIndex == null) return;
    if (_selectedRightIndex! < 0 || _selectedRightIndex! >= rightEntries.length) return;

    final chosenHanzi = _selectedHanzi!;
    final chosenRightIdx = _selectedRightIndex!;
    final rightEntry = rightEntries[chosenRightIdx];
    final expectedMeaning = card.pairs[chosenHanzi];

    if (expectedMeaning != null && rightEntry.value == expectedMeaning) {
      _matchedPairs.add(chosenHanzi);
      _matchedRightIndices.add(chosenRightIdx);
      _selectedHanzi = null;
      _selectedRightIndex = null;
      HapticFeedback.lightImpact();

      if (_matchedPairs.length >= card.pairs.length) {
        _handleAnswer(true, 'matched_all');
      }
    } else {
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _selectedHanzi = null;
            _selectedRightIndex = null;
          });
        }
      });
    }
  }

  // --- CARD 5: MINI QUIZ CARD ---
  Widget _buildMiniQuizCard(MicroCardModel card) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          card.prompt ?? '',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primaryText),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.lg),

        ...List.generate(card.options.length, (idx) {
          final opt = card.options[idx];
          final isSelected = _selectedOptionIndex == idx;
          final isCorrect = card.correctIndex == idx;

          Color bgColor = AppColors.cardBackground;
          Color borderColor = AppColors.border;
          Color textColor = AppColors.primaryText;

          if (_isAnswerSubmitted) {
            if (isCorrect) {
              bgColor = AppColors.successContainerLight;
              borderColor = AppColors.success;
              textColor = AppColors.success;
            } else if (isSelected) {
              bgColor = AppColors.errorContainerLight;
              borderColor = AppColors.error;
              textColor = AppColors.error;
            }
          } else if (isSelected) {
            bgColor = AppColors.primaryBlueLight;
            borderColor = AppColors.primaryBlueDark;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: InkWell(
              onTap: _isAnswerSubmitted
                  ? null
                  : () {
                      setState(() {
                        _selectedOptionIndex = idx;
                      });
                      _handleAnswer(isCorrect, opt);
                    },
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: borderColor, width: isSelected || (_isAnswerSubmitted && isCorrect) ? 2 : 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected ? AppColors.primaryBlueDark : AppColors.inputBackground,
                      ),
                      child: Center(
                        child: Text(
                          String.fromCharCode(65 + idx),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : AppColors.secondaryText,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        opt,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ),
                    if (_isAnswerSubmitted && isCorrect)
                      const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
                    else if (_isAnswerSubmitted && isSelected && !isCorrect)
                      const Icon(Icons.cancel_rounded, color: AppColors.error, size: 20),
                  ],
                ),
              ),
            ),
          );
        }),

        if (_isAnswerSubmitted && card.explanation != null) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.primaryBlueLight.withAlpha(120),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.primaryBlueDark),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    card.explanation!,
                    style: const TextStyle(fontSize: 13, color: AppColors.primaryText),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- BOTTOM BANNER & ACTION ---
  Widget _buildBottomBanner(MicroCardModel currentCard) {
    if (currentCard.type == MicroCardType.reveal) {
      return SafeArea(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: const BoxDecoration(
            color: AppColors.cardBackground,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: HiButton(
            text: 'Tiếp tục',
            variant: HiButtonVariant.primary,
            onPressed: () {
              _handleAnswer(true, 'reveal_viewed');
              _advanceToNextCard();
            },
          ),
        ),
      );
    }

    if (!_isAnswerSubmitted) {
      return const SizedBox.shrink();
    }

    final isCorrect = _isCurrentAnswerCorrect == true;
    final bannerBg = isCorrect ? AppColors.successContainerLight : AppColors.errorContainerLight;
    final bannerBorder = isCorrect ? AppColors.success : AppColors.error;

    return SafeArea(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: bannerBg,
          border: Border(top: BorderSide(color: bannerBorder, width: 2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  isCorrect ? Icons.check_circle_rounded : Icons.info_rounded,
                  color: isCorrect ? AppColors.success : AppColors.error,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isCorrect ? 'Tuyệt vời!' : 'Chưa chính xác',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isCorrect ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
            if (_feedbackText != null) ...[
              const SizedBox(height: 4),
              Text(
                _feedbackText!,
                style: const TextStyle(fontSize: 13, color: AppColors.primaryText),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            HiButton(
              text: 'Tiếp tục',
              variant: isCorrect ? HiButtonVariant.primary : HiButtonVariant.secondary,
              onPressed: _advanceToNextCard,
            ),
          ],
        ),
      ),
    );
  }
}
