import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/practice_models.dart';

class ShortAnswerWidget extends StatefulWidget {
  final ExerciseDefinition definition;
  final String textResponse;
  final ScoringResult? result;
  final ValueChanged<String> onTextChanged;

  const ShortAnswerWidget({
    super.key,
    required this.definition,
    required this.textResponse,
    this.result,
    required this.onTextChanged,
  });

  @override
  State<ShortAnswerWidget> createState() => _ShortAnswerWidgetState();
}

class _ShortAnswerWidgetState extends State<ShortAnswerWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.textResponse);
  }

  @override
  void didUpdateWidget(covariant ShortAnswerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.textResponse != widget.textResponse && _controller.text != widget.textResponse) {
      _controller.text = widget.textResponse;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSubmitted = widget.result != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.definition.rubricKeywords.isNotEmpty) ...[
          Text(
            'Gợi ý tiêu chí ngữ nghĩa:',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Câu trả lời cần vận dụng đúng cấu trúc ngữ pháp và các từ khóa cốt lõi.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],

        TextField(
          controller: _controller,
          enabled: !isSubmitted,
          maxLines: 3,
          minLines: 2,
          decoration: InputDecoration(
            hintText: 'Nhập câu trả lời của bạn bằng tiếng Trung...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
            filled: true,
            fillColor: theme.colorScheme.surface,
          ),
          onChanged: widget.onTextChanged,
        ),
      ],
    );
  }
}
