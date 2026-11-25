import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/features/shadowing/shadowing.dart';
import '../../helpers/mock_audio_platform.dart';

class _EmptyShadowRepo implements ShadowingRepository {
  @override
  Future<void> deleteRecordingAudio({
    required String audioPath,
    required String? evidenceId,
    bool retainEvidence = true,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> getRecentShadowingSessions({
    String? segmentId,
    int limit = 10,
  }) async =>
      [];

  @override
  Future<String> recordShadowingSession({
    required ShadowingAssessmentResult assessment,
    DateTime? timestamp,
    Duration? timeZoneOffset,
  }) async =>
      'EVI_1';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const segment = ShadowingSegment(
    id: 'SEG_W2',
    order: 1,
    hanzi: '你好',
    pinyin: 'Nǐ hǎo',
    meaningVi: 'Xin chào',
    durationMs: 2000,
  );
  const evaluator = ShadowingEvaluator();

  group('Shadowing Evaluator Silence Guard & Document Selector', () {
    test('returns 0 scores for silent normalized amplitudes (< -35 dBFS / < 0.417)', () {
      final res = evaluator.evaluate(
        segment: segment,
        userDuration: const Duration(milliseconds: 2000),
        mode: ShadowingMode.listenThenRepeat,
        speed: ShadowingPlaybackSpeed.normal,
        amplitudeSamples: const [0.1, 0.2, 0.35, 0.15],
      );

      expect(res.pacingRatio, equals(0.0));
      expect(res.timelineMatchPercent, equals(0.0));
      expect(res.fluencyIndex, equals(0.0));
      expect(res.pacingVerdict, contains('im lặng'));
    });

    test('returns 0 scores when voiced frame ratio in rawDbfsSamples is below 25%', () {
      final res = evaluator.evaluate(
        segment: segment,
        userDuration: const Duration(milliseconds: 2000),
        mode: ShadowingMode.listenThenRepeat,
        speed: ShadowingPlaybackSpeed.normal,
        rawDbfsSamples: const [-20.0, -55.0, -52.0, -58.0, -60.0],
      );

      expect(res.pacingRatio, equals(0.0));
      expect(res.fluencyIndex, equals(0.0));
    });

    test('evaluates normally when amplitudeSamples indicate clear speech', () {
      final res = evaluator.evaluate(
        segment: segment,
        userDuration: const Duration(milliseconds: 2000),
        mode: ShadowingMode.listenThenRepeat,
        speed: ShadowingPlaybackSpeed.normal,
        amplitudeSamples: const [0.65, 0.72, 0.58, 0.69],
      );

      expect(res.pacingRatio, equals(1.0));
      expect(res.timelineMatchPercent, equals(100.0));
      expect(res.fluencyIndex, equals(1.0));
    });

    testWidgets('ShadowingScreen renders document chips and switches document cleanly', (tester) async {
      MockAudioPlatformHelper.setupMockPlatformChannels();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shadowingRepositoryProvider.overrideWithValue(_EmptyShadowRepo()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const ShadowingScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Bài 1 · HSK 1'), findsOneWidget);
      expect(find.text('Bài 2 · HSK 2'), findsOneWidget);

      await tester.tap(find.text('Bài 2 · HSK 2'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Gọi món tại nhà hàng Trung Hoa'), findsOneWidget);
      expect(find.text('Câu 1/3'), findsOneWidget);
    });
  });
}
