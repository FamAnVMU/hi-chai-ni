import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';

class LevelExitExamScreen extends StatefulWidget {
  final String level;
  final Map<String, dynamic>? examPayload;
  final Map<String, dynamic>? examData;

  const LevelExitExamScreen({
    super.key,
    this.level = '1',
    this.examPayload,
    this.examData,
  });

  @override
  State<LevelExitExamScreen> createState() => _LevelExitExamScreenState();
}

class _LevelExitExamScreenState extends State<LevelExitExamScreen> {
  final Map<String, String> _userAnswers = {};
  bool _isSubmitted = false;
  int _score = 0;
  int _listenScore = 0;
  int _readScore = 0;

  static const int _totalScore = 200;
  static const int _passingScore = 120; // 60% standard

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activePayload = widget.examData ?? widget.examPayload;
    final title = (activePayload?['title'] as String?) ?? 'Đề Thi Tốt Nghiệp HSK ${widget.level}';
    final duration = (activePayload?['duration_minutes'] as int?) ?? 35;

    final rawQuestions = (activePayload?['questions'] as List<dynamic>?) ?? [];
    List<Map<String, dynamic>> questions = rawQuestions.map((e) => e as Map<String, dynamic>).toList();

    // Fallback authentic simulated mock exam if payload not loaded yet
    if (questions.isEmpty) {
      questions = [
        {
          'id': 'exam_l1',
          'section': 'listening',
          'prompt': '[Nghe audio] "你好！" - Người nói đang chào hỏi đối phương.',
          'options': ['Đúng', 'Sai'],
          'correct_answer': 'Đúng',
        },
        {
          'id': 'exam_l2',
          'section': 'listening',
          'prompt': '[Nghe audio] "他在学校学习汉语。" - Người này đang học tiếng Anh.',
          'options': ['Đúng', 'Sai'],
          'correct_answer': 'Sai',
        },
        {
          'id': 'exam_r1',
          'section': 'reading',
          'prompt': 'Chọn từ thích hợp điền vào chỗ trống: 我 ____ 中国人。',
          'options': ['是', '有', '在', '很'],
          'correct_answer': '是',
        },
        {
          'id': 'exam_r2',
          'section': 'reading',
          'prompt': 'Từ nào sau đây có nghĩa là "uống nước"?',
          'options': ['喝水', '吃菜', '看书', '买米'],
          'correct_answer': '喝水',
        },
      ];
    }

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
                    color: isPassed ? AppColors.successContainerLight : AppColors.errorContainerLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPassed ? Icons.workspace_premium_rounded : Icons.highlight_off_rounded,
                    size: 72,
                    color: isPassed ? AppColors.success : AppColors.error,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Kết quả thi tốt nghiệp HSK ${widget.level}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isPassed ? AppColors.success : AppColors.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isPassed ? 'XUẤT SẮC ĐẠT CHUẨN ĐẦU RA!' : 'CHƯA ĐẠT ĐIỂM CHUẨN',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              HiCard(
                backgroundColor: AppColors.cardBackground,
                borderColor: AppColors.border,
                child: Column(
                  children: [
                    _buildScoreRow('Tổng điểm đạt được', '$_score / $_totalScore điểm', isHighlight: true, isPassed: isPassed),
                    const Divider(color: AppColors.divider),
                    _buildScoreRow('Phần 1: Nghe hiểu', '$_listenScore / 100 điểm'),
                    const Divider(color: AppColors.divider),
                    _buildScoreRow('Phần 2: Đọc hiểu', '$_readScore / 100 điểm'),
                    const Divider(color: AppColors.divider),
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
              color: AppColors.primaryBlueLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, size: 16, color: AppColors.primaryBlueDark),
                const SizedBox(width: 4),
                Text(
                  '$duration:00',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryBlueDark),
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
                color: AppColors.primaryText,
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
                color: AppColors.primaryText,
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

  Widget _buildScoreRow(String label, String value, {bool isHighlight = false, bool isPassed = true}) {
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
              color: AppColors.primaryText,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isHighlight ? 18 : 14,
              color: isHighlight
                  ? (isPassed ? AppColors.success : AppColors.error)
                  : AppColors.secondaryText,
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
        backgroundColor: AppColors.cardBackground,
        borderColor: AppColors.border,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              prompt,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.primaryText,
              ),
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
                      color: isChosen ? AppColors.primaryBlueLight : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isChosen ? AppColors.primaryBlueDark : AppColors.border,
                        width: isChosen ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isChosen ? Icons.radio_button_checked : Icons.radio_button_off,
                          size: 18,
                          color: isChosen ? AppColors.primaryBlueDark : AppColors.mutedText,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            opt,
                            style: TextStyle(
                              color: isChosen ? AppColors.primaryBlueDark : AppColors.primaryText,
                              fontWeight: isChosen ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
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
