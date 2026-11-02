import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';

class AiTutorHelperSheet extends ConsumerStatefulWidget {
  final String topicTitle;
  final String? topicContext;
  final String? exercisePrompt;
  final String? userWrongAnswer;
  final bool isOnline;

  const AiTutorHelperSheet({
    super.key,
    required this.topicTitle,
    this.topicContext,
    this.exercisePrompt,
    this.userWrongAnswer,
    this.isOnline = true,
  });

  @override
  ConsumerState<AiTutorHelperSheet> createState() => _AiTutorHelperSheetState();
}

class _AiTutorHelperSheetState extends ConsumerState<AiTutorHelperSheet> {
  String? _selectedQuery;
  bool _isLoading = false;
  String? _aiResponse;

  void _onSelectChip(String query) {
    setState(() {
      _selectedQuery = query;
      _isLoading = true;
    });

    // Provide immediate helpful pedagogical guidance
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (query == 'Giải thích dễ hiểu hơn') {
          _aiResponse = '💡 Trợ giảng phân tích: Trong "${widget.topicTitle}", hãy nhớ quy tắc ngữ cảnh thực tế: ${_getPedagogicalTip(widget.topicTitle)}. Học sinh Việt Nam thường có phản xạ dịch từng chữ theo tiếng Việt, nhưng tiếng Trung luôn ưu tiên trật tự: Thời gian / Địa điểm trước Động từ.';
        } else if (query == 'Cho thêm 2 ví dụ') {
          _aiResponse = '📝 2 ví dụ mở rộng từ trợ giảng:\n1. 昨天我去学校。(Hôm qua tôi đã đến trường - Trạng từ thời gian đứng trước).\n2. 他在教室学习。(Anh ấy học ở phòng học - Trạng từ nơi chốn đứng trước).';
        } else {
          _aiResponse = '🤖 Trợ giảng giải đáp: Đối với nội dung "${widget.topicTitle}", bạn đang làm rất tốt! Hãy tiếp tục luyện tập các bài tập trong giáo trình để củng cố phản xạ tự nhiên.';
        }
      });
    });
  }

  String _getPedagogicalTip(String topic) {
    if (topic.contains('是')) {
      return '"是" dùng để liên kết 2 danh từ hoặc cụm danh từ (A là B), không đi trực tiếp với tính từ';
    }
    return 'người bản xứ luôn dùng ngữ điệu tự nhiên và trật tự ngữ pháp chặt chẽ';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlueDark.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      color: AppColors.primaryBlueDark,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Trợ Giảng AI Bổ Trợ',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Topic info
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Chủ đề: ${widget.topicTitle}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlueDark,
                      ),
                    ),
                    if (widget.topicContext != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.topicContext!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Offline Fallback vs Online Features
              if (!widget.isOnline) ...[
                HiCard(
                  child: Column(
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 36,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Chế độ Ngoại tuyến (Offline)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'AI chỉ là trợ giảng bổ trợ khi có mạng. Bạn vẫn có thể tiếp tục tự học giáo trình ngoại tuyến 100% với lời giải thích chính thức có sẵn trong từng bài học.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                HiButton(
                  text: 'Đã hiểu và tiếp tục học',
                  variant: HiButtonVariant.primary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ] else ...[
                Text(
                  'Bạn muốn trợ giảng hỗ trợ điều gì?',
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.lightbulb_outline, size: 16),
                      label: const Text('Giải thích dễ hiểu hơn'),
                      backgroundColor: _selectedQuery == 'Giải thích dễ hiểu hơn'
                          ? AppColors.primaryBlueDark.withValues(alpha: 0.25)
                          : null,
                      onPressed: () => _onSelectChip('Giải thích dễ hiểu hơn'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.format_list_bulleted, size: 16),
                      label: const Text('Cho thêm 2 ví dụ'),
                      backgroundColor: _selectedQuery == 'Cho thêm 2 ví dụ'
                          ? AppColors.primaryBlueDark.withValues(alpha: 0.25)
                          : null,
                      onPressed: () => _onSelectChip('Cho thêm 2 ví dụ'),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.question_answer_outlined, size: 16),
                      label: const Text('Hỏi AI trợ giảng'),
                      backgroundColor: _selectedQuery == 'Hỏi AI trợ giảng'
                          ? AppColors.primaryBlueDark.withValues(alpha: 0.25)
                          : null,
                      onPressed: () => _onSelectChip('Hỏi AI trợ giảng'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                if (_isLoading) ...[
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.md),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ] else if (_aiResponse != null) ...[
                  HiCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phản hồi từ Trợ Giảng:',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlueDark,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _aiResponse!,
                          style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    '⚠️ Rào chắn sư phạm: AI đóng vai trò trợ giảng bổ trợ, không thay đổi nội dung chuẩn hoặc đáp án bài tập của giáo trình.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                HiButton(
                  text: 'Đã hiểu',
                  variant: HiButtonVariant.primary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
