import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/audio/audio.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../../pronunciation/presentation/widgets/waveform_visualizer.dart';
import '../../domain/models/shadowing_models.dart';
import '../providers/shadowing_providers.dart';
import '../widgets/shadowing_timeline_card.dart';

/// Screen dedicated to Shadowing practice (sentence & conversational level fluency training).
class ShadowingScreen extends ConsumerStatefulWidget {
  final String? initialDocumentId;

  const ShadowingScreen({
    super.key,
    this.initialDocumentId,
  });

  @override
  ConsumerState<ShadowingScreen> createState() => _ShadowingScreenState();
}

class _ShadowingScreenState extends ConsumerState<ShadowingScreen> {
  late final AudioPlayerService _player;
  late final AudioRecorderService _recorder;

  StreamSubscription<double>? _ampSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<AudioPlaybackStatus>? _playStatusSub;

  double _currentAmplitude = 0.0;
  Duration _recordingDuration = Duration.zero;
  bool _isRecording = false;
  bool _isPlayingSample = false;
  bool _isPlayingUserAudio = false;
  bool _isLooping = false;
  String? _recordedFilePath;

  @override
  void initState() {
    super.initState();
    _player = DefaultAudioPlayerService();
    _recorder = DefaultAudioRecorderService();

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
    _recorder.cancelRecording();
    _recorder.dispose();
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _handlePlaySample(ShadowingSegment segment, ShadowingPlaybackSpeed speed) async {
    if (_isPlayingSample) {
      await _player.stop();
      setState(() => _isPlayingSample = false);
    } else {
      setState(() {
        _isPlayingUserAudio = false;
        _isPlayingSample = true;
      });
      await _player.play(
        segment.audioUri ?? 'sample.mp3',
        speed: speed.rate,
        loop: _isLooping,
        simulatedDuration: Duration(milliseconds: segment.durationMs),
      );
    }
  }

  Future<void> _handleToggleRecording(ShadowingSegment segment) async {
    if (_isRecording) {
      final path = await _recorder.stopRecording();
      setState(() {
        _isRecording = false;
        _recordedFilePath = path;
      });
      await _evaluateShadowing(segment);
    } else {
      final perm = await PermissionHelper.requestMicrophoneWithRationale(
        context,
        featureName: 'Luyện Nói Đuổi (Shadowing)',
      );

      if (perm == AudioPermissionResult.granted) {
        final mode = ref.read(shadowingModeProvider);
        final speed = ref.read(shadowingPlaybackSpeedProvider);

        if (mode == ShadowingMode.simultaneous) {
          // In simultaneous mode, play sample audio alongside recording
          _player.play(
            segment.audioUri ?? 'sample.mp3',
            speed: speed.rate,
            loop: false,
            simulatedDuration: Duration(milliseconds: segment.durationMs),
          );
        } else {
          await _player.stop();
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
            'Cần cấp quyền Microphone để thu âm giọng nói của bạn.',
          );
        }
      }
    }
  }

  Future<void> _evaluateShadowing(ShadowingSegment segment) async {
    if (_recordedFilePath == null) return;

    final evaluator = ref.read(shadowingEvaluatorProvider);
    final repo = ref.read(shadowingRepositoryProvider);
    final mode = ref.read(shadowingModeProvider);
    final speed = ref.read(shadowingPlaybackSpeedProvider);

    final result = evaluator.evaluate(
      segment: segment,
      userDuration: _recordingDuration,
      mode: mode,
      speed: speed,
      audioPath: _recordedFilePath,
    );

    ref.read(lastShadowingResultProvider.notifier).setResult(result);

    try {
      final evidenceId = await repo.recordShadowingSession(assessment: result);
      ref.read(lastShadowingEvidenceIdProvider.notifier).setEvidenceId(evidenceId);
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
          'Bạn có muốn xóa file ghi âm Shadowing này khỏi máy không?\n\n'
          'Chỉ số nhịp độ và bằng chứng hoàn thành bài tập vẫn được lưu trữ trong nhật ký.',
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
      final repo = ref.read(shadowingRepositoryProvider);
      final evidenceId = ref.read(lastShadowingEvidenceIdProvider);

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
          'Đã xóa file thu âm. Kết quả học tập được bảo toàn an toàn.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final document = ref.watch(selectedShadowingDocumentProvider);
    final segmentIndex = ref.watch(selectedSegmentIndexProvider);
    final mode = ref.watch(shadowingModeProvider);
    final speed = ref.watch(shadowingPlaybackSpeedProvider);
    final lastResult = ref.watch(lastShadowingResultProvider);

    final segments = document.segments;
    final activeSegment = segments[segmentIndex.clamp(0, segments.length - 1)];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện Nói Đuổi (Shadowing)'),
        actions: [
          IconButton(
            icon: Icon(_isLooping ? Icons.repeat_one_on_rounded : Icons.repeat_rounded),
            tooltip: _isLooping ? 'Tắt lặp lại câu' : 'Bật lặp lại câu',
            color: _isLooping ? AppColors.primaryBlueDark : null,
            onPressed: () {
              setState(() {
                _isLooping = !_isLooping;
                _player.setLooping(_isLooping);
              });
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
              // 1. Document Overview & Segment Stepper
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          document.description,
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  HiChip(
                    label: 'Câu ${segmentIndex + 1}/${segments.length}',
                    status: HiChipStatus.info,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // 2. Mode Switch & Speed Chips
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  SegmentedButton<ShadowingMode>(
                    segments: const [
                      ButtonSegment(
                        value: ShadowingMode.listenThenRepeat,
                        label: Text('Nghe nhắc lại'),
                        icon: Icon(Icons.headphones_rounded, size: 16),
                      ),
                      ButtonSegment(
                        value: ShadowingMode.simultaneous,
                        label: Text('Nói đuổi'),
                        icon: Icon(Icons.record_voice_over_rounded, size: 16),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: (set) {
                      if (set.isNotEmpty) {
                        ref.read(shadowingModeProvider.notifier).setMode(set.first);
                      }
                    },
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: ShadowingPlaybackSpeed.values.map((s) {
                      return Padding(
                        padding: const EdgeInsets.only(left: 4.0),
                        child: ChoiceChip(
                          label: Text(s.labelVi),
                          selected: speed == s,
                          onSelected: (_) {
                            ref.read(shadowingPlaybackSpeedProvider.notifier).setSpeed(s);
                            _player.setPlaybackSpeed(s.rate);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // 3. Active Sentence Card
              HiCard(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    RubyText(
                      segments: [
                        RubySegment(
                          text: activeSegment.hanzi,
                          pinyin: activeSegment.pinyin,
                        ),
                      ],
                      hanziStyle: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryBlueDark,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      activeSegment.meaningVi,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // Play Native Model Speech Button
                    HiButton(
                      text: _isPlayingSample ? 'Đang phát mẫu...' : 'Phát câu mẫu (${speed.labelVi})',
                      icon: Icon(_isPlayingSample ? Icons.stop_rounded : Icons.volume_up_rounded),
                      variant: HiButtonVariant.secondary,
                      size: HiButtonSize.md,
                      onPressed: () => _handlePlaySample(activeSegment, speed),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 4. Waveform Visualizer
              WaveformVisualizer(
                amplitude: _currentAmplitude,
                isRecording: _isRecording,
                duration: _recordingDuration,
              ),
              const SizedBox(height: AppSpacing.lg),

              // 5. Microphone Record Button
              Center(
                child: Semantics(
                  label: _isRecording ? 'Dừng thu âm' : 'Nhấn để thu âm nói đuổi',
                  button: true,
                  child: InkWell(
                    onTap: () => _handleToggleRecording(activeSegment),
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
                  _isRecording ? 'Chạm để hoàn thành câu' : 'Chạm micro để bắt đầu nói đuổi',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 6. Navigation Controls for Segments (Previous / Next)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton.outlined(
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Câu trước',
                    onPressed: segmentIndex > 0
                        ? () {
                            ref.read(selectedSegmentIndexProvider.notifier).previous();
                            setState(() {
                              _recordedFilePath = null;
                            });
                            ref.read(lastShadowingResultProvider.notifier).setResult(null);
                          }
                        : null,
                  ),
                  Text(
                    'Câu ${segmentIndex + 1} / ${segments.length}',
                    style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton.outlined(
                    icon: const Icon(Icons.arrow_forward_rounded),
                    tooltip: 'Câu tiếp theo',
                    onPressed: segmentIndex < segments.length - 1
                        ? () {
                            ref
                                .read(selectedSegmentIndexProvider.notifier)
                                .next(segments.length);
                            setState(() {
                              _recordedFilePath = null;
                            });
                            ref.read(lastShadowingResultProvider.notifier).setResult(null);
                          }
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),

              // 7. Timeline Match & Pacing Result Card
              if (lastResult != null) ...[
                ShadowingTimelineCard(
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
