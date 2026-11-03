import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/features/hanzi_writing/domain/models/stroke_models.dart';
import 'package:hi_chinese/features/hanzi_writing/presentation/widgets/hanzi_canvas.dart';
import 'package:hi_chinese/features/hanzi_writing/presentation/widgets/hanzi_canvas_controller.dart';

void main() {
  const sampleStrokeData = HanziStrokeData(
    character: '十',
    pinyin: 'shí',
    meaningVi: 'Số mười',
    totalStrokes: 2,
    strokes: [
      StandardStroke(
        order: 1,
        nameVi: 'Nét ngang',
        type: StrokeType.heng,
        normalizedStart: Offset(0.2, 0.5),
        normalizedEnd: Offset(0.8, 0.5),
      ),
      StandardStroke(
        order: 2,
        nameVi: 'Nét sổ',
        type: StrokeType.shu,
        normalizedStart: Offset(0.5, 0.2),
        normalizedEnd: Offset(0.5, 0.8),
      ),
    ],
  );

  Widget buildTestWidget({
    required HanziCanvasController controller,
    VoidCallback? onStepReplay,
  }) {
    return MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Center(
          child: HanziCanvas(
            controller: controller,
            character: '十',
            strokeData: sampleStrokeData,
            onStepReplay: onStepReplay,
          ),
        ),
      ),
    );
  }

  group('HanziCanvas Accessibility Semantics Tests (F-20)', () {
    testWidgets('1. Exposes meaningful Semantics label, value, and hint for TalkBack',
        (tester) async {
      final controller = HanziCanvasController();
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(buildTestWidget(controller: controller));
      await tester.pumpAndSettle();

      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label != null &&
            widget.properties.label!.contains('Khung lưới tập viết chữ Hán 十'),
      );
      expect(semanticsFinder, findsOneWidget);

      final Semantics semanticsWidget = tester.widget<Semantics>(semanticsFinder);
      expect(semanticsWidget.properties.label, contains('Khung lưới tập viết chữ Hán 十'));
      expect(semanticsWidget.properties.value, contains('Chữ 十, phát âm shí'));
      expect(semanticsWidget.properties.value, contains('Chế độ: Tô mẫu'));
      expect(semanticsWidget.properties.value, contains('Đã viết 0 nét trên tổng số 2 nét chuẩn'));
      expect(semanticsWidget.properties.hint, contains('Chạm và rê để vẽ nét chữ'));

      handle.dispose();
      controller.dispose();
    });

    testWidgets('2. Drawing a stroke dynamically updates Semantics value',
        (tester) async {
      final controller = HanziCanvasController();
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(buildTestWidget(controller: controller));
      await tester.pumpAndSettle();

      final canvasFinder = find.byType(HanziCanvas);
      final center = tester.getCenter(canvasFinder);
      final gesture = await tester.startGesture(center - const Offset(40, 0));
      await gesture.moveTo(center + const Offset(40, 0));
      await gesture.up();
      await tester.pumpAndSettle();

      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.value != null &&
            widget.properties.value!.contains('Đã viết 1 nét trên tổng số 2 nét chuẩn'),
      );
      expect(semanticsFinder, findsOneWidget);

      handle.dispose();
      controller.dispose();
    });

    testWidgets('3. Custom accessibility actions allow Reset, Undo, and Step Replay',
        (tester) async {
      final controller = HanziCanvasController();
      bool stepReplayCalled = false;
      final SemanticsHandle handle = tester.ensureSemantics();

      await tester.pumpWidget(
        buildTestWidget(
          controller: controller,
          onStepReplay: () {
            stepReplayCalled = true;
          },
        ),
      );
      await tester.pumpAndSettle();

      final canvasFinder = find.byType(HanziCanvas);
      final center = tester.getCenter(canvasFinder);
      final gesture = await tester.startGesture(center - const Offset(30, 0));
      await gesture.moveTo(center + const Offset(30, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(controller.strokes.length, equals(1));

      final semanticsFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.customSemanticsActions != null &&
            widget.properties.customSemanticsActions!.containsKey(
              const CustomSemanticsAction(label: 'Hoàn tác nét vừa vẽ'),
            ),
      );
      expect(semanticsFinder, findsOneWidget);

      final Semantics semanticsWidget = tester.widget<Semantics>(semanticsFinder);
      final actions = semanticsWidget.properties.customSemanticsActions!;

      actions[const CustomSemanticsAction(label: 'Xem mẫu nét tiếp theo')]?.call();
      expect(stepReplayCalled, isTrue);

      actions[const CustomSemanticsAction(label: 'Hoàn tác nét vừa vẽ')]?.call();
      await tester.pumpAndSettle();
      expect(controller.strokes.length, equals(0));

      handle.dispose();
      controller.dispose();
    });
  });
}
