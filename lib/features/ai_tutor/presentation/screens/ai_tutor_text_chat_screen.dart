import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/ai/models/cancel_token.dart';
import '../../../../core/theme/theme.dart';
import '../../domain/models/tutor_chat_turn.dart';
import '../../domain/models/tutor_correction.dart';
import '../../domain/models/tutor_scenario.dart';
import '../providers/ai_tutor_providers.dart';

/// Screen implementing AI Tutor Text Chat with full streaming, cancellation,
/// controlled retry, session management, and RubyText rendering.
class AiTutorTextChatScreen extends ConsumerStatefulWidget {
  const AiTutorTextChatScreen({super.key});

  @override
  ConsumerState<AiTutorTextChatScreen> createState() => _AiTutorTextChatScreenState();
}

class _AiTutorTextChatScreenState extends ConsumerState<AiTutorTextChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isStreaming = false;
  String _streamBuffer = '';
  CancelToken? _cancelToken;
  StreamSubscription<String>? _streamSub;
  String? _lastUserText;

  // Track expanded Vietnamese translations per message ID
  final Set<String> _expandedTranslations = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureActiveSession();
    });
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _cancelToken?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _ensureActiveSession() async {
    try {
      final currentSessionId = ref.read(currentChatSessionIdProvider);
      if (currentSessionId != null) return;

      final repo = ref.read(aiTutorRepositoryProvider);
      final activeSessions = await repo.getActiveSessions(limit: 1);

      if (activeSessions.isNotEmpty && mounted) {
        final session = activeSessions.first;
        ref.read(currentChatSessionIdProvider.notifier).selectSession(session['id'] as String);
        final scenarioCode = session['scenario_code'] as String?;
        if (scenarioCode != null) {
          ref.read(activeScenarioProvider.notifier).selectScenario(TutorScenarios.fromCode(scenarioCode));
        }
      } else if (mounted) {
        await _createNewSession();
      }
    } catch (e) {
      debugPrint('[AiTutorTextChatScreen] Could not auto-load active session: $e');
    }
  }

  Future<void> _createNewSession() async {
    final repo = ref.read(aiTutorRepositoryProvider);
    final scenario = ref.read(activeScenarioProvider);
    final persona = ref.read(activePersonaProvider);

    final title = '${scenario.titleVi} • ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}';
    final sessionId = await repo.createSession(
      title: title,
      scenarioCode: scenario.code,
      personaId: persona.id,
    );

    if (!mounted) return;
    ref.read(currentChatSessionIdProvider.notifier).selectSession(sessionId);
    ref.invalidate(recentChatSessionsProvider);
    ref.invalidate(sessionMessagesProvider(sessionId));
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? overrideText]) async {
    final text = (overrideText ?? _textController.text).trim();
    if (text.isEmpty || _isStreaming) return;

    final sessionId = ref.read(currentChatSessionIdProvider);
    if (sessionId == null) return;

    final repo = ref.read(aiTutorRepositoryProvider);
    final persona = ref.read(activePersonaProvider);
    final scenario = ref.read(activeScenarioProvider);

    _textController.clear();
    _lastUserText = text;
    final cancelToken = CancelToken();

    setState(() {
      _isStreaming = true;
      _streamBuffer = '';
      _cancelToken = cancelToken;
    });

    _scrollToBottom();

    try {
      final stream = repo.sendMessageStream(
        sessionId: sessionId,
        userText: text,
        persona: persona,
        scenario: scenario,
        cancelToken: cancelToken,
        onComplete: (response) {
          if (mounted) {
            setState(() {
              _isStreaming = false;
              _streamBuffer = '';
              _cancelToken = null;
            });
            ref.invalidate(sessionMessagesProvider(sessionId));
            _scrollToBottom();
          }
        },
      );

      _streamSub = stream.listen(
        (chunk) {
          if (mounted) {
            setState(() {
              _streamBuffer += chunk;
            });
            _scrollToBottom();
          }
        },
        onError: (err) {
          if (mounted) {
            setState(() {
              _isStreaming = false;
              _cancelToken = null;
            });
            ref.invalidate(sessionMessagesProvider(sessionId));
            if (!cancelToken.isCancelled) {
              HiSnackBar.showError(
                context,
                'Không thể hoàn tất phản hồi: ${err.toString()}',
              );
            }
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isStreaming = false;
          _cancelToken = null;
        });
        ref.invalidate(sessionMessagesProvider(sessionId));
        HiSnackBar.showError(context, 'Lỗi kết nối AI Tutor: $e');
      }
    }
  }

  void _stopGeneration() {
    if (_cancelToken != null && !_cancelToken!.isCancelled) {
      _cancelToken!.cancel('User cancelled generation');
      _streamSub?.cancel();
      setState(() {
        _isStreaming = false;
        _streamBuffer = '';
        _cancelToken = null;
      });
      final sessionId = ref.read(currentChatSessionIdProvider);
      if (sessionId != null) {
        ref.invalidate(sessionMessagesProvider(sessionId));
      }
      HiSnackBar.showInfo(context, 'Đã dừng tạo phản hồi');
    }
  }

  Future<void> _retryLastTurn() async {
    final sessionId = ref.read(currentChatSessionIdProvider);
    final lastText = _lastUserText;
    if (sessionId == null || lastText == null || lastText.isEmpty || _isStreaming) return;

    final repo = ref.read(aiTutorRepositoryProvider);
    await repo.removeLastTurn(sessionId);
    ref.invalidate(sessionMessagesProvider(sessionId));

    await _sendMessage(lastText);
  }

  void _copyToClipboard(String content) {
    Clipboard.setData(ClipboardData(text: content));
    HiSnackBar.showSuccess(context, 'Đã sao chép vào bộ nhớ tạm');
  }

  void _showSessionDrawer() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _buildSessionSheet(ctx),
    );
  }

  Widget _buildSessionSheet(BuildContext sheetContext) {
    final theme = Theme.of(sheetContext);
    final isDark = theme.brightness == Brightness.dark;
    final sessionsAsync = ref.watch(recentChatSessionsProvider);
    final activeSessionId = ref.watch(currentChatSessionIdProvider);

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Lịch sử hội thoại',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                HiButton(
                  text: 'Tạo phiên mới',
                  icon: const Icon(Icons.add_rounded, size: 16),
                  size: HiButtonSize.sm,
                  variant: HiButtonVariant.primary,
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await _createNewSession();
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Divider(),
            Expanded(
              child: sessionsAsync.when(
                data: (sessions) {
                  if (sessions.isEmpty) {
                    return const Center(
                      child: HiEmptyState(
                        title: 'Chưa có phiên hội thoại',
                        description: 'Bấm "Tạo phiên mới" để bắt đầu luyện tập',
                        icon: Icons.chat_bubble_outline_rounded,
                      ),
                    );
                  }
                  return ListView.builder(
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final item = sessions[index];
                      final id = item['id'] as String;
                      final title = item['title'] as String? ?? 'Phiên học';
                      final scenarioCode = item['scenario_code'] as String? ?? 'free_chat';
                      final isSelected = id == activeSessionId;

                      return ListTile(
                        selected: isSelected,
                        selectedTileColor: isDark
                            ? AppColors.darkForestCard
                            : theme.colorScheme.primaryContainer.withAlpha(80),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
                        leading: Icon(
                          isSelected ? Icons.chat_rounded : Icons.chat_bubble_outline_rounded,
                          color: isSelected ? AppColors.limeGreen : theme.colorScheme.onSurfaceVariant,
                        ),
                        title: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          scenarioCode,
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                        trailing: PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, size: 18),
                          onSelected: (val) async {
                            if (val == 'rename') {
                              Navigator.of(sheetContext).pop();
                              _promptRenameSession(id, title);
                            } else if (val == 'delete') {
                              Navigator.of(sheetContext).pop();
                              _confirmDeleteSession(id);
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 16),
                                  SizedBox(width: 8),
                                  Text('Đổi tên'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Xóa phiên', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          ref.read(currentChatSessionIdProvider.notifier).selectSession(id);
                          ref.read(activeScenarioProvider.notifier).selectScenario(
                                TutorScenarios.fromCode(scenarioCode),
                              );
                          Navigator.of(sheetContext).pop();
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: HiLoadingIndicator()),
                error: (e, _) => Center(child: Text('Lỗi tải danh sách: $e')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _promptRenameSession(String sessionId, String currentTitle) {
    final controller = TextEditingController(text: currentTitle);
    HiDialog.show(
      context: context,
      title: 'Đổi tên cuộc trò chuyện',
      content: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: HiTextField(
          controller: controller,
          hintText: 'Nhập tên mới...',
        ),
      ),
      confirmText: 'Lưu',
      cancelText: 'Hủy',
      onConfirm: () async {
        final newTitle = controller.text.trim();
        if (newTitle.isNotEmpty) {
          final repo = ref.read(aiTutorRepositoryProvider);
          await repo.updateSessionTitle(sessionId, newTitle);
          ref.invalidate(recentChatSessionsProvider);
        }
      },
    );
  }

  void _confirmDeleteSession(String sessionId) {
    HiDialog.show(
      context: context,
      title: 'Xóa cuộc trò chuyện?',
      message: 'Toàn bộ nội dung trao đổi trong phiên này sẽ bị xóa khỏi danh sách. Bạn có chắc chắn muốn xóa?',
      confirmText: 'Xóa',
      cancelText: 'Hủy',
      isDestructive: true,
      onConfirm: () async {
        final repo = ref.read(aiTutorRepositoryProvider);
        await repo.deleteSession(sessionId);
        ref.invalidate(recentChatSessionsProvider);

        if (ref.read(currentChatSessionIdProvider) == sessionId) {
          ref.read(currentChatSessionIdProvider.notifier).selectSession(null);
          await _ensureActiveSession();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final sessionId = ref.watch(currentChatSessionIdProvider);
    final persona = ref.watch(activePersonaProvider);
    final scenario = ref.watch(activeScenarioProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: InkWell(
          onTap: _showSessionDrawer,
          borderRadius: AppRadius.borderSm,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.limeGreen.withAlpha(40),
                  child: Text(
                    persona.avatarLabel,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            persona.nameZh,
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down_rounded, size: 18),
                        ],
                      ),
                      Text(
                        scenario.titleVi,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Danh sách phiên',
            onPressed: _showSessionDrawer,
          ),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Phiên mới',
            onPressed: _createNewSession,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Context Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
              color: isDark ? AppColors.darkForestSurface : theme.colorScheme.surfaceContainerHighest.withAlpha(70),
              child: Row(
                children: [
                  const Icon(Icons.lightbulb_outline_rounded, size: 14, color: AppColors.limeGreen),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Mục tiêu: ${scenario.objectiveVi}',
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Messages View
            Expanded(
              child: sessionId == null
                  ? const Center(child: HiLoadingIndicator())
                  : ref.watch(sessionMessagesProvider(sessionId)).when(
                        data: (turns) => _buildMessagesList(turns),
                        loading: () => const Center(child: HiLoadingIndicator()),
                        error: (err, _) => Center(
                          child: Text('Lỗi tải tin nhắn: $err'),
                        ),
                      ),
            ),

            // Suggested prompt chips
            if (scenario.suggestedUserPrompts.isNotEmpty && !_isStreaming)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4.0),
                child: Row(
                  children: scenario.suggestedUserPrompts.map((prompt) {
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.xs),
                      child: HiChip(
                        label: prompt,
                        onTap: () {
                          _textController.text = prompt;
                          _textController.selection = TextSelection.fromPosition(
                            TextPosition(offset: prompt.length),
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

            // Bottom Control / Input Bar
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList(List<TutorChatTurn> turns) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: turns.length + (_isStreaming ? 1 : 0),
      itemBuilder: (context, index) {
        if (index < turns.length) {
          final turn = turns[index];
          return _buildChatTurnItem(turn, isLast: index == turns.length - 1);
        } else {
          // Streaming partial bubble
          return _buildStreamingBubble();
        }
      },
    );
  }

  Widget _buildChatTurnItem(TutorChatTurn turn, {required bool isLast}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (turn.isUser) {
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                turn.content,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => _copyToClipboard(turn.content),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant.withAlpha(160),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // AI Assistant Turn
    final isTranslationExpanded = _expandedTranslations.contains(turn.id);
    final hasTranslation = turn.translationVi != null && turn.translationVi!.isNotEmpty;
    final hasPinyin = turn.pinyin != null && turn.pinyin!.isNotEmpty;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md, right: AppSpacing.xxl),
        padding: const EdgeInsets.all(AppSpacing.md),
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
            // Hanzi + Ruby Pinyin
            RubyText.fromAnnotatedString(
              annotatedText: turn.content.contains('[') ? turn.content : turn.content,
              showPinyin: true,
              onSegmentTap: (segment) {
                if (segment.pinyin != null) {
                  HiSnackBar.showInfo(
                    context,
                    '${segment.text} [${segment.pinyin}]',
                  );
                }
              },
            ),

            if (!turn.content.contains('[') && hasPinyin) ...[
              const SizedBox(height: 4),
              Text(
                turn.pinyin!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? AppColors.limeGreen : theme.colorScheme.primary,
                  fontFamily: 'NotoSans',
                  fontSize: 12,
                ),
              ),
            ],

            // Optional 3-step pedagogical correction note if evaluation exists
            if (turn.evaluation != null && !turn.evaluation!.isCorrect) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildPedagogicalCorrectionCard(turn.evaluation!),
            ],

            // Vietnamese Translation toggle
            if (hasTranslation) ...[
              const SizedBox(height: AppSpacing.sm),
              if (isTranslationExpanded)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkForestCard
                        : theme.colorScheme.surfaceContainerHighest.withAlpha(90),
                    borderRadius: AppRadius.borderSm,
                  ),
                  child: Text(
                    turn.translationVi!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],

            // Action row: Copy, Translate toggle, Retry (if last)
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (hasTranslation)
                  IconButton(
                    icon: Icon(
                      isTranslationExpanded ? Icons.translate_rounded : Icons.translate_outlined,
                      size: 16,
                      color: isTranslationExpanded ? AppColors.limeGreen : theme.colorScheme.onSurfaceVariant,
                    ),
                    tooltip: isTranslationExpanded ? 'Ẩn bản dịch' : 'Xem bản dịch tiếng Việt',
                    onPressed: () {
                      setState(() {
                        if (isTranslationExpanded) {
                          _expandedTranslations.remove(turn.id);
                        } else {
                          _expandedTranslations.add(turn.id);
                        }
                      });
                    },
                    visualDensity: VisualDensity.compact,
                  ),
                IconButton(
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  tooltip: 'Sao chép văn bản',
                  onPressed: () => _copyToClipboard(turn.content),
                  visualDensity: VisualDensity.compact,
                ),
                if (isLast && !_isStreaming)
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    tooltip: 'Thử lại phản hồi này',
                    onPressed: _retryLastTurn,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPedagogicalCorrectionCard(TutorEvaluation evaluation) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkForestCard : const Color(0xFFFFF9E6),
        border: Border.all(color: Colors.amber.shade400, width: 0.8),
        borderRadius: AppRadius.borderSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_rounded, size: 14, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                'Góp ý sư phạm (3 bước)',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (evaluation.encouragementVi.isNotEmpty)
            Text(
              '1. ${evaluation.encouragementVi}',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          if (evaluation.gentleFeedbackVi.isNotEmpty)
            Text(
              '2. ${evaluation.gentleFeedbackVi}',
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
            ),
          if (evaluation.modelCorrectionZh.isNotEmpty)
            Text(
              '3. Câu chuẩn: ${evaluation.modelCorrectionZh}',
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.limeGreen,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStreamingBubble() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.md, right: AppSpacing.xxl),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkForestSurface : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: AppRadius.rMd,
            topRight: AppRadius.rMd,
            bottomRight: AppRadius.rMd,
            bottomLeft: Radius.zero,
          ),
          border: Border.all(
            color: AppColors.limeGreen.withAlpha(120),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  'AI Tutor đang trả lời...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.limeGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _streamBuffer.isEmpty ? '...' : _streamBuffer,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: HiButton(
                text: 'Dừng tạo',
                icon: const Icon(Icons.stop_circle_outlined, size: 14),
                variant: HiButtonVariant.secondary,
                size: HiButtonSize.sm,
                onPressed: _stopGeneration,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: HiTextField(
              controller: _textController,
              hintText: 'Nhập câu tiếng Trung hoặc câu hỏi...',
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          if (_isStreaming)
            HiButton(
              text: '',
              icon: const Icon(Icons.stop_rounded, color: Colors.red),
              variant: HiButtonVariant.secondary,
              size: HiButtonSize.md,
              onPressed: _stopGeneration,
            )
          else
            HiButton(
              text: '',
              icon: const Icon(Icons.send_rounded),
              variant: HiButtonVariant.primary,
              size: HiButtonSize.md,
              onPressed: () => _sendMessage(),
            ),
        ],
      ),
    );
  }
}
