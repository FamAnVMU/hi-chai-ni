import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/hanzi/domain/engine/svg_path_parser.dart';

void main() {
  group('SvgPathParser', () {
    test('parses simple M, L, Z commands without throwing', () {
      const svgPath = 'M 100 200 L 300 400 Z';
      final path = SvgPathParser.parse(svgPath, width: 300, height: 300);
      expect(path, isNotNull);
      final bounds = path.getBounds();
      expect(bounds.width, greaterThan(0));
      expect(bounds.height, greaterThan(0));
    });

    test('parses quadratic bezier Q commands from Make Me a Hanzi', () {
      const svgPath = 'M 272 567 Q 306 613 342 669 Q 370 718 395 743 Z';
      final path = SvgPathParser.parse(svgPath, width: 400, height: 400);
      expect(path, isNotNull);
      final bounds = path.getBounds();
      expect(bounds.width, greaterThan(0));
      expect(bounds.height, greaterThan(0));
    });

    test('parses cubic bezier C commands properly', () {
      const svgPath = 'M 100 100 C 150 150 200 200 250 250 Z';
      final path = SvgPathParser.parse(svgPath, width: 300, height: 300);
      expect(path, isNotNull);
      final bounds = path.getBounds();
      expect(bounds.width, greaterThan(0));
    });

    test('handles empty or malformed strings gracefully', () {
      final emptyPath = SvgPathParser.parse('', width: 200, height: 200);
      expect(emptyPath, isNotNull);
      expect(emptyPath.getBounds().isEmpty, isTrue);

      final malformedPath = SvgPathParser.parse('M 10', width: 200, height: 200);
      expect(malformedPath, isNotNull);
    });

    test('parseRaw inverts Y axis to standard SVG orientation', () {
      // Font Y=900 should map to Screen Y=0 in raw parse
      const svgPath = 'M 0 900 L 1024 0 Z';
      final path = SvgPathParser.parseRaw(svgPath);
      final bounds = path.getBounds();
      expect(bounds.top, closeTo(0, 1.0));
      expect(bounds.bottom, closeTo(900, 1.0));
    });
  });
}
