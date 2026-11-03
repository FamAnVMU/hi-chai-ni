import 'dart:ui';

/// Parses Make Me a Hanzi SVG path strings (M, Q, C, L, Z commands)
/// into Flutter [Path] objects, mapping from font coordinates (0..1024, -124..900)
/// to canvas screen coordinates.
class SvgPathParser {
  const SvgPathParser();

  /// Parses an SVG path string and transforms it to fit target screen canvas dimensions.
  ///
  /// [pathString]: SVG path data from Make Me a Hanzi, e.g. "M 323 706 Q 325 699 328 694 ... Z"
  /// [width], [height]: Canvas dimensions
  /// [padding]: Outer margin padding
  static Path parse(
    String pathString, {
    required double width,
    required double height,
    double padding = 20.0,
  }) {
    final effectiveWidth = width - 2 * padding;
    final effectiveHeight = height - 2 * padding;
    final scale = (effectiveWidth < effectiveHeight ? effectiveWidth : effectiveHeight) / 1024.0;
    final xOffset = padding + (effectiveWidth - 1024.0 * scale) / 2.0;
    final yOffset = padding + (effectiveHeight - 1024.0 * scale) / 2.0;

    double toScreenX(num x) => xOffset + x * scale;
    double toScreenY(num y) => yOffset + (900.0 - y) * scale;

    return parseWithTransform(
      pathString,
      transformX: toScreenX,
      transformY: toScreenY,
    );
  }

  /// Parses an SVG path string into raw unscaled coordinates (0..1024, -124..900)
  /// with Y inverted (y_screen = 900 - y).
  static Path parseRaw(String pathString) {
    return parseWithTransform(
      pathString,
      transformX: (x) => x.toDouble(),
      transformY: (y) => (900.0 - y).toDouble(),
    );
  }

  /// Generic parser accepting custom coordinate transformation functions
  static Path parseWithTransform(
    String pathString, {
    required double Function(num x) transformX,
    required double Function(num y) transformY,
  }) {
    final path = Path();
    if (pathString.isEmpty) return path;

    final tokens = _tokenize(pathString);
    int i = 0;

    while (i < tokens.length) {
      final token = tokens[i];
      if (token == 'M' || token == 'm') {
        if (i + 2 < tokens.length) {
          final x = double.tryParse(tokens[i + 1]) ?? 0.0;
          final y = double.tryParse(tokens[i + 2]) ?? 0.0;
          path.moveTo(transformX(x), transformY(y));
          i += 3;
        } else {
          break;
        }
      } else if (token == 'L' || token == 'l') {
        if (i + 2 < tokens.length) {
          final x = double.tryParse(tokens[i + 1]) ?? 0.0;
          final y = double.tryParse(tokens[i + 2]) ?? 0.0;
          path.lineTo(transformX(x), transformY(y));
          i += 3;
        } else {
          break;
        }
      } else if (token == 'Q' || token == 'q') {
        if (i + 4 < tokens.length) {
          final x1 = double.tryParse(tokens[i + 1]) ?? 0.0;
          final y1 = double.tryParse(tokens[i + 2]) ?? 0.0;
          final x = double.tryParse(tokens[i + 3]) ?? 0.0;
          final y = double.tryParse(tokens[i + 4]) ?? 0.0;
          path.quadraticBezierTo(
            transformX(x1),
            transformY(y1),
            transformX(x),
            transformY(y),
          );
          i += 5;
        } else {
          break;
        }
      } else if (token == 'C' || token == 'c') {
        if (i + 6 < tokens.length) {
          final x1 = double.tryParse(tokens[i + 1]) ?? 0.0;
          final y1 = double.tryParse(tokens[i + 2]) ?? 0.0;
          final x2 = double.tryParse(tokens[i + 3]) ?? 0.0;
          final y2 = double.tryParse(tokens[i + 4]) ?? 0.0;
          final x = double.tryParse(tokens[i + 5]) ?? 0.0;
          final y = double.tryParse(tokens[i + 6]) ?? 0.0;
          path.cubicTo(
            transformX(x1),
            transformY(y1),
            transformX(x2),
            transformY(y2),
            transformX(x),
            transformY(y),
          );
          i += 7;
        } else {
          break;
        }
      } else if (token == 'Z' || token == 'z') {
        path.close();
        i += 1;
      } else {
        // Unrecognized token or extra number, advance
        i += 1;
      }
    }

    return path;
  }

  static List<String> _tokenize(String pathString) {
    final tokens = <String>[];
    final buffer = StringBuffer();

    for (int i = 0; i < pathString.length; i++) {
      final char = pathString[i];
      if ('MLQCZmlqcz'.contains(char)) {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        tokens.add(char);
      } else if (char == ' ' || char == ',' || char == '\t' || char == '\n' || char == '\r') {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
      } else if (char == '-') {
        if (buffer.isNotEmpty) {
          tokens.add(buffer.toString());
          buffer.clear();
        }
        buffer.write(char);
      } else {
        buffer.write(char);
      }
    }

    if (buffer.isNotEmpty) {
      tokens.add(buffer.toString());
    }

    return tokens;
  }
}
