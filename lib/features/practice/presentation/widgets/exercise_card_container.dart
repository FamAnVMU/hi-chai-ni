import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/audio/tts_service.dart';
import '../../../../core/audio/unified_audio_playback_service.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/practice_models.dart';

/// Reusable outer shell displaying prompt, stimulus, audio button, and feedback
class ExerciseCardContainer extends StatelessWidget {
  final ExerciseDefinition definition;
  final ScoringResult? result;
  final Widget child;

  const ExerciseCardContainer({
    super.key,
    required this.definition,
    this.result,
    required this.child,
  });

  Future<void> _playStimulusAudio(BuildContext context) async {
    final uri = definition.stimulusAudioUri;
    if (uri != null && uri.isNotEmpty) {
      try {
        if (uri.startsWith('assets/')) {
          await rootBundle.load(uri);
        }
        await UnifiedAudioPlaybackService.instance.playAudio(uri);
        return;
      } catch (_) {}
    }

    final text = (definition.stimulus ??
            definition.targetSentence ??
            definition.sentenceWithBlank ??
            definition.prompt)
        .replaceAll('___', '')
        .trim();
    if (text.isEmpty) return;

    try {
      await DefaultTtsService().speak(text, language: 'zh-CN');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể phát âm thanh lúc này.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.hiCardSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: context.hiBorderColor),
        boxShadow: AppElevation.shadowLow(theme.brightness),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: Type badge & HSK
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: context.hiAccentBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  definition.type.displayName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.hiAccentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: context.hiInputSurface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  border: Border.all(color: context.hiBorderColor),
                ),
                child: Text(
                  'HSK ${definition.hskLevel}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: context.hiSecondaryText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Prompt
          Text(
            definition.prompt,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: context.hiPrimaryText,
            ),
          ),

          // Stimulus (if any)
          if (definition.stimulus != null && definition.stimulus!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: context.hiInputSurface,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: context.hiBorderColor),
              ),
              child: Column(
                children: [
                  Text(
                    definition.stimulus!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                      color: context.hiPrimaryText,
                    ),
                  ),
                  if (definition.stimulusPinyin != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      definition.stimulusPinyin!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.hiAccentColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if ((definition.stimulusAudioUri != null &&
                          definition.stimulusAudioUri!.isNotEmpty) ||
                      definition.skill == 'listening') ...[
                    const SizedBox(height: AppSpacing.xs),
                    TextButton.icon(
                      icon: const Icon(Icons.volume_up_rounded, size: 18),
                      label: const Text('Nghe phát âm'),
                      onPressed: () => _playStimulusAudio(context),
                    ),
                  ],
                ],
              ),
            ),
          ] else if (definition.stimulusAudioUri != null &&
              definition.stimulusAudioUri!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton.icon(
              icon: const Icon(Icons.volume_up_rounded, size: 18),
              label: const Text('Nghe câu hỏi âm thanh'),
              onPressed: () => _playStimulusAudio(context),
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          // Core exercise interactive content
          child,

          // Evaluation Result Banner (if submitted)
          if (result != null) ...[
            const SizedBox(height: AppSpacing.md),
            _buildResultBanner(context, result!),
          ],
        ],
      ),
    );
  }

  Widget _buildResultBanner(BuildContext context, ScoringResult res) {
    final theme = Theme.of(context);
    final isCorrect = res.isCorrect;
    final needsReview = res.needsHumanReview;

    final bannerColor = isCorrect
        ? context.hiSuccessBg
        : (needsReview ? context.hiWarningBg : context.hiErrorBg);
    final borderColor = isCorrect
        ? context.hiSuccessFg
        : (needsReview ? context.hiWarningFg : context.hiErrorFg);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: bannerColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isCorrect
                        ? Icons.check_circle_rounded
                        : (needsReview ? Icons.help_outline_rounded : Icons.cancel_rounded),
                    size: 18,
                    color: borderColor,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    isCorrect
                        ? 'Chính xác (${(res.score * 100).toInt()}%)'
                        : (needsReview ? 'Cần xem lại kết quả' : 'Chưa đúng'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: borderColor,
                    ),
                  ),
                ],
              ),
              if (res.evaluatorType == EvaluatorType.rubric)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: borderColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    'Độ tin cậy: ${(res.confidence * 100).toInt()}%',
                    style: theme.textTheme.labelSmall?.copyWith(fontSize: 10, color: borderColor),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            res.feedbackVi,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.hiPrimaryText,
            ),
          ),
        ],
      ),
    );
  }
}
