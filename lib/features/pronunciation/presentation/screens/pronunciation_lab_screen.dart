import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/audio/audio.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../domain/models/pronunciation_models.dart';
import '../providers/pronunciation_providers.dart';
import '../widgets/pronunciation_result_card.dart';
import '../widgets/waveform_visualizer.dart';

/// Pronunciation Lab screen dedicated to phoneme and tone level vocal training.
class PronunciationLabScreen extends ConsumerStatefulWidget {
  final String? initialTargetId;

  const PronunciationLabScreen({
    super.key,
    this.initialTargetId,
  });

  @override
  ConsumerState<PronunciationLabScreen> createState() => _PronunciationLabScreenState();
}

class _PronunciationLabScreenState extends ConsumerState<PronunciationLabScreen> {
  late final AudioPlayerService _player;
  late final AudioRecorderService _recorder;

  StreamSubscription<double>? _ampSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<AudioPlaybackStatus>? _playStatusSub;

  double _currentAmplitude = 0.0;
  Duration _recordingDuration = Duration.zero;
  bool _isRecording = false;
  bool _isPlayingUserAudio = false;
  bool _isPlayingSample = false;
  String? _recordedFilePath;

  @override
  void initState() {
    super.initState();
    _player = DefaultAudioPlayerService();
    _recorder = DefaultAudioRecorderService();

    if (widget.initialTargetId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(selectedPronunciationTargetProvider.notifier)
            .selectTargetById(widget.initialTargetId!);
      });
    }

    _ampSub = _recorder.amplitudeStream.listen((amp) {
      if (mounted) setState(() => _currentAmplitude = amp);
    });

    _durSub = _recorder.durationStream.listen((dur) {
      if (mounted) setState(() => _recordingDuration = dur);
    });

    _playStatusSub = _player.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _isPlayingSample = status == AudioPlaybackStatus.playing && !_isPlayingUserAudio;
          _isPlayingUserAudio = status == AudioPlaybackStatus.playing && _isPlayingUserAudio;
        });
      }
    });
  }

  @override
  void dispose() {
    _ampSub?.cancel();
    _durSub?.cancel();
    _playStatusSub?.cancel();
    if (_recordedFilePath != null) {
      AudioTempCleaner.deleteAudioFile(_recordedFilePath);
    }
    _recorder.cancelRecording();
    _recorder.dispose();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _handlePlaySample(PronunciationTarget target) async {
    if (_isPlayingSample) {
      await _player.stop();
      setState(() => _isPlayingSample = false);
    } else {
      setState(() {
        _isPlayingUserAudio = false;
        _isPlayingSample = true;
      });
      await _player.play(target.audioUri ?? 'sample.mp3');
    }
  }

  Future<void> _handleToggleRecording() async {
    if (_isRecording) {
      // Stop recording
      final path = await _recorder.stopRecording();
      setState(() {
        _isRecording = false;
        _recordedFilePath = path;
      });
      await _evaluateRecordedAudio();
    } else {
      // Request permission with rationale
      final perm = await PermissionHelper.requestMicrophoneWithRationale(
        context,
        featureName: 'Luyện Phát Âm (Pronunciation Lab)',
      );

      if (perm == AudioPermissionResult.granted) {
        await _player.stop();
        if (_recordedFilePath != null) {
          AudioTempCleaner.deleteAudioFile(_recordedFilePath);
        }
        setState(() {
          _isRecording = true;
          _recordedFilePath = null;
        });
        await _recorder.startRecording();
      } else {
        if (mounted) {
          HiSnackBar.showWarning(
            context,
            'Cần quyền truy cập Micro để thu âm phát âm của bạn.',
          );
        }
      }
    }
  }

  Future<void> _evaluateRecordedAudio() async {
    if (_recordedFilePath == null) return;

    final target = ref.read(selectedPronunciationTargetProvider);
    final service = ref.read(pronunciationAnalysisServiceProvider);
    final repo = ref.read(pronunciationRepositoryProvider);

    final result = await service.evaluatePronunciation(
      target: target,
      audioPath: _recordedFilePath!,
      duration: _recordingDuration,
    );

    ref.read(lastPronunciationResultProvider.notifier).setResult(result);

    try {
      final evidenceId = await repo.recordPronunciationSession(assessment: result);
      ref.read(lastPronunciationEvidenceIdProvider.notifier).setEvidenceId(evidenceId);
    } catch (_) {}
  }

  Future<void> _handlePlayUserAudio() async {
    if (_recordedFilePath == null) return;

    if (_isPlayingUserAudio) {
      await _player.stop();
      setState(() => _isPlayingUserAudio = false);
    } else {
      setState(() {
        _isPlayingSample = false;
        _isPlayingUserAudio = true;
      });
      await _player.play(_recordedFilePath!);
    }
  }

  Future<void> _handleDeleteAudio() async {
    if (_recordedFilePath == null) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa Bản Thu Âm'),
        content: const Text(
          'Bạn có muốn xóa file ghi âm này khỏi bộ nhớ thiết bị không?\n\n'
          'Kết quả đánh giá học tập trong nhật ký vẫn sẽ được bảo toàn.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa file'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      final repo = ref.read(pronunciationRepositoryProvider);
      final evidenceId = ref.read(lastPronunciationEvidenceIdProvider);

      await repo.deleteRecordingAudio(
        audioPath: _recordedFilePath!,
        evidenceId: evidenceId,
        retainEvidence: true,
      );

      setState(() {
        _recordedFilePath = null;
        _isPlayingUserAudio = false;
      });

      if (mounted) {
        HiSnackBar.showSuccess(
          context,
          'Đã xóa file âm thanh. Kết quả học tập được lưu trữ an toàn.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final target = ref.watch(selectedPronunciationTargetProvider);
    final bank = ref.watch(pronunciationItemBankProvider);
    final lastResult = ref.watch(lastPronunciationResultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phòng Luyện Phát Âm'),
        actions: [
          PopupMenuButton<PronunciationCategory>(
            icon: const Icon(Icons.filter_list_rounded),
            tooltip: 'Lọc danh mục phát âm',
            onSelected: (cat) {
              final targets = bank.getTargetsByCategory(cat);
              if (targets.isNotEmpty) {
                ref
                    .read(selectedPronunciationTargetProvider.notifier)
                    .selectTarget(targets.first);
              }
            },
            itemBuilder: (ctx) {
              return PronunciationCategory.values.map((cat) {
                return PopupMenuItem(
                  value: cat,
                  child: Text(cat.labelVi),
                );
              }).toList();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.screenPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Category Switcher Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: bank.targets.map((t) {
                    final isSelected = t.id == target.id;
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: HiChip(
                        label: '${t.text} (${t.pinyin})',
                        isSelected: isSelected,
                        onTap: () {
                          ref
                              .read(selectedPronunciationTargetProvider.notifier)
                              .selectTarget(t);
                          setState(() {
                            _recordedFilePath = null;
                          });
                          ref
                              .read(lastPronunciationResultProvider.notifier)
                              .setResult(null);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 2. Target Pronunciation Focus Card
              HiCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    Text(
                      target.text,
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlueDark,
                        fontFamilyFallback: const ['Noto Sans SC', 'Heiti SC'],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    RubyText(
                      segments: [
                        RubySegment(text: target.text, pinyin: target.pinyin),
                      ],
                      hanziStyle: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (target.ipa != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'IPA: ${target.ipa}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      target.meaningVi,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (target.hintVi.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest.withAlpha(90),
                          borderRadius: AppRadius.borderMd,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.tips_and_updates_outlined, size: 16, color: AppColors.primaryBlueDark),
                            const SizedBox(width: AppSpacing.xs),
                            Expanded(
                              child: Text(
                                target.hintVi,
                                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.md),

                    // Play Sample Audio Button
                    HiButton(
                      text: _isPlayingSample ? 'Đang phát âm mẫu...' : 'Nghe phát âm chuẩn',
                      icon: Icon(_isPlayingSample ? Icons.stop_rounded : Icons.volume_up_rounded),
                      variant: HiButtonVariant.secondary,
                      size: HiButtonSize.md,
                      onPressed: () => _handlePlaySample(target),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 3. Realtime Audio Waveform Visualizer
              WaveformVisualizer(
                amplitude: _currentAmplitude,
                isRecording: _isRecording,
                duration: _recordingDuration,
              ),
              const SizedBox(height: AppSpacing.lg),

              // 4. Primary Microphone Action Button
              Center(
                child: Semantics(
                  label: _isRecording ? 'Dừng thu âm' : 'Nhấn để bắt đầu thu âm phát âm',
                  button: true,
                  child: InkWell(
                    onTap: _handleToggleRecording,
                    borderRadius: AppRadius.borderFull,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isRecording ? Colors.redAccent : AppColors.primaryBlueDark,
                        boxShadow: AppElevation.shadowMid(theme.brightness),
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                        size: 40,
                        color: _isRecording ? Colors.white : AppColors.primaryText,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Center(
                child: Text(
                  _isRecording ? 'Chạm để dừng và phân tích' : 'Chạm micro để bắt đầu nói',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // 5. Objective Assessment Result Card
              if (lastResult != null) ...[
                PronunciationResultCard(
                  result: lastResult,
                  onPlayUserAudio: _handlePlayUserAudio,
                  onDeleteAudio: _handleDeleteAudio,
                  isPlayingAudio: _isPlayingUserAudio,
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
