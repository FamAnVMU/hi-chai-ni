import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/features/shadowing/shadowing.dart';

void main() {
  group('ShadowingEvaluator Mathematical & Timeline Tests', () {
    const evaluator = ShadowingEvaluator();
    const segment = ShadowingSegment(
      id: 'SEG_TEST_01',
      order: 1,
      hanzi: '你好，请问你是王老师吗？',
      pinyin: 'Nǐ hǎo, qǐngwèn nǐ shì Wáng lǎoshī ma?',
      meaningVi: 'Xin chào, xin hỏi bạn có phải là thầy Vương không?',
      durationMs: 3000,
    );

    test('1. Optimal speech pacing (0.85x - 1.15x) achieves high fluency and native speed verdict', () {
      final result = evaluator.evaluate(
        segment: segment,
        userDuration: const Duration(milliseconds: 3000), // Exactly 1.0x
        mode: ShadowingMode.listenThenRepeat,
        speed: ShadowingPlaybackSpeed.normal,
      );

      expect(result.pacingRatio, equals(1.0));
      expect(result.pacingVerdict, contains('Chuẩn nhịp độ bản xứ'));
      expect(result.timelineMatchPercent, equals(100.0));
      expect(result.fluencyIndex, equals(1.0));
    });

    test('2. Rushed speech (< 0.85x) is detected as too fast', () {
      final result = evaluator.evaluate(
        segment: segment,
        userDuration: const Duration(milliseconds: 2100), // 0.70x
        mode: ShadowingMode.listenThenRepeat,
        speed: ShadowingPlaybackSpeed.normal,
      );

      expect(result.pacingRatio, equals(0.7));
      expect(result.pacingVerdict, contains('Nói hơi nhanh'));
      expect(result.timelineMatchPercent, lessThan(80.0));
    });

    test('3. Dragged speech (> 1.15x) is detected as too slow with pause reduction hint', () {
      final result = evaluator.evaluate(
        segment: segment,
        userDuration: const Duration(milliseconds: 4200), // 1.40x
        mode: ShadowingMode.simultaneous,
        speed: ShadowingPlaybackSpeed.normal,
      );

      expect(result.pacingRatio, equals(1.4));
      expect(result.pacingVerdict, contains('Nói hơi chậm'));
      expect(result.timelineMatchPercent, lessThan(70.0));
    });

    test('4. Target duration dynamically adjusts when playback speed is 0.75x or 1.25x', () {
      // At 0.75x, 3000ms base speech plays over 4000ms
      final slowResult = evaluator.evaluate(
        segment: segment,
        userDuration: const Duration(milliseconds: 4000),
        mode: ShadowingMode.listenThenRepeat,
        speed: ShadowingPlaybackSpeed.slow,
      );

      expect(slowResult.targetDurationMs, equals(4000));
      expect(slowResult.pacingRatio, equals(1.0));
      expect(slowResult.pacingVerdict, contains('Chuẩn nhịp độ bản xứ'));
    });

    test('5. Disclaimer explicitly forbids fake accent scoring', () {
      final result = evaluator.evaluate(
        segment: segment,
        userDuration: const Duration(milliseconds: 3000),
        mode: ShadowingMode.listenThenRepeat,
        speed: ShadowingPlaybackSpeed.normal,
      );

      expect(result.disclaimer, contains('không đưa ra chấm điểm giả về accent'));
    });
  });
}
