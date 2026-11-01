import 'package:flutter/material.dart';
import '../models/stroke_models.dart';

/// Curated, verified repository of Chinese stroke order data (GB/T 13000 / Hanban standard).
class HanziStrokeBank {
  const HanziStrokeBank();

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

  /// Retrieves verified standard stroke sequence for a character, or null if unverified.
  HanziStrokeData? getStrokeData(String character) {
    final trimmed = character.trim();
    if (trimmed.isEmpty) return null;
    return _verifiedBank[trimmed.characters.first];
  }

  /// List of all characters with verified stroke order available for study.
  List<String> get availableCharacters => _verifiedBank.keys.toList();
}
