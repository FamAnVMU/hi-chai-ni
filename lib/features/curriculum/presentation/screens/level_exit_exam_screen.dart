import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../providers/curriculum_providers.dart';

class LevelExitExamScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? examData;
  final int level;

  const LevelExitExamScreen({
    super.key,
    this.examData,
    this.level = 1,
  });

  @override
  ConsumerState<LevelExitExamScreen> createState() => _LevelExitExamScreenState();
}

class _LevelExitExamScreenState extends ConsumerState<LevelExitExamScreen> {
  final Map<String, String> _userAnswers = {};
  bool _isSubmitted = false;
  int _score = 0;
  int _totalScore = 200;
  int _passingScore = 120;
  int _listenScore = 0;
  int _readScore = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.examData != null) {
      return _buildExamContent(widget.examData!);
    }

    final examAsync = ref.watch(exitExamProvider(widget.level));

    return examAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Đang tải đề thi...')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        appBar: AppBar(title: const Text('Đề thi')),
        body: Center(child: Text('Không thể tải đề thi: $err')),
      ),
      data: (data) {
        if (data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Đề thi tốt nghiệp')),
            body: const Center(child: Text('Chưa có đề thi cho cấp độ này.')),
          );
        }

        // Parse content_json if needed
        Map<String, dynamic> resolved = Map<String, dynamic>.from(data);
        if (resolved['content_json'] is String) {
          try {
            final parsed = json.decode(resolved['content_json'] as String);
            if (parsed is Map<String, dynamic>) {
              resolved.addAll(parsed);
            }
          } catch (_) {}
        }

        return _buildExamContent(resolved);
      },
    );
  }

  Widget _buildExamContent(Map<String, dynamic> exam) {
    final theme = Theme.of(context);
    final title = (exam['title'] ?? 'Đề thi tốt nghiệp HSK 1 Chuẩn Quốc Tế') as String;
    final duration = (exam['duration_minutes'] as num?)?.toInt() ?? 35;
    _passingScore = (exam['passing_score'] as num?)?.toInt() ?? 120;
    _totalScore = (exam['total_score'] as num?)?.toInt() ?? 200;

    final rawQuestions = (exam['questions'] as List<dynamic>?) ?? [];
    final questions = rawQuestions.map((q) => q as Map<String, dynamic>).toList();

    final listeningQuestions = questions.where((q) => q['section'] == 'listening').toList();
    final readingQuestions = questions.where((q) => q['section'] == 'reading').toList();

    if (_isSubmitted) {
      final isPassed = _score >= _passingScore;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Kết Quả Thi'),
          automaticallyImplyLeading: false,
        ),
        body: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: isPassed ? AppColors.limeGreen.withAlpha(30) : AppColors.errorLight.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPassed ? Icons.workspace_premium_rounded : Icons.highlight_off_rounded,
                    size: 72,
                    color: isPassed ? AppColors.limeGreenDark : AppColors.errorLight,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Kết quả thi tốt nghiệp HSK ${widget.level}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isPassed ? AppColors.limeGreenDark : AppColors.errorLight,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isPassed ? 'XUẤT SẮC ĐẠT CHUẨN ĐẦU RA!' : 'CHƯA ĐẠT ĐIỂM CHUẨN',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              HiCard(
                child: Column(
                  children: [
                    _buildScoreRow('Tổng điểm đạt được', '$_score / $_totalScore điểm', isHighlight: true),
                    const Divider(),
                    _buildScoreRow('Phần 1: Nghe hiểu', '$_listenScore / 100 điểm'),
                    const Divider(),
                    _buildScoreRow('Phần 2: Đọc hiểu', '$_readScore / 100 điểm'),
                    const Divider(),
                    _buildScoreRow('Điểm chuẩn đạt HSK 1', '$_passingScore điểm'),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              HiButton(
                text: 'Trở về trang giáo trình',
                isFullWidth: true,
                variant: HiButtonVariant.primary,
                size: HiButtonSize.lg,
                onPressed: () => Navigator.of(context).pop(isPassed),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppSpacing.md),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.limeGreenDark.withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: AppColors.limeGreenDark),
                const SizedBox(width: 4),
                Text(
                  '$duration:00',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.limeGreenDark),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.screenPadding,
        children: [
          // Section 1: Listening
          if (listeningQuestions.isNotEmpty) ...[
            Text(
              'Phần 1: Nghe hiểu',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.limeGreenDark,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...listeningQuestions.map((q) => _buildQuestionCard(q)),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Section 2: Reading
          if (readingQuestions.isNotEmpty) ...[
            Text(
              'Phần 2: Đọc hiểu',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.limeGreenDark,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...readingQuestions.map((q) => _buildQuestionCard(q)),
            const SizedBox(height: AppSpacing.lg),
          ],

          const SizedBox(height: AppSpacing.md),
          HiButton(
            text: 'Nộp bài thi',
            isFullWidth: true,
            size: HiButtonSize.lg,
            onPressed: () {
              int listenCorrect = 0;
              for (final q in listeningQuestions) {
                if (_userAnswers[q['id']] == q['correct_answer']) listenCorrect++;
              }
              int readCorrect = 0;
              for (final q in readingQuestions) {
                if (_userAnswers[q['id']] == q['correct_answer']) readCorrect++;
              }

              final listenPoints = listeningQuestions.isNotEmpty
                  ? (listenCorrect / listeningQuestions.length * 100).round()
                  : 50;
              final readPoints = readingQuestions.isNotEmpty
                  ? (readCorrect / readingQuestions.length * 100).round()
                  : 50;

              setState(() {
                _listenScore = listenPoints;
                _readScore = readPoints;
                _score = listenPoints + readPoints;
                _isSubmitted = true;
              });
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, String value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
              fontSize: isHighlight ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isHighlight ? 18 : 14,
              color: isHighlight ? AppColors.limeGreenDark : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> q) {
    final theme = Theme.of(context);
    final qId = q['id'] as String;
    final prompt = (q['prompt'] ?? '') as String;
    final options = ((q['options'] as List<dynamic>?) ?? []).map((e) => e.toString()).toList();
    final selected = _userAnswers[qId];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: HiCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              prompt,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.md),
            ...options.map((opt) {
              final isChosen = selected == opt;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      _userAnswers[qId] = opt;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isChosen ? AppColors.limeGreen.withAlpha(25) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isChosen ? AppColors.limeGreenDark : theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isChosen ? Icons.radio_button_checked : Icons.radio_button_off,
                          size: 18,
                          color: isChosen ? AppColors.limeGreenDark : Colors.grey,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(opt)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
