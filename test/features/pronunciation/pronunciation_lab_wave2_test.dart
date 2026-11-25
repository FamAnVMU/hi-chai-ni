import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/network/ai/interfaces/ai_provider.dart';
import 'package:hi_chinese/core/network/ai/models/ai_model_config.dart';
import 'package:hi_chinese/core/network/ai/models/ai_request.dart';
import 'package:hi_chinese/core/network/ai/models/ai_response.dart';
import 'package:hi_chinese/core/network/ai/models/cancel_token.dart';
import 'package:hi_chinese/core/network/ai/models/connection_test_result.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/core/utils/permission_helper.dart';
import 'package:hi_chinese/features/pronunciation/pronunciation.dart';
import '../../helpers/mock_audio_platform.dart';

class _JsonAiProvider implements AiProvider {
  final String reply;
  _JsonAiProvider(this.reply);

  @override
  String get providerName => 'mock_gemini_audio';

  @override
  Future<bool> verifyCredentials() async => true;

  @override
  Future<AiTextResponse> generateText(
    AiPromptRequest request, {
    AiModelConfig? config,
    Duration timeout = const Duration(seconds: 30),
    CancelToken? cancelToken,
  }) async {
    return AiTextResponse(text: reply, latencyMs: 40, modelUsed: 'gemini-2.5-flash');
  }

  @override
  Stream<AiStreamChunk> streamText(
    AiPromptRequest request, {
    AiModelConfig? config,
    Duration timeout = const Duration(seconds: 45),
    CancelToken? cancelToken,
  }) =>
      Stream.value(AiStreamChunk(index: 0, text: reply));

  @override
  Future<ConnectionTestResult> testConnection({String? modelId}) async =>
      ConnectionTestResult.success(
        providerName: providerName,
        modelTested: modelId ?? 'gemini-2.5-flash',
        latencyMs: 25,
      );

  @override
  void dispose() {}
}

class _FakeAnalysisService implements PronunciationAnalysisService {
  final PronunciationEvaluationStatus statusToReturn;
  _FakeAnalysisService(this.statusToReturn);

  @override
  String get providerId => 'fake_wave2';

  @override
  bool get supportsAcousticToneAnalysis => false;

  @override
  Future<PronunciationAssessmentResult> evaluatePronunciation({
    required PronunciationTarget target,
    required String audioPath,
    required Duration duration,
    bool simulateAcousticEngine = false,
  }) async {
    return PronunciationAssessmentResult(
      targetId: target.id,
      targetText: target.text,
      targetPinyin: target.pinyin,
      recognizedTranscript: statusToReturn == PronunciationEvaluationStatus.success ? target.text : null,
      overallScore: statusToReturn == PronunciationEvaluationStatus.success ? 0.9 : 0.0,
      status: statusToReturn,
      isAcousticallyAnalyzed: false,
      feedbackList: const ['Test status'],
      audioLocalPath: audioPath,
      recordedDurationMs: duration.inMilliseconds,
      providerId: providerId,
      timestamp: DateTime.now(),
    );
  }
}

class _SpyPronunciationRepo implements PronunciationRepository {
  int recordCount = 0;

  @override
  Future<String> recordPronunciationSession({
    required PronunciationAssessmentResult assessment,
    DateTime? timestamp,
    Duration? timeZoneOffset,
  }) async {
    recordCount++;
    return 'EVI_$recordCount';
  }

  @override
  Future<void> deleteRecordingAudio({
    required String audioPath,
    required String? evidenceId,
    bool retainEvidence = true,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> getRecentPronunciationSessions({
    String? targetId,
    int limit = 10,
  }) async =>
      [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const target = PronunciationTarget(
    id: 'TONE_01_MA1',
    text: '妈',
    pinyin: 'mā',
    meaningVi: 'Mẹ',
    category: PronunciationCategory.tone,
  );

  late File audioFile;

  setUpAll(() {
    MockAudioPlatformHelper.setupMockPlatformChannels();
    audioFile = File('${Directory.systemTemp.path}/pron_wave2_test.wav');
    audioFile.writeAsBytesSync(List.filled(600, 0x33));
  });

  tearDownAll(() {
    if (audioFile.existsSync()) audioFile.deleteSync();
  });

  group('Pronunciation Lab Wave 2', () {
    test('parses fenced Gemini Audio JSON with tone_accuracy and sets isAcousticallyAnalyzed = true', () async {
      final service = DefaultPronunciationAnalysisService(
        aiProvider: _JsonAiProvider(
          '```json\n{"transcript":"妈","detected_pinyin_tones":"mā","tone_accuracy":0.9,"feedback_vi":"Thanh 1 cao và ổn định."}\n```',
        ),
      );

      final res = await service.evaluatePronunciation(
        target: target,
        audioPath: audioFile.path,
        duration: const Duration(milliseconds: 900),
      );

      expect(res.status, equals(PronunciationEvaluationStatus.success));
      expect(res.isAcousticallyAnalyzed, isTrue);
      expect(res.toneAccuracy, equals(0.9));
      expect(res.overallScore, closeTo(0.96, 1e-6));
      expect(res.feedbackList.any((f) => f.contains('Thanh 1 cao và ổn định.')), isTrue);
    });

    test('returns failed when JSON transcript is [NO_SPEECH]', () async {
      final service = DefaultPronunciationAnalysisService(
        aiProvider: _JsonAiProvider(
          '{"transcript":"[NO_SPEECH]","detected_pinyin_tones":"","tone_accuracy":0.0}',
        ),
      );

      final res = await service.evaluatePronunciation(
        target: target,
        audioPath: audioFile.path,
        duration: const Duration(milliseconds: 900),
      );

      expect(res.status, equals(PronunciationEvaluationStatus.failed));
      expect(res.recognizedTranscript, isNull);
    });

    testWidgets('skips recordPronunciationSession on failed/insufficientAudio results', (tester) async {
      MockAudioPlatformHelper.reset();
      PermissionHelper.mockPermissionResult = AudioPermissionResult.granted;
      final spyRepo = _SpyPronunciationRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pronunciationRepositoryProvider.overrideWithValue(spyRepo),
            pronunciationAnalysisServiceProvider.overrideWithValue(
              _FakeAnalysisService(PronunciationEvaluationStatus.insufficientAudio),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PronunciationLabScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.mic_rounded));
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.ensureVisible(find.byIcon(Icons.stop_rounded));
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(PronunciationResultCard), findsOneWidget);
      expect(spyRepo.recordCount, equals(0));
      PermissionHelper.mockPermissionResult = null;
    });
  });
}
