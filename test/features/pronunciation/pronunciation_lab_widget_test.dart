import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/core/utils/permission_helper.dart';
import 'package:hi_chinese/features/pronunciation/pronunciation.dart';

class FakePronunciationRepository implements PronunciationRepository {
  final List<PronunciationAssessmentResult> recorded = [];
  bool audioDeleted = false;

  @override
  Future<String> recordPronunciationSession({
    required PronunciationAssessmentResult assessment,
    DateTime? timestamp,
  }) async {
    recorded.add(assessment);
    return 'FAKE_EVI_${assessment.targetId}';
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
  Future<List<Map<String, dynamic>>> getRecentPronunciationSessions({
    String? targetId,
    int limit = 10,
  }) async {
    return [];
  }
}

void main() {
  late FakePronunciationRepository fakeRepo;

  setUp(() {
    fakeRepo = FakePronunciationRepository();
    PermissionHelper.mockPermissionResult = AudioPermissionResult.granted;
  });

  tearDown(() {
    PermissionHelper.mockPermissionResult = null;
  });

  Widget buildTestWidget({String? initialTargetId}) {
    return ProviderScope(
      overrides: [
        pronunciationRepositoryProvider.overrideWithValue(fakeRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: PronunciationLabScreen(initialTargetId: initialTargetId),
      ),
    );
  }

  group('PronunciationLabScreen Widget Tests', () {
    testWidgets('1. Renders title, target card, IPA, and action buttons', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Phòng Luyện Phát Âm'), findsOneWidget);
      expect(find.text('妈'), findsAtLeastNWidgets(1));
      expect(find.text('mā'), findsOneWidget);
      expect(find.textContaining('IPA: /ma˥˥/'), findsOneWidget);
      expect(find.text('Nghe phát âm chuẩn'), findsOneWidget);
      expect(find.byType(WaveformVisualizer), findsOneWidget);
    });

    testWidgets('2. Target switching via horizontal chip selector', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap on '麻 (má)' chip
      final ma2Finder = find.text('麻 (má)');
      expect(ma2Finder, findsOneWidget);
      await tester.tap(ma2Finder);
      await tester.pumpAndSettle();

      expect(find.text('má'), findsOneWidget);
      expect(find.textContaining('IPA: /ma˧˥/'), findsOneWidget);
    });

    testWidgets('3. Recording workflow triggers assessment and renders result card', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Tap mic to start recording
      final micFinder = find.byIcon(Icons.mic_rounded);
      await tester.ensureVisible(micFinder);
      await tester.tap(micFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Tap stop to stop recording and trigger analysis
      final stopFinder = find.byIcon(Icons.stop_rounded);
      await tester.ensureVisible(stopFinder);
      await tester.tap(stopFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Result card should appear
      expect(find.byType(PronunciationResultCard), findsOneWidget);
      expect(find.text('Kết Quả Phân Tích'), findsOneWidget);
      expect(find.textContaining('Transcript nhận dạng (ASR)'), findsOneWidget);
      expect(find.text('Nghe lại bản thu'), findsOneWidget);
      expect(fakeRepo.recorded.length, equals(1));
    });

    testWidgets('4. Delete audio dialog retains evidence and shows success snackbar', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Run a quick record
      final micFinder = find.byIcon(Icons.mic_rounded);
      await tester.ensureVisible(micFinder);
      await tester.tap(micFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final stopFinder = find.byIcon(Icons.stop_rounded);
      await tester.ensureVisible(stopFinder);
      await tester.tap(stopFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Tap delete icon
      final deleteBtn = find.byTooltip('Xóa bản thu âm');
      await tester.ensureVisible(deleteBtn);
      expect(deleteBtn, findsOneWidget);
      await tester.tap(deleteBtn);
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Xóa Bản Thu Âm'), findsOneWidget);
      expect(find.textContaining('Kết quả đánh giá học tập trong nhật ký vẫn sẽ được bảo toàn'), findsOneWidget);

      // Confirm deletion
      await tester.tap(find.text('Xóa file'));
      await tester.pumpAndSettle();

      expect(fakeRepo.audioDeleted, isTrue);
    });
  });
}
