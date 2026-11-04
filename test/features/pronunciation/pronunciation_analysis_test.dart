import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/network/ai/interfaces/ai_provider.dart';
import 'package:hi_chinese/core/network/ai/models/ai_model_config.dart';
import 'package:hi_chinese/core/network/ai/models/ai_request.dart';
import 'package:hi_chinese/core/network/ai/models/ai_response.dart';
import 'package:hi_chinese/core/network/ai/models/cancel_token.dart';
import 'package:hi_chinese/core/network/ai/models/connection_test_result.dart';
import 'package:hi_chinese/features/pronunciation/pronunciation.dart';

class _FakeAiSttProvider implements AiProvider {
  final String transcriptToReturn;
  final bool shouldTimeout;
  final bool shouldFail;

  _FakeAiSttProvider({
    this.transcriptToReturn = '妈',
    this.shouldTimeout = false,
    this.shouldFail = false,
  });

  @override
  String get providerName => 'fake_gemini_stt';

  @override
  Future<bool> verifyCredentials() async => true;

  @override
  Future<AiTextResponse> generateText(
    AiPromptRequest request, {
    AiModelConfig? config,
    Duration timeout = const Duration(seconds: 30),
    CancelToken? cancelToken,
  }) async {
    if (shouldTimeout) {
      throw TimeoutException('Request timeout');
    }
    if (shouldFail) {
      throw Exception('Server error');
    }
    return AiTextResponse(
      text: transcriptToReturn,
      latencyMs: 50,
      modelUsed: 'gemini-2.5-flash',
    );
  }

  @override
  Stream<AiStreamChunk> streamText(
    AiPromptRequest request, {
    AiModelConfig? config,
    Duration timeout = const Duration(seconds: 45),
    CancelToken? cancelToken,
  }) {
    return Stream.value(AiStreamChunk(index: 0, text: transcriptToReturn));
  }

  @override
  Future<ConnectionTestResult> testConnection({String? modelId}) async {
    return ConnectionTestResult.success(
      providerName: providerName,
      modelTested: modelId ?? 'gemini-2.5-flash',
      latencyMs: 100,
    );
  }

  @override
  void dispose() {}
}

void main() {
  group('Pronunciation Analysis Service & Academic Honesty Tests', () {
    const target = PronunciationTarget(
      id: 'TONE_01_MA1',
      text: '妈',
      pinyin: 'mā',
      meaningVi: 'Mẹ',
      category: PronunciationCategory.tone,
    );

    late File testAudioFile;

    setUpAll(() {
      final tempDir = Directory.systemTemp;
      testAudioFile = File('${tempDir.path}/test_speech_rec.wav');
      // Create valid audio file (> 300 bytes)
      testAudioFile.writeAsBytesSync(List.filled(600, 0x42));
    });

    tearDownAll(() {
      if (testAudioFile.existsSync()) {
        try {
          testAudioFile.deleteSync();
        } catch (_) {}
      }
    });

    test('1. Short recording (< 0.3s) is flagged with insufficientAudio status and retry guidance', () async {
      const service = DefaultPronunciationAnalysisService();
      final result = await service.evaluatePronunciation(
        target: target,
        audioPath: 'dummy.wav',
        duration: const Duration(milliseconds: 150),
      );

      expect(result.status, equals(PronunciationEvaluationStatus.insufficientAudio));
      expect(result.overallScore, equals(0.0));
      expect(result.confidence, equals(PronunciationConfidence.low));
      expect(result.isAcousticallyAnalyzed, isFalse);
      expect(result.feedbackList.first, contains('Thời lượng thu âm quá ngắn'));
    });

    test('2. Non-existent audio file returns failed status without crash', () async {
      const service = DefaultPronunciationAnalysisService();
      final result = await service.evaluatePronunciation(
        target: target,
        audioPath: 'non_existent_file_99999.wav',
        duration: const Duration(milliseconds: 1200),
      );

      expect(result.status, equals(PronunciationEvaluationStatus.failed));
      expect(result.overallScore, equals(0.0));
      expect(result.recognizedTranscript, isNull);
      expect(result.feedbackList.first, contains('không tồn tại'));
    });

    test('3. Offline mode without cloud STT honestly returns unsupported status and NO fake scores', () async {
      const service = DefaultPronunciationAnalysisService(
        providerId: 'local_offline',
        hasAcousticModel: false,
      );

      final result = await service.evaluatePronunciation(
        target: target,
        audioPath: testAudioFile.path,
        duration: const Duration(milliseconds: 1200),
      );

      expect(result.status, equals(PronunciationEvaluationStatus.unsupported));
      expect(result.overallScore, isNull, reason: 'Zero fake scores in offline mode');
      expect(result.toneAccuracy, isNull, reason: 'Zero fake tone scores');
      expect(result.recognizedTranscript, isNull);
      expect(result.isAcousticallyAnalyzed, isFalse);
      expect(result.audioLocalPath, equals(testAudioFile.path));
      expect(result.feedbackList.any((f) => f.contains('Ngoại tuyến (Offline)')), isTrue);
    });

    test('4. Connected AI STT recognizes text and preserves Academic Honesty (null tone score)', () async {
      final fakeStt = _FakeAiSttProvider(transcriptToReturn: '妈');
      final service = DefaultPronunciationAnalysisService(
        aiProvider: fakeStt,
        hasAcousticModel: false,
      );

      final result = await service.evaluatePronunciation(
        target: target,
        audioPath: testAudioFile.path,
        duration: const Duration(milliseconds: 1200),
      );

      expect(result.status, equals(PronunciationEvaluationStatus.success));
      expect(result.recognizedTranscript, equals('妈'));
      expect(result.isRecognizedAccurately, isTrue);
      expect(result.overallScore, equals(1.0));
      // Academic honesty assertions:
      expect(result.isAcousticallyAnalyzed, isFalse);
      expect(result.toneAccuracy, isNull, reason: 'Must NOT fake tone score when only pure text ASR was performed');
      expect(result.initialFinalAccuracy, isNull);
      expect(result.feedbackList.any((f) => f.contains('Chưa tích hợp bộ cảm biến cao độ F0')), isTrue);
    });

    test('5. Connected AI STT handles network timeout gracefully', () async {
      final timeoutStt = _FakeAiSttProvider(shouldTimeout: true);
      final service = DefaultPronunciationAnalysisService(aiProvider: timeoutStt);

      final result = await service.evaluatePronunciation(
        target: target,
        audioPath: testAudioFile.path,
        duration: const Duration(milliseconds: 1200),
      );

      expect(result.status, equals(PronunciationEvaluationStatus.failed));
      expect(result.overallScore, isNull);
      expect(result.feedbackList.any((f) => f.contains('Timeout')), isTrue);
    });

    test('6. Connected AI STT handles general server errors gracefully', () async {
      final failStt = _FakeAiSttProvider(shouldFail: true);
      final service = DefaultPronunciationAnalysisService(aiProvider: failStt);

      final result = await service.evaluatePronunciation(
        target: target,
        audioPath: testAudioFile.path,
        duration: const Duration(milliseconds: 1200),
      );

      expect(result.status, equals(PronunciationEvaluationStatus.failed));
      expect(result.overallScore, isNull);
      expect(result.feedbackList.any((f) => f.contains('Lỗi khi gửi phân tích âm thanh')), isTrue);
    });
  });
}
