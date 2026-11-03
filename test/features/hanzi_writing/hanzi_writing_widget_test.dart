import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/features/hanzi_writing/hanzi_writing.dart';

class FakeHanziWritingRepository implements HanziWritingRepository {
  final List<Map<String, dynamic>> recordedSessions = [];

  @override
  Future<void> recordWritingSession({
    required String character,
    required WritingEvaluationResult evaluation,
    int durationMs = 0,
    DateTime? timestamp,
    Duration? timeZoneOffset,
  }) async {
    recordedSessions.add({
      'character': character,
      'evaluation': evaluation,
      'durationMs': durationMs,
      'timestamp': timestamp ?? DateTime.now(),
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getRecentWritingSessions({
    String? character,
    int limit = 10,
  }) async {
    return recordedSessions;
  }
}

void main() {
  late FakeHanziWritingRepository fakeRepository;

  setUp(() {
    fakeRepository = FakeHanziWritingRepository();
  });

  Widget buildTestWidget({
    String? initialCharacter,
    List<dynamic>? extraOverrides,
  }) {
    return ProviderScope(
      overrides: [
        hanziWritingRepositoryProvider.overrideWithValue(fakeRepository),
        ...?extraOverrides?.cast(),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: HanziWritingScreen(
          initialCharacter: initialCharacter,
        ),
      ),
    );
  }

  group('HanziWritingScreen & Canvas Widget Tests', () {
    testWidgets('1. Renders character header, pinyin, canvas and controls correctly', (tester) async {
      await tester.pumpWidget(buildTestWidget(initialCharacter: '十'));
      await tester.pumpAndSettle();

      // Header checks
      expect(find.text('Luyện Viết Chữ Hán'), findsOneWidget);
      expect(find.text('十'), findsOneWidget);
      expect(find.text('shí'), findsOneWidget);
      expect(find.text('Số mười'), findsOneWidget);
      expect(find.text('2 nét'), findsOneWidget);

      // Canvas check
      expect(find.byType(HanziCanvas), findsOneWidget);

      // Toolbar checks
      expect(find.byType(WritingToolbar), findsOneWidget);
      expect(find.text('Tô mẫu'), findsOneWidget);
      expect(find.text('Tự viết'), findsOneWidget);
      expect(find.text('Mảnh'), findsOneWidget);
      expect(find.text('Vừa'), findsOneWidget);
      expect(find.text('Đậm'), findsOneWidget);
      expect(find.text('Chấm điểm'), findsOneWidget);
    });

    testWidgets('2. Drawing gesture creates stroke and updates controller state', (tester) async {
      await tester.pumpWidget(buildTestWidget(initialCharacter: '十'));
      await tester.pumpAndSettle();

      final canvasFinder = find.byType(HanziCanvas);
      expect(canvasFinder, findsOneWidget);

      // Touch gesture: draw horizontal stroke
      final center = tester.getCenter(canvasFinder);
      final gesture = await tester.startGesture(center - const Offset(50, 0));
      await tester.pump();
      await gesture.moveTo(center + const Offset(50, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      // Undo and Chấm điểm buttons should now be enabled
      final undoButton = find.byTooltip('Hoàn tác nét vừa vẽ');
      expect(undoButton, findsOneWidget);

      final evaluateButton = find.widgetWithText(HiButton, 'Chấm điểm');
      expect(evaluateButton, findsOneWidget);
      final hiBtn = tester.widget<HiButton>(evaluateButton);
      expect(hiBtn.onPressed, isNotNull);
    });

    testWidgets('3. Multi-stroke drawing, Undo, and Reset operations work properly', (tester) async {
      await tester.pumpWidget(buildTestWidget(initialCharacter: '十'));
      await tester.pumpAndSettle();

      final canvasFinder = find.byType(HanziCanvas);
      final center = tester.getCenter(canvasFinder);

      // Stroke 1: Horizontal
      final g1 = await tester.startGesture(center - const Offset(60, 0));
      await tester.pump();
      await g1.moveTo(center + const Offset(60, 0));
      await tester.pump();
      await g1.up();
      await tester.pumpAndSettle();

      // Stroke 2: Vertical
      final g2 = await tester.startGesture(center - const Offset(0, 60));
      await tester.pump();
      await g2.moveTo(center + const Offset(0, 60));
      await tester.pump();
      await g2.up();
      await tester.pumpAndSettle();

      // Tap Undo -> removes Stroke 2
      final undoBtnFinder = find.byTooltip('Hoàn tác nét vừa vẽ');
      await tester.tap(undoBtnFinder);
      await tester.pumpAndSettle();

      // Tap Reset -> removes remaining strokes
      final resetBtnFinder = find.byTooltip('Xóa toàn bộ nét');
      await tester.tap(resetBtnFinder);
      await tester.pumpAndSettle();

      // After reset, Chấm điểm button should be disabled
      final evaluateButton = find.widgetWithText(HiButton, 'Chấm điểm');
      final hiBtn = tester.widget<HiButton>(evaluateButton);
      expect(hiBtn.onPressed, isNull);
    });

    testWidgets('4. Switching writing mode between Tô mẫu and Tự viết', (tester) async {
      await tester.pumpWidget(buildTestWidget(initialCharacter: '十'));
      await tester.pumpAndSettle();

      // Initially in Tracing mode
      expect(find.text('Tô mẫu'), findsOneWidget);
      expect(find.text('Tự viết'), findsOneWidget);

      // Tap 'Tự viết'
      await tester.tap(find.text('Tự viết'));
      await tester.pumpAndSettle();

      // Tap 'Tô mẫu'
      await tester.tap(find.text('Tô mẫu'));
      await tester.pumpAndSettle();
    });

    testWidgets('5. Selecting stroke width presets (Mảnh, Vừa, Đậm)', (tester) async {
      await tester.pumpWidget(buildTestWidget(initialCharacter: '十'));
      await tester.pumpAndSettle();

      // Tap 'Mảnh'
      await tester.tap(find.text('Mảnh'));
      await tester.pumpAndSettle();

      // Tap 'Đậm'
      await tester.tap(find.text('Đậm'));
      await tester.pumpAndSettle();

      // Tap 'Vừa'
      await tester.tap(find.text('Vừa'));
      await tester.pumpAndSettle();
    });

    testWidgets('6. Evaluation modal pops up and saves result cleanly to repository', (tester) async {
      await tester.pumpWidget(buildTestWidget(initialCharacter: '十'));
      await tester.pumpAndSettle();

      final canvasFinder = find.byType(HanziCanvas);
      final center = tester.getCenter(canvasFinder);

      // Stroke 1: Horizontal (heng) left-to-right
      final g1 = await tester.startGesture(center + const Offset(-60, 0));
      await tester.pump();
      await g1.moveTo(center + const Offset(60, 0));
      await tester.pump();
      await g1.up();
      await tester.pumpAndSettle();

      // Stroke 2: Vertical (shu) top-to-bottom
      final g2 = await tester.startGesture(center + const Offset(0, -60));
      await tester.pump();
      await g2.moveTo(center + const Offset(0, 60));
      await tester.pump();
      await g2.up();
      await tester.pumpAndSettle();

      // Tap Chấm điểm
      final evaluateBtn = find.widgetWithText(HiButton, 'Chấm điểm');
      await tester.tap(evaluateBtn);
      await tester.pumpAndSettle();

      // Verification of modal sheet
      expect(find.byType(WritingEvaluationSheet), findsOneWidget);
      expect(find.textContaining('GB/T 13000'), findsOneWidget);
      expect(find.text('Lưu kết quả'), findsOneWidget);

      // Tap 'Lưu kết quả'
      await tester.tap(find.text('Lưu kết quả'));
      await tester.pumpAndSettle();

      // Modal closed and repository received 1 record
      expect(find.byType(WritingEvaluationSheet), findsNothing);
      expect(fakeRepository.recordedSessions.length, equals(1));
      expect(fakeRepository.recordedSessions.first['character'], equals('十'));
    });

    testWidgets('7. Character lacking stroke data shows transparent notice and allows free writing', (tester) async {
      await tester.pumpWidget(buildTestWidget(initialCharacter: '国'));
      await tester.pumpAndSettle();

      // Notice banner must be visible
      expect(
        find.textContaining('Chưa có dữ liệu nét chuẩn cho chữ "国"'),
        findsOneWidget,
      );

      // Still allows drawing on canvas
      final canvasFinder = find.byType(HanziCanvas);
      final center = tester.getCenter(canvasFinder);
      final g = await tester.startGesture(center);
      await g.moveTo(center + const Offset(30, 30));
      await g.up();
      await tester.pumpAndSettle();

      final evaluateButton = find.widgetWithText(HiButton, 'Chấm điểm');
      expect(tester.widget<HiButton>(evaluateButton).onPressed, isNotNull);
    });

    testWidgets('8. Narrow screen (320dp width) renders without overflow', (tester) async {
      tester.view.physicalSize = const Size(320.0, 640.0);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestWidget(initialCharacter: '十'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Luyện Viết Chữ Hán'), findsOneWidget);
      expect(find.byType(HanziCanvas), findsOneWidget);
    });
  });
}
