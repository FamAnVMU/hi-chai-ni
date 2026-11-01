import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/core/utils/permission_helper.dart';
import 'package:hi_chinese/features/pronunciation/presentation/widgets/waveform_visualizer.dart';
import 'package:hi_chinese/features/shadowing/shadowing.dart';

class FakeShadowingRepository implements ShadowingRepository {
  final List<ShadowingAssessmentResult> recorded = [];
  bool audioDeleted = false;

  @override
  Future<String> recordShadowingSession({
    required ShadowingAssessmentResult assessment,
    DateTime? timestamp,
  }) async {
    recorded.add(assessment);
    return 'FAKE_EVI_SHADOW_${assessment.segmentId}';
  }

  @override
  Future<void> deleteRecordingAudio({
    required String audioPath,
    required String? evidenceId,
    bool retainEvidence = true,
  }) async {
    audioDeleted = true;
  }

  @override
  Future<List<Map<String, dynamic>>> getRecentShadowingSessions({
    String? segmentId,
    int limit = 10,
  }) async {
    return [];
  }
}

void main() {
  late FakeShadowingRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeShadowingRepository();
    PermissionHelper.mockPermissionResult = AudioPermissionResult.granted;
  });

  tearDown(() {
    PermissionHelper.mockPermissionResult = null;
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        shadowingRepositoryProvider.overrideWithValue(fakeRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ShadowingScreen(),
      ),
    );
  }

  group('ShadowingScreen Widget Tests', () {
    testWidgets('1. Renders title, sentence with RubyText, and mode/speed selectors', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Luyện Nói Đuổi (Shadowing)'), findsOneWidget);
      expect(find.textContaining('Chào hỏi và làm quen'), findsOneWidget);
      expect(find.text('Câu 1/3'), findsOneWidget);
      expect(find.text('Nghe nhắc lại'), findsOneWidget);
      expect(find.text('Nói đuổi'), findsOneWidget);
      expect(find.text('0.75x (Chậm)'), findsOneWidget);
      expect(find.text('1.0x (Chuẩn)'), findsOneWidget);
      expect(find.text('1.25x (Nhanh)'), findsOneWidget);
      expect(find.byType(WaveformVisualizer), findsOneWidget);
    });

    testWidgets('2. Mode and speed toggles function properly', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap 'Nói đuổi'
      await tester.tap(find.text('Nói đuổi'));
      await tester.pumpAndSettle();

      // Tap '1.25x (Nhanh)'
      await tester.tap(find.text('1.25x (Nhanh)'));
      await tester.pumpAndSettle();

      expect(find.textContaining('1.25x (Nhanh)'), findsAtLeastNWidgets(1));
    });

    testWidgets('3. Recording workflow triggers assessment and renders ShadowingTimelineCard', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap mic to record
      final micFinder = find.byIcon(Icons.mic_rounded);
      await tester.ensureVisible(micFinder);
      await tester.tap(micFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Stop record
      final stopFinder = find.byIcon(Icons.stop_rounded);
      await tester.ensureVisible(stopFinder);
      await tester.tap(stopFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.byType(ShadowingTimelineCard), findsOneWidget);
      expect(find.text('Đối Chiếu Nhịp Độ & Timeline'), findsOneWidget);
      expect(find.text('Bản mẫu:'), findsOneWidget);
      expect(find.text('Bạn nói:'), findsOneWidget);
      expect(fakeRepo.recorded.length, equals(1));
    });

    testWidgets('4. Next and previous segment navigation', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Câu 1/3'), findsOneWidget);

      // Tap Next sentence
      final nextBtn = find.byTooltip('Câu tiếp theo');
      await tester.ensureVisible(nextBtn);
      await tester.tap(nextBtn);
      await tester.pumpAndSettle();

      expect(find.text('Câu 2/3'), findsOneWidget);

      // Tap Previous sentence
      final prevBtn = find.byTooltip('Câu trước');
      await tester.ensureVisible(prevBtn);
      await tester.tap(prevBtn);
      await tester.pumpAndSettle();

      expect(find.text('Câu 1/3'), findsOneWidget);
    });
  });
}
