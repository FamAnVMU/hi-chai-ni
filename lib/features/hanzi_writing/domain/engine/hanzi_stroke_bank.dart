import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../hanzi/data/hanzi_dao.dart';
import '../../../hanzi/domain/models/hanzi_models.dart';
import '../models/stroke_models.dart';

/// Curated, verified repository of Chinese stroke order data (GB/T 13000 / Hanban standard).
/// Connects to the shared 2,632-character Hanzi database while maintaining verified curated fallbacks.
class HanziStrokeBank {
  final HanziDao? _hanziDao;
  static final Map<String, HanziStrokeData> _dynamicCache = {};

  const HanziStrokeBank([this._hanziDao]);

  static final Map<String, HanziStrokeData> _verifiedBank = {
    // 1. 一 (1 stroke: 横)
    '一': const HanziStrokeData(
      character: '一',
      totalStrokes: 1,
      pinyin: 'yī',
      meaningVi: 'Số một',
      radical: '一',
      strokes: [
        StandardStroke(
          order: 1,
          type: StrokeType.heng,
          nameVi: 'Ngang (横)',
          normalizedStart: Offset(0.2, 0.5),
          normalizedEnd: Offset(0.8, 0.5),
        ),
      ],
    ),

    // 2. 二 (2 strokes: Ngang ngắn, Ngang dài)
    '二': const HanziStrokeData(
      character: '二',
      totalStrokes: 2,
      pinyin: 'èr',
      meaningVi: 'Số hai',
      radical: '二',
      strokes: [
        StandardStroke(
          order: 1,
          type: StrokeType.heng,
          nameVi: 'Ngang ngắn trên (横)',
          normalizedStart: Offset(0.3, 0.35),
          normalizedEnd: Offset(0.7, 0.35),
        ),
        StandardStroke(
          order: 2,
          type: StrokeType.heng,
          nameVi: 'Ngang dài dưới (横)',
          normalizedStart: Offset(0.2, 0.65),
          normalizedEnd: Offset(0.8, 0.65),
        ),
      ],
    ),

    // 3. 三 (3 strokes: Ngang trên, Ngang giữa, Ngang dưới)
    '三': const HanziStrokeData(
      character: '三',
      totalStrokes: 3,
      pinyin: 'sān',
      meaningVi: 'Số ba',
      radical: '一',
      strokes: [
        StandardStroke(
          order: 1,
          type: StrokeType.heng,
          nameVi: 'Ngang trên (横)',
          normalizedStart: Offset(0.28, 0.3),
          normalizedEnd: Offset(0.72, 0.3),
        ),
        StandardStroke(
          order: 2,
          type: StrokeType.heng,
          nameVi: 'Ngang giữa ngắn (横)',
          normalizedStart: Offset(0.35, 0.5),
          normalizedEnd: Offset(0.65, 0.5),
        ),
        StandardStroke(
          order: 3,
          type: StrokeType.heng,
          nameVi: 'Ngang đáy dài (横)',
          normalizedStart: Offset(0.2, 0.7),
          normalizedEnd: Offset(0.8, 0.7),
        ),
      ],
    ),

    // 4. 十 (2 strokes: Ngang trước, Sổ sau - 先横后竖)
    '十': const HanziStrokeData(
      character: '十',
      totalStrokes: 2,
      pinyin: 'shí',
      meaningVi: 'Số mười',
      radical: '十',
      strokes: [
        StandardStroke(
          order: 1,
          type: StrokeType.heng,
          nameVi: 'Ngang (横)',
          normalizedStart: Offset(0.2, 0.45),
          normalizedEnd: Offset(0.8, 0.45),
        ),
        StandardStroke(
          order: 2,
          type: StrokeType.shu,
          nameVi: 'Sổ thẳng (竖)',
          normalizedStart: Offset(0.5, 0.2),
          normalizedEnd: Offset(0.5, 0.8),
        ),
      ],
    ),

    // 5. 人 (2 strokes: Phẩy trước, Mác sau - 先撇后捺)
    '人': const HanziStrokeData(
      character: '人',
      totalStrokes: 2,
      pinyin: 'rén',
      meaningVi: 'Người, con người',
      radical: '人',
      strokes: [
        StandardStroke(
          order: 1,
          type: StrokeType.pie,
          nameVi: 'Phẩy (撇)',
          normalizedStart: Offset(0.5, 0.2),
          normalizedEnd: Offset(0.22, 0.8),
        ),
        StandardStroke(
          order: 2,
          type: StrokeType.na,
          nameVi: 'Mác (捺)',
          normalizedStart: Offset(0.45, 0.45),
          normalizedEnd: Offset(0.78, 0.8),
        ),
      ],
    ),

    // 6. 大 (3 strokes: Ngang, Phẩy, Mác)
    '大': const HanziStrokeData(
      character: '大',
      totalStrokes: 3,
      pinyin: 'dà',
      meaningVi: 'To lớn',
      radical: '大',
      strokes: [
        StandardStroke(
          order: 1,
          type: StrokeType.heng,
          nameVi: 'Ngang (横)',
          normalizedStart: Offset(0.2, 0.4),
          normalizedEnd: Offset(0.8, 0.4),
        ),
        StandardStroke(
          order: 2,
          type: StrokeType.pie,
          nameVi: 'Phẩy dài (撇)',
          normalizedStart: Offset(0.5, 0.2),
          normalizedEnd: Offset(0.2, 0.8),
        ),
        StandardStroke(
          order: 3,
          type: StrokeType.na,
          nameVi: 'Mác (捺)',
          normalizedStart: Offset(0.48, 0.42),
          normalizedEnd: Offset(0.8, 0.8),
        ),
      ],
    ),

    // 7. 中 (4 strokes: Sổ, Ngang gập, Ngang, Sổ xuyên tâm)
    '中': const HanziStrokeData(
      character: '中',
      totalStrokes: 4,
      pinyin: 'zhōng',
      meaningVi: 'Ở giữa, trung tâm',
      radical: '丨',
      strokes: [
        StandardStroke(
          order: 1,
          type: StrokeType.shu,
          nameVi: 'Sổ đứng trái (竖)',
          normalizedStart: Offset(0.25, 0.35),
          normalizedEnd: Offset(0.25, 0.65),
        ),
        StandardStroke(
          order: 2,
          type: StrokeType.zhe,
          nameVi: 'Ngang gập phải (横折)',
          normalizedStart: Offset(0.25, 0.35),
          normalizedEnd: Offset(0.75, 0.65),
          controlPoints: [Offset(0.75, 0.35)],
        ),
        StandardStroke(
          order: 3,
          type: StrokeType.heng,
          nameVi: 'Ngang đóng đáy (横)',
          normalizedStart: Offset(0.25, 0.65),
          normalizedEnd: Offset(0.75, 0.65),
        ),
        StandardStroke(
          order: 4,
          type: StrokeType.shu,
          nameVi: 'Sổ giữa xuyên tâm (竖)',
          normalizedStart: Offset(0.5, 0.18),
          normalizedEnd: Offset(0.5, 0.82),
        ),
      ],
    ),

    // 8. 水 (4 strokes: Sổ móc giữa trước, Ngang phẩy trái, Phẩy phải, Mác)
    '水': const HanziStrokeData(
      character: '水',
      totalStrokes: 4,
      pinyin: 'shuǐ',
      meaningVi: 'Nước',
      radical: '水',
      strokes: [
        StandardStroke(
          order: 1,
          type: StrokeType.gou,
          nameVi: 'Sổ móc giữa (竖钩)',
          normalizedStart: Offset(0.5, 0.18),
          normalizedEnd: Offset(0.42, 0.82),
          controlPoints: [Offset(0.5, 0.82)],
        ),
        StandardStroke(
          order: 2,
          type: StrokeType.zhe,
          nameVi: 'Ngang phẩy trái (横撇)',
          normalizedStart: Offset(0.25, 0.4),
          normalizedEnd: Offset(0.45, 0.55),
          controlPoints: [Offset(0.4, 0.4)],
        ),
        StandardStroke(
          order: 3,
          type: StrokeType.pie,
          nameVi: 'Phẩy ngắn phải (撇)',
          normalizedStart: Offset(0.75, 0.32),
          normalizedEnd: Offset(0.55, 0.52),
        ),
        StandardStroke(
          order: 4,
          type: StrokeType.na,
          nameVi: 'Mác dài phải (捺)',
          normalizedStart: Offset(0.52, 0.52),
          normalizedEnd: Offset(0.82, 0.82),
        ),
      ],
    ),
  };

  /// Retrieves verified standard stroke sequence for a character synchronously,
  /// checking curated bank first and then dynamic cache.
  HanziStrokeData? getStrokeData(String character) {
    final trimmed = character.trim();
    if (trimmed.isEmpty) return null;
    final char = trimmed.characters.first;
    if (_verifiedBank.containsKey(char)) {
      return _verifiedBank[char];
    }
    return _dynamicCache[char];
  }

  /// Asynchronously retrieves standard stroke order data from curated bank,
  /// dynamic cache, or shared Hanzi SQLite database (2,632 characters).
  Future<HanziStrokeData?> getStrokeDataAsync(String character) async {
    final trimmed = character.trim();
    if (trimmed.isEmpty) return null;
    final char = trimmed.characters.first;

    // 1. Verified curated bank (highest priority)
    if (_verifiedBank.containsKey(char)) {
      return _verifiedBank[char];
    }

    // 2. Dynamic in-memory cache
    if (_dynamicCache.containsKey(char)) {
      return _dynamicCache[char];
    }

    // 3. Shared HanziDao database lookup
    if (_hanziDao != null) {
      final hanziChar = await _hanziDao.getCharacter(char);
      if (hanziChar != null) {
        final strokeData = _convertFromHanziCharacter(hanziChar);
        _dynamicCache[char] = strokeData;
        return strokeData;
      }
    }

    return null;
  }

  /// Converts a [HanziCharacter] from shared database into [HanziStrokeData].
  /// Characters without stroke or median data are strictly marked as unverified.
  static HanziStrokeData _convertFromHanziCharacter(HanziCharacter c) {
    if (c.medians.isEmpty || c.strokes.isEmpty) {
      return HanziStrokeData(
        character: c.character,
        totalStrokes: c.strokeCount,
        strokes: const [],
        radical: c.radical.isNotEmpty ? c.radical : null,
        pinyin: c.pinyin.isNotEmpty ? c.pinyin : null,
        meaningVi: c.meaningVi.isNotEmpty ? c.meaningVi : null,
        isVerified: false,
      );
    }

    final List<StandardStroke> strokes = [];
    for (int i = 0; i < c.medians.length; i++) {
      final median = c.medians[i];
      if (median.length < 2) continue;

      final startPt = median.first;
      final endPt = median.last;

      // Font coordinate space [0..1024, -124..900] to normalized [0..1]
      final normStart = Offset(
        (startPt.x / 1024.0).clamp(0.0, 1.0),
        ((900.0 - startPt.y) / 1024.0).clamp(0.0, 1.0),
      );
      final normEnd = Offset(
        (endPt.x / 1024.0).clamp(0.0, 1.0),
        ((900.0 - endPt.y) / 1024.0).clamp(0.0, 1.0),
      );

      final controlPoints = <Offset>[];
      if (median.length > 2) {
        for (int p = 1; p < median.length - 1; p++) {
          controlPoints.add(Offset(
            (median[p].x / 1024.0).clamp(0.0, 1.0),
            ((900.0 - median[p].y) / 1024.0).clamp(0.0, 1.0),
          ));
        }
      }

      final type = _classifyStrokeType(median, normStart, normEnd);

      strokes.add(StandardStroke(
        order: i + 1,
        type: type,
        nameVi: 'Nét ${i + 1}: ${type.nameVi}',
        normalizedStart: normStart,
        normalizedEnd: normEnd,
        controlPoints: controlPoints,
      ));
    }

    return HanziStrokeData(
      character: c.character,
      totalStrokes: c.strokeCount > 0 ? c.strokeCount : strokes.length,
      strokes: strokes,
      radical: c.radical.isNotEmpty ? c.radical : null,
      pinyin: c.pinyin.isNotEmpty ? c.pinyin : null,
      meaningVi: c.meaningVi.isNotEmpty ? c.meaningVi : null,
      isVerified: strokes.isNotEmpty,
    );
  }

  /// Classifies stroke geometry into canonical Chinese stroke types.
  static StrokeType _classifyStrokeType(
    List<Point2D> median,
    Offset normStart,
    Offset normEnd,
  ) {
    if (median.length < 2) return StrokeType.heng;

    final dx = normEnd.dx - normStart.dx;
    final dy = normEnd.dy - normStart.dy;
    final length = math.sqrt(dx * dx + dy * dy);
    final angleDeg = math.atan2(dy, dx) * 180.0 / math.pi;

    // Detect sharp directional inflection (gập / móc)
    bool hasSharpTurn = false;
    bool isHook = false;

    if (median.length >= 3) {
      for (int i = 0; i < median.length - 2; i++) {
        final v1x = median[i + 1].x - median[i].x;
        final v1y = (900.0 - median[i + 1].y) - (900.0 - median[i].y);
        final v2x = median[i + 2].x - median[i + 1].x;
        final v2y = (900.0 - median[i + 2].y) - (900.0 - median[i + 1].y);
        final len1 = math.sqrt(v1x * v1x + v1y * v1y);
        final len2 = math.sqrt(v2x * v2x + v2y * v2y);

        if (len1 > 20.0 && len2 > 20.0) {
          final dot = (v1x * v2x + v1y * v2y) / (len1 * len2);
          final clampedDot = dot.clamp(-1.0, 1.0);
          final turnDeg = math.acos(clampedDot) * 180.0 / math.pi;

          if (turnDeg > 65.0) {
            hasSharpTurn = true;
            if (i >= median.length - 4 && (v2y < -10.0 || (v2x < -10.0 && v2y.abs() < 50.0))) {
              isHook = true;
              break;
            }
          }
        }
      }
    }

    if (isHook) return StrokeType.gou;
    if (hasSharpTurn) return StrokeType.zhe;

    if (length < 0.22 && angleDeg >= 20.0 && angleDeg <= 75.0) {
      return StrokeType.dian;
    }
    if (angleDeg >= -30.0 && angleDeg <= 30.0) {
      return StrokeType.heng;
    }
    if (angleDeg >= 65.0 && angleDeg <= 115.0) {
      return StrokeType.shu;
    }
    if (angleDeg > 115.0 && angleDeg <= 170.0) {
      return StrokeType.pie;
    }
    if (angleDeg > 30.0 && angleDeg < 65.0) {
      return StrokeType.na;
    }
    if (angleDeg >= -75.0 && angleDeg < -30.0) {
      return StrokeType.ti;
    }

    return StrokeType.heng;
  }

  /// List of verified characters available immediately without DB access.
  List<String> get availableCharacters => _verifiedBank.keys.toList();

  /// Retrieves available characters from shared Hanzi database.
  Future<List<String>> getAvailableCharactersAsync({
    int limit = 100,
    int offset = 0,
    int? hskLevel,
  }) async {
    if (_hanziDao != null) {
      final list = hskLevel != null
          ? await _hanziDao.getCharactersByHskLevel(hskLevel, limit: limit, offset: offset)
          : await _hanziDao.getCharactersByHskLevel(1, limit: limit, offset: offset);
      if (list.isNotEmpty) {
        return list.map((c) => c.character).toList();
      }
    }
    return availableCharacters;
  }
}
