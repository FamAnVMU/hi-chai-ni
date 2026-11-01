import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../providers/hanzi_writing_providers.dart';
import '../widgets/hanzi_canvas.dart';
import '../widgets/hanzi_canvas_controller.dart';
import '../widgets/writing_evaluation_sheet.dart';
import '../widgets/writing_toolbar.dart';

/// Screen dedicated to practicing Chinese character handwriting with touch/stylus,
/// stroke order evaluation, and customizable tracing/freeform modes.
class HanziWritingScreen extends ConsumerStatefulWidget {
  final String? initialCharacter;

  const HanziWritingScreen({
    super.key,
    this.initialCharacter,
  });

  @override
  ConsumerState<HanziWritingScreen> createState() => _HanziWritingScreenState();
}

class _HanziWritingScreenState extends ConsumerState<HanziWritingScreen> {
  late final HanziCanvasController _canvasController;
  int? _highlightedStrokeOrder;
  DateTime _sessionStartTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _canvasController = HanziCanvasController();
    _sessionStartTime = DateTime.now();

    if (widget.initialCharacter != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedHanziCharacterProvider.notifier).selectCharacter(
              widget.initialCharacter!,
            );
      });
    }
  }

  @override
  void dispose() {
    _canvasController.dispose();
    super.dispose();
  }

  void _handleEvaluate() {
    final character = ref.read(selectedHanziCharacterProvider);
    final strokeData = ref.read(currentHanziStrokeDataProvider);
    final evaluator = ref.read(strokeEvaluatorProvider);

    final canvasSize = _canvasController.canvasSize;

    final result = evaluator.evaluate(
      drawnStrokes: _canvasController.strokes,
      canvasSize: canvasSize,
      strokeData: strokeData,
      mode: _canvasController.mode,
    );

    WritingEvaluationSheet.show(
      context: context,
      result: result,
      onRetry: () {
        _canvasController.reset();
        setState(() {
          _highlightedStrokeOrder = null;
        });
      },
      onSaveAndClose: () async {
        final durationMs =
            DateTime.now().difference(_sessionStartTime).inMilliseconds;
        try {
          final repo = ref.read(hanziWritingRepositoryProvider);
          await repo.recordWritingSession(
            character: character,
            evaluation: result,
            durationMs: durationMs,
          );
          if (mounted) {
            HiSnackBar.showSuccess(
              context,
              'Đã lưu kết quả luyện viết chữ "$character" vào nhật ký học tập.',
            );
          }
        } catch (e) {
          if (mounted) {
            HiSnackBar.showError(
              context,
              'Không thể lưu kết quả: ${e.toString()}',
            );
          }
        }
      },
    );
  }

  void _handleStepReplay() {
    final strokeData = ref.read(currentHanziStrokeDataProvider);
    if (strokeData == null || strokeData.strokes.isEmpty) return;

    final current = _highlightedStrokeOrder ?? 0;
    final next = (current % strokeData.totalStrokes) + 1;

    setState(() {
      _highlightedStrokeOrder = next;
    });

    final stroke = strokeData.getStroke(next - 1);
    if (stroke != null) {
      HiSnackBar.showInfo(
        context,
        'Nét $next/${strokeData.totalStrokes}: ${stroke.nameVi}',
      );
    }
  }

  void _switchCharacter(String newChar) {
    ref.read(selectedHanziCharacterProvider.notifier).selectCharacter(newChar);
    _canvasController.reset();
    setState(() {
      _highlightedStrokeOrder = null;
      _sessionStartTime = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final character = ref.watch(selectedHanziCharacterProvider);
    final strokeData = ref.watch(currentHanziStrokeDataProvider);
    final bank = ref.watch(hanziStrokeBankProvider);

    final pinyin = strokeData?.pinyin ?? '';
    final meaning = strokeData?.meaningVi ?? 'Chữ Hán';
    final strokeCount = strokeData?.totalStrokes ?? 0;
    final hasStrokeData = strokeData != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Luyện Viết Chữ Hán'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Chọn chữ Hán luyện tập',
            onSelected: _switchCharacter,
            itemBuilder: (context) {
              return bank.availableCharacters.map((char) {
                final data = bank.getStrokeData(char);
                return PopupMenuItem(
                  value: char,
                  child: Text('$char  (${data?.pinyin ?? ""}) — ${data?.meaningVi ?? ""}'),
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
              // 1. Character Header Info Card
              HiCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Text(
                      character,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.limeGreen,
                        fontFamilyFallback: const ['Noto Sans SC', 'Heiti SC'],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                pinyin,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              if (strokeCount > 0)
                                HiChip(
                                  label: '$strokeCount nét',
                                  status: HiChipStatus.info,
                                ),
                            ],
                          ),
                          Text(
                            meaning,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.volume_up_rounded),
                      tooltip: 'Nghe phát âm',
                      onPressed: () {
                        HiSnackBar.showSuccess(
                          context,
                          'Phát âm: $character ($pinyin)',
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Notice when character lacks standard stroke data
              if (!hasStrokeData) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: Colors.amber.withAlpha(25),
                    borderRadius: AppRadius.borderMd,
                    border: Border.all(color: Colors.amber.withAlpha(100)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          'Chưa có dữ liệu thứ tự nét cho chữ "$character". Bạn có thể tự do luyện viết trên ô lưới.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],

              // 2. Mizige Calligraphy Canvas
              LayoutBuilder(
                builder: (context, constraints) {
                  final canvasSize = constraints.maxWidth < 320.0
                      ? constraints.maxWidth
                      : 320.0;
                  return HanziCanvas(
                    controller: _canvasController,
                    character: character,
                    strokeData: strokeData,
                    highlightedStrokeOrder: _highlightedStrokeOrder,
                    size: canvasSize,
                  );
                },
              ),
              const SizedBox(height: AppSpacing.lg),

              // 3. Writing Toolbar (Mode toggle, stroke width, undo, evaluate)
              WritingToolbar(
                controller: _canvasController,
                hasStrokeData: hasStrokeData,
                onEvaluate: _handleEvaluate,
                onReplay: hasStrokeData ? _handleStepReplay : null,
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}
