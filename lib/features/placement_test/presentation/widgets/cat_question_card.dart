import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/cat_item.dart';
import '../../domain/models/cat_skill.dart';

/// Card rendering adaptive question formats (Multiple Choice, Pinyin Input, Speaking).
class CatQuestionCard extends StatefulWidget {
  final CatItem item;
  final ValueChanged<dynamic> onAnswerSubmitted;

  const CatQuestionCard({
    super.key,
    required this.item,
    required this.onAnswerSubmitted,
  });

  @override
  State<CatQuestionCard> createState() => _CatQuestionCardState();
}

class _CatQuestionCardState extends State<CatQuestionCard> {
  final TextEditingController _textController = TextEditingController();
  int? _selectedOptionIndex;
  bool _isSpeakingSimulated = false;

  @override
  void didUpdateWidget(covariant CatQuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _textController.clear();
      _selectedOptionIndex = null;
      _isSpeakingSimulated = false;
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;

    return HiCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Sub-type indicator if applicable
          if (item.writingSubType != null) ...[
            Text(
              item.writingSubType!.labelVi,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.primaryBlueDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],

          // Question Prompt Text
          Text(
            item.prompt,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Annotated Chinese sentence with RubyText (hidden for listening questions)
          if (item.annotatedPrompt != null && item.skill != CatSkill.listening) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                borderRadius: AppRadius.borderMd,
              ),
              child: RubyText.fromAnnotatedString(
                annotatedText: item.annotatedPrompt!,
                showPinyin: true,
                hanziStyle: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Audio prompt if applicable
          if (item.audioUri != null || item.skill == CatSkill.listening) ...[
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.lg),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primaryBlueLight.withAlpha(50),
                borderRadius: AppRadius.borderMd,
                border: Border.all(color: AppColors.primaryBlueLight),
              ),
              child: Row(
                children: [
                  IconButton.filled(
                    icon: const Icon(Icons.volume_up_rounded),
                    tooltip: 'Nghe lại phát âm',
                    onPressed: () {
                      // Audio trigger (handled via AudioService / TTS)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đang phát âm thanh bài kiểm tra...'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Nhấn để nghe câu hỏi âm thanh (ẩn chữ Hán & phụ đề)',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.primaryBlueDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Formats:
          // A. Multiple Choice & Stroke Order
          if (item.options.isNotEmpty) ...[
            ...List.generate(item.options.length, (index) {
              final optionText = item.options[index];
              final isSelected = _selectedOptionIndex == index;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: InkWell(
                  onTap: () {
                    setState(() => _selectedOptionIndex = index);
                    widget.onAnswerSubmitted(index);
                  },
                  borderRadius: AppRadius.borderMd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primaryBlueLight
                          : AppColors.cardBackground,
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primaryBlueDark
                            : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: isSelected
                              ? AppColors.primaryBlueDark
                              : AppColors.inputBackground,
                          child: Text(
                            String.fromCharCode(65 + index), // A, B, C, D
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: isSelected ? Colors.white : AppColors.secondaryText,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            optionText,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ]

          // B. Pinyin Input
          else if (item.type == CatItemType.pinyinInput) ...[
            HiTextField(
              controller: _textController,
              hintText: 'Nhập Pinyin (ví dụ: hanyu, nihao)...',
              prefixIcon: const Icon(Icons.keyboard_outlined),
              onSubmitted: (val) {
                if (val.trim().isNotEmpty) {
                  widget.onAnswerSubmitted(val.trim());
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            HiButton(
              text: 'Xác nhận câu trả lời',
              icon: const Icon(Icons.check_rounded),
              variant: HiButtonVariant.primary,
              onPressed: () {
                if (_textController.text.trim().isNotEmpty) {
                  widget.onAnswerSubmitted(_textController.text.trim());
                }
              },
            ),
          ]

          // C. Speaking Prompt
          else if (item.type == CatItemType.speakingPrompt) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
                borderRadius: AppRadius.borderMd,
              ),
              child: Column(
                children: [
                  Icon(
                    _isSpeakingSimulated ? Icons.mic_rounded : Icons.mic_none_rounded,
                    color: _isSpeakingSimulated ? Colors.redAccent : AppColors.primaryBlueDark,
                    size: AppDimensions.iconXl,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _isSpeakingSimulated ? 'Đang gửi bản ghi âm...' : 'Nhấn micro và đọc to câu trên',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Bản ghi âm sẽ được lưu và chuyển trạng thái "Chờ kiểm tra"',
                    style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondaryText),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  HiButton(
                    text: _isSpeakingSimulated ? 'Đã ghi nhận (Chờ kiểm tra)' : 'Bắt đầu phát âm',
                    variant: HiButtonVariant.primary,
                    onPressed: _isSpeakingSimulated
                        ? null
                        : () {
                            setState(() => _isSpeakingSimulated = true);
                            Future.delayed(const Duration(milliseconds: 1000), () {
                              if (mounted) {
                                widget.onAnswerSubmitted('speech_sample_recorded');
                              }
                            });
                          },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
