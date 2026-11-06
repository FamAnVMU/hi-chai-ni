import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/curriculum_models.dart';
import '../../domain/models/lesson_flow_state.dart';
import '../providers/lesson_flow_providers.dart';
import '../widgets/lesson_warmup_view.dart';
import '../widgets/lesson_vocab_view.dart';
import '../widgets/lesson_grammar_view.dart';
import '../widgets/lesson_dialogue_view.dart';
import '../widgets/lesson_practice_view.dart';
import '../widgets/lesson_mastery_view.dart';
import '../widgets/ai_tutor_helper_sheet.dart';

class LessonStudyScreen extends ConsumerStatefulWidget {
  final CurriculumLesson lesson;
  final LessonStep? resumeStep;

  const LessonStudyScreen({
    super.key,
    required this.lesson,
    this.resumeStep,
  });

  @override
  ConsumerState<LessonStudyScreen> createState() => _LessonStudyScreenState();
}

class _LessonStudyScreenState extends ConsumerState<LessonStudyScreen> {
  @override
  void initState() {
    super.initState();
    // Default flow starts at LessonStep.warmup (Stage 1).
    // If the learner explicitly requested to resume from a specific step, jump to it.
    if (widget.resumeStep != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(lessonFlowNotifierProvider(widget.lesson.id).notifier).resetToStep(widget.resumeStep!);
        }
      });
    }
  }
  static const List<String> _stepTitles = [
    'Khởi động',
    'Từ vựng mới',
    'Điểm ngữ pháp',
    'Hội thoại ứng dụng',
    'Luyện tập thích ứng',
    'Đánh giá hoàn thành',
  ];

  LessonSegment? _getSegment(String type) {
    try {
      return widget.lesson.segments.firstWhere(
        (s) => s.segmentType.toLowerCase() == type.toLowerCase() ||
               (type == 'masteryCheck' && (s.segmentType == 'mastery_check' || s.segmentType == 'masteryCheck')),
      );
    } catch (_) {
      return null;
    }
  }

  void _showAiExplanationDialog(BuildContext context, String title, {String? contextDescription}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return AiTutorHelperSheet(
          topicTitle: title,
          topicContext: contextDescription ?? 'Nội dung thuộc bài học ${widget.lesson.titleVi}',
          isOnline: true,
        );
      },
    );
  }

  Widget _buildCurrentStep(int index, LessonFlowNotifier flowNotifier) {
    switch (index) {
      case 0:
        return LessonWarmupView(
          lesson: widget.lesson,
          segment: _getSegment('warmup'),
          onStart: () => flowNotifier.nextStep(),
        );
      case 1:
        return LessonVocabView(
          lesson: widget.lesson,
          segment: _getSegment('vocabulary'),
          onNext: () => flowNotifier.nextStep(),
        );
      case 2:
        return LessonGrammarView(
          lesson: widget.lesson,
          segment: _getSegment('grammar'),
          onNext: () => flowNotifier.nextStep(),
          onAskAi: () => _showAiExplanationDialog(context, 'Ngữ pháp ${widget.lesson.titleZh}'),
        );
      case 3:
        return LessonDialogueView(
          lesson: widget.lesson,
          segment: _getSegment('dialogue'),
          onNext: () => flowNotifier.nextStep(),
        );
      case 4:
        return LessonPracticeView(
          lesson: widget.lesson,
          segment: _getSegment('practice'),
          onAnswerRecorded: (qId, ans) => flowNotifier.recordAnswer(qId, ans),
          onNext: () => flowNotifier.nextStep(),
          onAskAi: () => _showAiExplanationDialog(context, 'Bài tập luyện tập'),
        );
      case 5:
        return LessonMasteryView(
          lesson: widget.lesson,
          segment: _getSegment('masteryCheck'),
          onAnswerRecorded: (qId, ans) => flowNotifier.recordAnswer(qId, ans),
          onSubmit: (questions) => flowNotifier.submitPractice(questions),
          onFinishLesson: () async {
            await flowNotifier.completeLesson();
            if (!mounted) return;
            Navigator.of(context).pop(true);
          },
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final flowState = ref.watch(lessonFlowNotifierProvider(widget.lesson.id));
    final flowNotifier = ref.read(lessonFlowNotifierProvider(widget.lesson.id).notifier);
    final theme = Theme.of(context);

    final currentIndex = flowState.currentStep.index;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.lesson.titleVi,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              '${_stepTitles[currentIndex]} (${currentIndex + 1}/6)',
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            tooltip: 'Hỏi trợ giảng AI',
            onPressed: () => _showAiExplanationDialog(context, widget.lesson.titleVi),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (currentIndex + 1) / 6,
            backgroundColor: AppColors.primaryBlueLight,
            color: AppColors.primaryBlueDark,
            minHeight: 4,
          ),
        ),
      ),
      body: _buildCurrentStep(currentIndex, flowNotifier),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          decoration: const BoxDecoration(
            color: AppColors.cardBackground,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (currentIndex > 0)
                HiButton(
                  text: 'Trước',
                  variant: HiButtonVariant.secondary,
                  size: HiButtonSize.sm,
                  onPressed: () => flowNotifier.previousStep(),
                )
              else
                const SizedBox(width: 80),
              // Step Dots
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(6, (idx) {
                  final isActive = idx == currentIndex;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 16 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.primaryBlueDark : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              if (currentIndex < 5)
                HiButton(
                  text: 'Tiếp theo',
                  variant: HiButtonVariant.primary,
                  size: HiButtonSize.sm,
                  onPressed: () => flowNotifier.nextStep(),
                )
              else
                const SizedBox(width: 80),
            ],
          ),
        ),
      ),
    );
  }
}
