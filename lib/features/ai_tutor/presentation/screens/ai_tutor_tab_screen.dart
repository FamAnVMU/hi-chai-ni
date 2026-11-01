import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';
import '../../../settings/presentation/screens/ai_settings_screen.dart';

/// Tab 2: AI Tutor Chat & Interactive Language Companion Screen.
class AiTutorTabScreen extends StatefulWidget {
  const AiTutorTabScreen({super.key});

  @override
  State<AiTutorTabScreen> createState() => _AiTutorTabScreenState();
}

class _AiTutorTabScreenState extends State<AiTutorTabScreen> with AutomaticKeepAliveClientMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  final List<Map<String, dynamic>> _messages = [
    {
      'isUser': false,
      'annotatedText': '你好[nǐ hǎo]！我是[wǒ shì]你的[nǐ de]中文[zhōngwén]老师[lǎoshī]。今天[jīntiān]想[xiǎng]学[xué]什么[shénme]？',
      'meaning': 'Xin chào! Tôi là gia sư tiếng Trung của bạn. Hôm nay bạn muốn học gì?',
    },
    {
      'isUser': true,
      'text': 'Tôi muốn luyện câu chào hỏi khi gặp bạn bè ở trường.',
    },
    {
      'isUser': false,
      'annotatedText': '很好[hěn hǎo]！你可以[nǐ kěyǐ]说[shuō]：“嗨[hāi]，最近[zuìjìn]怎么样[zěnmeyàng]？”',
      'meaning': 'Rất tốt! Bạn có thể nói: "Chào, dạo này bạn thế nào?"',
    },
  ];

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _messages.add({
        'isUser': true,
        'text': text,
      });
      _isSending = true;
      _textController.clear();
    });

    // Simulate AI Tutor pedagogical response with Ruby annotation
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      setState(() {
        _messages.add({
          'isUser': false,
          'annotatedText': '你说得[nǐ shuō de]很对[hěn duì]！继续[jìxù]练习[liànxí]吧[ba]！',
          'meaning': 'Bạn nói rất đúng! Hãy tiếp tục luyện tập nhé!',
        });
        _isSending = false;
      });

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.limeGreen,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text('AI Tutor'),
            const SizedBox(width: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkForestCard : theme.colorScheme.primaryContainer,
                borderRadius: AppRadius.borderSm,
              ),
              child: Text(
                'HSK 1',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            tooltip: 'Cấu hình AI Tutor',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AiSettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Learner context banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
              color: isDark ? AppColors.darkForestSurface : theme.colorScheme.surfaceContainerHighest.withAlpha(80),
              child: Row(
                children: [
                  const Icon(
                    Icons.psychology_outlined,
                    size: 16,
                    color: AppColors.limeGreen,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Context: Mục tiêu phản xạ giao tiếp • Sửa lỗi có căn cứ • Ưu tiên tiếng Việt',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Chat Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: AppSpacing.screenPadding,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final isUser = msg['isUser'] as bool;

                  if (isUser) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.md, left: AppSpacing.huge),
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkForestCard : theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.only(
                            topLeft: AppRadius.rMd,
                            topRight: AppRadius.rMd,
                            bottomLeft: AppRadius.rMd,
                            bottomRight: Radius.zero,
                          ),
                          border: Border.all(
                            color: isDark ? AppColors.darkForestBorder : theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Text(
                          msg['text'] as String,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    );
                  }

                  // AI Tutor Message with RubyText
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md, right: AppSpacing.xxl),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkForestSurface : Colors.white,
                        borderRadius: BorderRadius.only(
                          topLeft: AppRadius.rMd,
                          topRight: AppRadius.rMd,
                          bottomRight: AppRadius.rMd,
                          bottomLeft: Radius.zero,
                        ),
                        border: Border.all(
                          color: isDark ? AppColors.darkForestBorder : theme.colorScheme.outlineVariant,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RubyText.fromAnnotatedString(
                            annotatedText: msg['annotatedText'] as String,
                            showPinyin: true,
                            onSegmentTap: (segment) {
                              HiSnackBar.showInfo(
                                context,
                                'Chữ: ${segment.text} [${segment.pinyin ?? ''}]',
                              );
                            },
                          ),
                          if (msg['meaning'] != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              msg['meaning'] as String,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Quick suggestion prompt chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
              child: Row(
                children: [
                  'Sửa câu của tôi ✍️',
                  'Luyện nói mua sắm 🛍️',
                  'Giải thích ngữ pháp 把 💡',
                ].map((prompt) {
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: HiChip(
                      label: prompt,
                      onTap: () {
                        _textController.text = prompt.replaceAll(RegExp(r'[^\w\s\u4e00-\u9fa5]'), '').trim();
                      },
                    ),
                  );
                }).toList(),
              ),
            ),

            // Input Bar
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: HiTextField(
                      controller: _textController,
                      hintText: 'Nhập câu tiếng Trung hoặc câu hỏi...',
                      onSubmitted: (_) => _handleSendMessage(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  HiButton(
                    text: '',
                    icon: _isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    variant: HiButtonVariant.primary,
                    size: HiButtonSize.md,
                    onPressed: _isSending ? null : _handleSendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
