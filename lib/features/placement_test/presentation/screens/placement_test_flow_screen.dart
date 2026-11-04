import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/theme.dart';
import '../providers/placement_test_providers.dart';
import '../widgets/cat_progress_header.dart';
import '../widgets/cat_question_card.dart';
import 'placement_test_result_screen.dart';

/// Screen managing the active interactive adaptive testing flow.
class PlacementTestFlowScreen extends ConsumerStatefulWidget {
  final void Function(int level)? onTestComplete;
  const PlacementTestFlowScreen({super.key, this.onTestComplete});

  @override
  ConsumerState<PlacementTestFlowScreen> createState() =>
      _PlacementTestFlowScreenState();
}

class _PlacementTestFlowScreenState
    extends ConsumerState<PlacementTestFlowScreen> {
  DateTime _questionStartTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _questionStartTime = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(activeCatSessionProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        var shouldLeave = false;
        await HiDialog.show(
          context: context,
          title: 'Tạm dừng bài kiểm tra?',
          message:
              'Tiến độ và các câu trả lời của bạn đã được tự động lưu vào máy. Bạn có thể tiếp tục làm bài bất kỳ lúc nào!',
          confirmText: 'Lưu & Thoát',
          onConfirm: () => shouldLeave = true,
          cancelText: 'Làm tiếp',
        );

        if (shouldLeave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bài Kiểm Tra Thích Ứng CAT'),
          automaticallyImplyLeading: true,
        ),
        body: SafeArea(
          child: sessionAsync.when(
            loading: () => const Center(
              child: HiLoadingIndicator(message: 'Đang tải câu hỏi thích ứng...'),
            ),
            error: (err, _) => Center(
              child: Padding(
                padding: AppSpacing.screenPadding,
                child: HiErrorState(
                  title: 'Đã có lỗi khi xử lý bài thi',
                  message: err.toString(),
                  onRetry: () =>
                      ref.read(activeCatSessionProvider.notifier).startNewTest(),
                ),
              ),
            ),
            data: (session) {
              if (session == null) {
                return Center(
                  child: Padding(
                    padding: AppSpacing.screenPadding,
                    child: HiEmptyState(
                      title: 'Chưa có bài thi đang hoạt động',
                      description: 'Nhấn nút bên dưới để bắt đầu bài kiểm tra mới.',
                      actionText: 'Bắt đầu',
                      onAction: () => ref
                          .read(activeCatSessionProvider.notifier)
                          .startNewTest(),
                    ),
                  ),
                );
              }

              // If completed, navigate to result screen
              if (session.isCompleted && session.result != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => PlacementTestResultScreen(
                          result: session.result!,
                          onContinue: widget.onTestComplete,
                        ),
                      ),
                    );
                  }
                });
                return const Center(
                  child: HiLoadingIndicator(
                    message: 'Đang tổng hợp báo cáo đánh giá 6 kỹ năng...',
                  ),
                );
              }

              final activeItem = session.activeItem;
              if (activeItem == null) {
                return const Center(
                  child: HiLoadingIndicator(message: 'Đang chuyển kỹ năng...'),
                );
              }

              return SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Progress Header
                    CatProgressHeader(
                      skill: session.currentSkill,
                      stepIndex: session.stepIndex,
                      onSkip: () async {
                        var confirm = false;
                        await HiDialog.show(
                          context: context,
                          title: 'Bỏ qua câu hỏi này?',
                          message:
                              'Câu hỏi sẽ được đánh dấu là bỏ qua và chuyển sang câu tiếp theo.',
                          confirmText: 'Bỏ qua',
                          onConfirm: () => confirm = true,
                          cancelText: 'Làm tiếp',
                        );
                        if (confirm) {
                          ref
                              .read(activeCatSessionProvider.notifier)
                              .skipCurrentQuestion();
                          _questionStartTime = DateTime.now();
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Adaptive Question Card
                    CatQuestionCard(
                      item: activeItem,
                      onAnswerSubmitted: (answer) {
                        final latency =
                            DateTime.now().difference(_questionStartTime).inMilliseconds;
                        ref
                            .read(activeCatSessionProvider.notifier)
                            .submitAnswer(answer, latencyMs: latency);
                        _questionStartTime = DateTime.now();
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
