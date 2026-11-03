import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../../../pronunciation/presentation/widgets/waveform_visualizer.dart';
import '../../domain/voice/voice_conversation_models.dart';
import '../../domain/voice/voice_conversation_service.dart';
import '../providers/ai_tutor_providers.dart';

/// Screen implementing AI Tutor Voice Conversation with 10 explicit operational states,
/// real-time mic waveform, AI interruption, interim vs final transcript differentiation,
/// mic test preflight, persona voice preview, and Firebase AI Logic Live API Preview diagnostics.
class AiTutorVoiceChatScreen extends ConsumerStatefulWidget {
  const AiTutorVoiceChatScreen({super.key});

  @override
  ConsumerState<AiTutorVoiceChatScreen> createState() => _AiTutorVoiceChatScreenState();
}

class _AiTutorVoiceChatScreenState extends ConsumerState<AiTutorVoiceChatScreen>
    with WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _speechInputController = TextEditingController();

  StreamSubscription<VoiceConversationStatus>? _statusSub;
  StreamSubscription<List<VoiceTranscriptSegment>>? _transcriptSub;

  VoiceConversationStatus _currentStatus = VoiceConversationStatus.idle;
  List<VoiceTranscriptSegment> _transcripts = [];
  bool _isMicTesting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    final service = ref.read(voiceConversationServiceProvider);
    _currentStatus = service.status;
    _transcripts = service.transcripts;

    _statusSub = service.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _currentStatus = status;
        });
        _scrollToBottom();
      }
    });

    _transcriptSub = service.transcriptStream.listen((list) {
      if (mounted) {
        setState(() {
          _transcripts = list;
        });
        _scrollToBottom();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final service = ref.read(voiceConversationServiceProvider);
    service.handleLifecycleTransition(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _statusSub?.cancel();
    _transcriptSub?.cancel();
    _scrollController.dispose();
    _speechInputController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startVoiceSession() async {
    final service = ref.read(voiceConversationServiceProvider);
    final persona = ref.read(activePersonaProvider);
    final scenario = ref.read(activeScenarioProvider);

    var sessionId = ref.read(currentChatSessionIdProvider);
    if (sessionId == null) {
      final repo = ref.read(aiTutorRepositoryProvider);
      final title = 'Hội thoại thoại: ${scenario.titleVi}';
      sessionId = await repo.createSession(
        title: title,
        scenarioCode: scenario.code,
        personaId: persona.id,
      );
      ref.read(currentChatSessionIdProvider.notifier).selectSession(sessionId);
    }

    await service.startSession(
      sessionId: sessionId,
      persona: persona,
      scenario: scenario,
    );
  }

  Future<void> _endVoiceSession() async {
    final service = ref.read(voiceConversationServiceProvider);
    await service.endSession();
    if (!mounted) return;
    HiSnackBar.showInfo(context, 'Đã kết thúc phiên đàm thoại');
  }

  Future<void> _interruptAi() async {
    final service = ref.read(voiceConversationServiceProvider);
    await service.interrupt();
    if (!mounted) return;
    HiSnackBar.showInfo(context, 'Đã ngắt lời AI');
  }

  Future<void> _toggleMute() async {
    final service = ref.read(voiceConversationServiceProvider);
    await service.toggleMute();
    if (!mounted) return;
    setState(() {});
    HiSnackBar.showInfo(
      context,
      service.isMuted ? 'Đã tắt tiếng mic' : 'Đã bật lại mic',
    );
  }

  void _showMicTestDialog() {
    final service = ref.read(voiceConversationServiceProvider);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.mic_none_rounded, color: AppColors.primaryBlueDark),
                SizedBox(width: 8),
                Text('Kiểm tra Microphone'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Hãy nói vào mic của thiết bị để kiểm tra mức âm lượng (amplitude) thực tế trước khi vào đàm thoại.',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                StreamBuilder<double>(
                  stream: service.amplitudeStream,
                  initialData: 0.0,
                  builder: (context, snapshot) {
                    final amp = snapshot.data ?? 0.0;
                    return Column(
                      children: [
                        LinearProgressIndicator(
                          value: amp.clamp(0.0, 1.0),
                          backgroundColor: Colors.grey.shade300,
                          color: AppColors.primaryBlueDark,
                          minHeight: 12,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Cường độ: ${(amp * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            actions: [
              if (!_isMicTesting)
                HiButton(
                  text: 'Bắt đầu đo',
                  size: HiButtonSize.sm,
                  variant: HiButtonVariant.primary,
                  onPressed: () async {
                    setDialogState(() => _isMicTesting = true);
                    await service.startMicTest();
                  },
                )
              else
                HiButton(
                  text: 'Dừng đo',
                  size: HiButtonSize.sm,
                  variant: HiButtonVariant.secondary,
                  onPressed: () async {
                    setDialogState(() => _isMicTesting = false);
                    await service.stopMicTest();
                  },
                ),
              HiButton(
                text: 'Đóng',
                size: HiButtonSize.sm,
                variant: HiButtonVariant.ghost,
                onPressed: () async {
                  if (_isMicTesting) {
                    await service.stopMicTest();
                    _isMicTesting = false;
                  }
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLiveApiDiagnosticDialog() {
    const previewInfo = LiveApiPreviewInfo();
    HiDialog.show(
      context: context,
      title: 'Voice Live API (Firebase AI Logic)',
      content: SizedBox(
        height: 250,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                border: Border.all(color: Colors.amber.shade400),
                borderRadius: AppRadius.borderSm,
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.amber, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Trạng thái: Feature Preview (Chưa GA)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Model đề xuất: ${previewInfo.previewModelName}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              previewInfo.limitationNotice,
              style: const TextStyle(fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'Giải pháp kiến trúc hiện hành:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 4),
            const Text(
              '• Tầng Audio: Thu âm thực tế qua AudioRecorderService và phát âm chuẩn qua AudioPlayerService.\n'
              '• VAD & Turn Engine: Xử lý theo lượt (Turn-based) đảm bảo context sư phạm & không mất dữ liệu.\n'
              '• Chuyển tiếp linh hoạt: Sẵn sàng đấu nối WebSocket Live API khi Firebase Vertex AI Logic chính thức phát hành endpoint sản xuất.',
              style: TextStyle(fontSize: 11, height: 1.4),
            ),
          ],
        ),
      ),
    ),
      confirmText: 'Đã hiểu',
      cancelText: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final persona = ref.watch(activePersonaProvider);
    final scenario = ref.watch(activeScenarioProvider);
    final service = ref.watch(voiceConversationServiceProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primaryBlueDark.withAlpha(40),
              child: Text(
                persona.avatarLabel,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hội thoại: ${persona.nameZh}',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  scenario.titleVi,
                  style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_external_on_rounded),
            tooltip: 'Kiểm tra mic',
            onPressed: _showMicTestDialog,
          ),
          IconButton(
            icon: Icon(
              service.previewStatus.isPlaying ? Icons.stop_rounded : Icons.volume_up_outlined,
            ),
            tooltip: service.previewStatus.isPlaying ? 'Dừng phát giọng mẫu' : 'Nghe thử giọng mẫu',
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              if (service.previewStatus.isPlaying) {
                await service.stopPersonaVoicePreview();
              } else {
                await service.previewPersonaVoice(persona);
                if (mounted && service.previewStatus.message != null) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(service.previewStatus.message!),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Status & Live API Preview Banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6.0),
              color: isDark ? AppColors.cardBackground : theme.colorScheme.surfaceContainerHighest.withAlpha(70),
              child: Row(
                children: [
                  _buildStatusChip(_currentStatus),
                  const Spacer(),
                  InkWell(
                    onTap: _showLiveApiDiagnosticDialog,
                    borderRadius: AppRadius.borderSm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withAlpha(40),
                        borderRadius: AppRadius.borderSm,
                        border: Border.all(color: Colors.amber.withAlpha(120), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.info_outline, size: 12, color: Colors.amber),
                          SizedBox(width: 4),
                          Text(
                            'Live API Preview',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Waveform & Amplitude Meter
            StreamBuilder<double>(
              stream: service.amplitudeStream,
              initialData: 0.0,
              builder: (context, snapshot) {
                final amp = snapshot.data ?? 0.0;
                final isListening = _currentStatus == VoiceConversationStatus.listening;
                return WaveformVisualizer(
                  amplitude: amp,
                  isRecording: isListening && !service.isMuted,
                  duration: Duration.zero,
                );
              },
            ),

            // Realtime Transcripts Scrollable Box
            Expanded(
              child: _transcripts.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.record_voice_over_outlined,
                            size: 48,
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(120),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _currentStatus == VoiceConversationStatus.idle
                                ? 'Nhấn nút gọi để bắt đầu hội thoại với ${persona.nameZh}'
                                : 'Đang lắng nghe giọng nói của bạn...',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: _transcripts.length,
                      itemBuilder: (context, index) {
                        final seg = _transcripts[index];
                        return _buildTranscriptBubble(seg);
                      },
                    ),
            ),

            // Speech Simulation / Input Box (enables testing and accessibility)
            if (_currentStatus == VoiceConversationStatus.listening)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _speechInputController,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Nhập tiếng Trung nếu cần giả lập giọng nói...',
                          hintStyle: const TextStyle(fontSize: 12),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: AppRadius.borderSm),
                        ),
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            service.submitSpeechInput(val.trim());
                            _speechInputController.clear();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                      tooltip: 'Gửi tiếng nói',
                      onPressed: () {
                        final val = _speechInputController.text.trim();
                        if (val.isNotEmpty) {
                          service.submitSpeechInput(val);
                          _speechInputController.clear();
                        }
                      },
                    ),
                  ],
                ),
              ),

            // Control Action Row (Start/Stop, Mute, Interrupt)
            _buildControlBar(service),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(VoiceConversationStatus status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case VoiceConversationStatus.idle:
        color = Colors.grey;
        label = 'Sẵn sàng';
        icon = Icons.radio_button_unchecked;
        break;
      case VoiceConversationStatus.requestingPermission:
        color = Colors.amber;
        label = 'Xin quyền mic...';
        icon = Icons.lock_clock;
        break;
      case VoiceConversationStatus.connecting:
        color = Colors.cyan;
        label = 'Đang kết nối...';
        icon = Icons.sync;
        break;
      case VoiceConversationStatus.listening:
        color = AppColors.primaryBlueDark;
        label = 'Đang lắng nghe...';
        icon = Icons.hearing;
        break;
      case VoiceConversationStatus.processing:
        color = Colors.purple;
        label = 'AI đang xử lý...';
        icon = Icons.psychology;
        break;
      case VoiceConversationStatus.speaking:
        color = Colors.blue;
        label = 'AI đang nói...';
        icon = Icons.volume_up;
        break;
      case VoiceConversationStatus.interrupted:
        color = Colors.orange;
        label = 'Đã ngắt lời AI';
        icon = Icons.pause_circle_outline;
        break;
      case VoiceConversationStatus.reconnecting:
        color = Colors.amber;
        label = 'Đang kết nối lại...';
        icon = Icons.refresh;
        break;
      case VoiceConversationStatus.error:
        color = Colors.red;
        label = 'Lỗi kết nối';
        icon = Icons.error_outline;
        break;
      case VoiceConversationStatus.ended:
        color = Colors.blueGrey;
        label = 'Đã kết thúc';
        icon = Icons.call_end;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: AppRadius.borderSm,
        border: Border.all(color: color.withAlpha(120), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptBubble(VoiceTranscriptSegment seg) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final isUser = seg.isUser;
    final isInterim = seg.isInterim;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: AppSpacing.sm,
          left: isUser ? AppSpacing.huge : 0,
          right: isUser ? 0 : AppSpacing.huge,
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: isUser
              ? (isDark ? AppColors.cardBackground : theme.colorScheme.primaryContainer)
              : (isDark ? AppColors.cardBackground : Colors.white),
          borderRadius: AppRadius.borderMd,
          border: Border.all(
            color: isInterim
                ? Colors.amber.withAlpha(160)
                : (isDark ? AppColors.darkForestBorder : theme.colorScheme.outlineVariant),
            style: isInterim ? BorderStyle.solid : BorderStyle.solid,
            width: isInterim ? 1.4 : 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (isInterim)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 8,
                    height: 8,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.amber),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Đang nhận dạng...',
                    style: TextStyle(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: Colors.amber.shade700,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 2),
            RubyText.fromAnnotatedString(
              annotatedText: seg.text,
              showPinyin: true,
            ),
            if (seg.pinyin != null && seg.pinyin!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                seg.pinyin!,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? AppColors.primaryBlueDark : theme.colorScheme.primary,
                ),
              ),
            ],
            if (seg.translationVi != null && seg.translationVi!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                seg.translationVi!,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar(VoiceConversationService service) {
    final isSessionActive = _currentStatus == VoiceConversationStatus.listening ||
        _currentStatus == VoiceConversationStatus.speaking ||
        _currentStatus == VoiceConversationStatus.processing ||
        _currentStatus == VoiceConversationStatus.connecting ||
        _currentStatus == VoiceConversationStatus.interrupted;

    final canInterrupt = _currentStatus == VoiceConversationStatus.speaking;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: 0.6),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute / Unmute
          IconButton.filledTonal(
            icon: Icon(service.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded),
            tooltip: service.isMuted ? 'Bật mic' : 'Tắt mic',
            onPressed: isSessionActive ? _toggleMute : null,
          ),

          // Main Call Start / End Button
          if (!isSessionActive)
            IconButton.filled(
              icon: const Icon(Icons.call_rounded, size: 28),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primaryBlueDark,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              tooltip: 'Bắt đầu đàm thoại',
              onPressed: _startVoiceSession,
            )
          else
            IconButton.filled(
              icon: const Icon(Icons.call_end_rounded, size: 28),
              style: IconButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              tooltip: 'Kết thúc đàm thoại',
              onPressed: _endVoiceSession,
            ),

          // Interrupt AI speech button
          IconButton.filledTonal(
            icon: const Icon(Icons.front_hand_rounded),
            tooltip: 'Ngắt lời AI',
            onPressed: canInterrupt ? _interruptAi : null,
          ),
        ],
      ),
    );
  }
}
