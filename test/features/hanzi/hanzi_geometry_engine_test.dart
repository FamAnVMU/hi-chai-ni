import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/hanzi/domain/engine/hanzi_geometry_engine.dart';
import 'package:hi_chinese/features/hanzi/domain/models/hanzi_models.dart';

void main() {
  group('HanziGeometryEngine', () {
    test('coordinate conversion is reversible between screen and font space', () {
      const screenPoint = Point2D(150.0, 180.0);
      const width = 300.0;
      const height = 300.0;
      const padding = 20.0;

      final fontPoint = HanziGeometryEngine.screenToFont(
        screenPoint,
        width: width,
        height: height,
        padding: padding,
      );

      final backToScreen = HanziGeometryEngine.fontToScreen(
        fontPoint,
        width: width,
        height: height,
        padding: padding,
      );

      expect(backToScreen.x, closeTo(screenPoint.x, 0.001));
      expect(backToScreen.y, closeTo(screenPoint.y, 0.001));
    });

    final testCharacter = HanziCharacter(
      id: 'hanzi_4e00',
      character: '一',
      strokeCount: 1,
      hskLevel: 1,
      pinyin: 'yī',
      meaningVi: 'số một',
      strokes: ['M 200 450 L 800 450 Z'],
      medians: [
        [
          const Point2D(200.0, 450.0),
          const Point2D(500.0, 450.0),
          const Point2D(800.0, 450.0),
        ],
      ],
    );

    final multiStrokeCharacter = HanziCharacter(
      id: 'hanzi_4e8c',
      character: '二',
      strokeCount: 2,
      hskLevel: 1,
      pinyin: 'èr',
      meaningVi: 'số hai',
      strokes: ['M 300 650 L 700 650 Z', 'M 200 350 L 800 350 Z'],
      medians: [
        [
          const Point2D(300.0, 650.0),
          const Point2D(500.0, 650.0),
          const Point2D(700.0, 650.0),
        ],
        [
          const Point2D(200.0, 350.0),
          const Point2D(500.0, 350.0),
          const Point2D(800.0, 350.0),
        ],
      ],
    );

    test('validates correct stroke matching median trajectory', () {
      final userPoints = [
        const Point2D(210.0, 448.0),
        const Point2D(505.0, 452.0),
        const Point2D(795.0, 449.0),
      ];

      final result = HanziGeometryEngine.validateStroke(
        userPoints: userPoints,
        character: testCharacter,
        expectedStrokeIndex: 0,
      );

      expect(result.isMatch, isTrue);
      expect(result.isBackwards, isFalse);
      expect(result.isWrongOrder, isFalse);
      expect(result.accuracyScore, greaterThanOrEqualTo(70.0));
    });

    test('detects backwards stroke when drawn from right to left for 一', () {
      final userPoints = [
        const Point2D(795.0, 450.0),
        const Point2D(500.0, 450.0),
        const Point2D(205.0, 450.0),
      ];

      final result = HanziGeometryEngine.validateStroke(
        userPoints: userPoints,
        character: testCharacter,
        expectedStrokeIndex: 0,
      );

      expect(result.isMatch, isFalse);
      expect(result.isBackwards, isTrue);
      expect(result.message, contains('ngược chiều'));
    });

    test('detects wrong stroke order when drawing stroke 2 before stroke 1', () {
      // Drawing stroke 2 of '二' while expecting stroke 0
      final userPoints = [
        const Point2D(205.0, 350.0),
        const Point2D(500.0, 350.0),
        const Point2D(795.0, 350.0),
      ];

      final result = HanziGeometryEngine.validateStroke(
        userPoints: userPoints,
        character: multiStrokeCharacter,
        expectedStrokeIndex: 0,
      );

      expect(result.isMatch, isFalse);
      expect(result.isWrongOrder, isTrue);
      expect(result.matchedStrokeIndex, 1);
      expect(result.message, contains('Sai thứ tự nét'));
    });

    test('rejects stroke with severe shape deviation', () {
      final userPoints = [
        const Point2D(200.0, 800.0),
        const Point2D(500.0, 800.0),
        const Point2D(800.0, 800.0),
      ];

      final result = HanziGeometryEngine.validateStroke(
        userPoints: userPoints,
        character: testCharacter,
        expectedStrokeIndex: 0,
      );

      expect(result.isMatch, isFalse);
      expect(result.accuracyScore, 0.0);
    });
  });
}
