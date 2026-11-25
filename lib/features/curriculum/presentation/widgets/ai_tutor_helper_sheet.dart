import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/ai/ai_service.dart';
import '../../../../core/network/ai/models/ai_request.dart';
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

  Future<void> _onSelectChip(String query) async {
    setState(() {
      _selectedQuery = query;
      _isLoading = true;
    });

    final contextualPrompt = StringBuffer()
      ..writeln('Bạn là trợ giảng tiếng Trung AI của Hi Chinese.')
      ..writeln('Yêu cầu: $query')
      ..writeln('Chủ đề bài học: ${widget.topicTitle}');
    if (widget.topicContext != null && widget.topicContext!.isNotEmpty) {
      contextualPrompt.writeln('Ngữ cảnh: ${widget.topicContext}');
    }
    if (widget.exercisePrompt != null && widget.exercisePrompt!.isNotEmpty) {
      contextualPrompt.writeln('Câu hỏi đang làm: ${widget.exercisePrompt}');
    }
    if (widget.userWrongAnswer != null && widget.userWrongAnswer!.isNotEmpty) {
      contextualPrompt.writeln('Đáp án học viên vừa chọn nhầm: ${widget.userWrongAnswer}');
    }
    contextualPrompt.writeln(
      'Hãy trả lời ngắn gọn, dễ hiểu bằng tiếng Việt kèm ví dụ chữ Hán và Pinyin chuẩn.',
    );

    if (widget.isOnline) {
      try {
        final aiService = ref.read(aiServiceProvider);
        final hasCredentials = await aiService.verifyCredentials();
        if (hasCredentials) {
          final response = await aiService.generateText(
            AiPromptRequest.singlePrompt(contextualPrompt.toString()),
          );
          if (mounted && response.text.trim().isNotEmpty) {
            setState(() {
              _isLoading = false;
              _aiResponse = response.text.trim();
            });
            return;
          }
        }
      } catch (_) {
        // Fall through cleanly to local grammar/context helper when offline or API unavailable
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _aiResponse = _buildLocalContextualExplanation(query);
    });
  }

  String _buildLocalContextualExplanation(String query) {
    final topic = widget.topicTitle;
    final wrongAns = widget.userWrongAnswer;
    final exercise = widget.exercisePrompt;
    final contextNote = widget.topicContext;

    if (query == 'Giải thích dễ hiểu hơn') {
      final base =
          '💡 Giải thích trọng tâm "$topic": ${_getPedagogicalTip(topic)}.';
      if (wrongAns != null && wrongAns.isNotEmpty) {
        return '$base\n• Lưu ý lỗi chọn "$wrongAns": hãy đối chiếu vị trí từ loại (Chủ ngữ → Thời gian/Địa điểm → Động từ/Tính từ → Tân ngữ) thay vì dịch từng từ tiếng Việt.';
      }
      if (contextNote != null && contextNote.isNotEmpty) {
        return '$base\n• Gợi ý ngữ cảnh: $contextNote';
      }
      return base;
    }

    if (query == 'Cho thêm 2 ví dụ') {
      return '📝 Gợi ý luyện đặt câu cho "$topic":\n'
          '• Công thức kiểm tra nhanh: Xác định chủ thể → hành động/tính chất → kết quả.\n'
          '${exercise != null && exercise.isNotEmpty ? "• Đối chiếu bài hiện tại: $exercise\n" : ""}'
          '• Bạn có thể cấu hình Gemini API Key trong Cài đặt để AI sinh thêm hàng loạt ví dụ mở rộng theo chủ đề "$topic".';
    }

    return '🤖 Trợ giảng (Chế độ ngoại tuyến): Với "$topic", hãy đọc to câu mẫu kèm Pinyin để nhớ nhịp ngữ điệu trước khi làm lại bài tập.${wrongAns != null && wrongAns.isNotEmpty ? ' Kiểm tra lại lựa chọn "$wrongAns" nhé.' : ''}';
  }

  String _getPedagogicalTip(String topic) {
    if (topic.contains('是')) {
      return '"是" dùng để liên kết hai danh từ hoặc cụm danh từ (A 是 B = A là B), không dùng trực tiếp trước tính từ đơn';
    }
    if (topic.contains('了')) {
      return '"了" dùng để biểu thị sự hoàn thành của hành động (đặt sau động từ) hoặc sự thay đổi trạng thái (đặt cuối câu)';
    }
    if (topic.contains('把')) {
      return 'Câu chữ "把" nhấn mạnh sự tác động làm thay đổi vị trí/trạng thái của đối tượng: Chủ ngữ + 把 + Tân ngữ + Động từ + Thành phần khác';
    }
    return 'hãy chú ý trật tự câu tiếng Trung (Thời gian/Địa điểm đặt trước động từ) và vai trò từng hư từ trong ngữ cảnh cụ thể';
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
