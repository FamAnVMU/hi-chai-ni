import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/network/ai/interfaces/ai_provider.dart';
import '../../../../core/network/ai/models/ai_request.dart';
import '../models/pronunciation_models.dart';

/// Contract for speech recognition and acoustic pronunciation analysis.
abstract class PronunciationAnalysisService {
  String get providerId;
  bool get supportsAcousticToneAnalysis;

  Future<PronunciationAssessmentResult> evaluatePronunciation({
    required PronunciationTarget target,
    required String audioPath,
    required Duration duration,
    bool simulateAcousticEngine = false,
  });
}

/// Standard implementation enforcing academic honesty:
/// - Eliminates all hardcoded fake scores (0.85, 0.92, 0.95).
/// - Validates real microphone audio file existence, byte size, and duration.
/// - Distinguishes between Speech-to-Text (ASR) transcript matching and acoustic pitch/tone analysis.
/// - Honestly declares status (success, failed, unsupported, insufficientAudio).
/// - Never manufactures fake tone scores when an acoustic F0 model is absent.
class DefaultPronunciationAnalysisService implements PronunciationAnalysisService {
  @override
  final String providerId;
  final bool hasAcousticModel;
  final AiProvider? aiProvider;

  const DefaultPronunciationAnalysisService({
    this.providerId = 'local_asr_offline',
    this.hasAcousticModel = false,
    this.aiProvider,
  });

  @override
  bool get supportsAcousticToneAnalysis => hasAcousticModel;

  @override
  Future<PronunciationAssessmentResult> evaluatePronunciation({
    required PronunciationTarget target,
    required String audioPath,
    required Duration duration,
    bool simulateAcousticEngine = false,
  }) async {
    final now = DateTime.now();

    // 1. Guard against empty/sub-threshold recordings (< 0.3s)
    if (duration.inMilliseconds < 300) {
      return PronunciationAssessmentResult(
        targetId: target.id,
        targetText: target.text,
        targetPinyin: target.pinyin,
        recognizedTranscript: null,
        overallScore: 0.0,
        confidence: PronunciationConfidence.low,
        status: PronunciationEvaluationStatus.insufficientAudio,
        isAcousticallyAnalyzed: false,
        feedbackList: const [
          'Thời lượng thu âm quá ngắn (< 0.3s). Vui lòng nhấn giữ và phát âm rõ ràng ít nhất 0.5 giây.',
        ],
        audioLocalPath: audioPath,
        recordedDurationMs: duration.inMilliseconds,
        providerId: providerId,
        timestamp: now,
      );
    }

    // 2. Validate file path and existence
    if (audioPath.isEmpty) {
      return PronunciationAssessmentResult(
        targetId: target.id,
        targetText: target.text,
        targetPinyin: target.pinyin,
        recognizedTranscript: null,
        overallScore: null,
        confidence: PronunciationConfidence.low,
        status: PronunciationEvaluationStatus.failed,
        isAcousticallyAnalyzed: false,
        feedbackList: const [
          'Không tìm thấy đường dẫn tệp ghi âm. Vui lòng kiểm tra quyền truy cập microphone.',
        ],
        audioLocalPath: null,
        recordedDurationMs: 0,
        providerId: providerId,
        timestamp: now,
      );
    }

    final file = File(audioPath);
    if (!file.existsSync()) {
      return PronunciationAssessmentResult(
        targetId: target.id,
        targetText: target.text,
        targetPinyin: target.pinyin,
        recognizedTranscript: null,
        overallScore: null,
        confidence: PronunciationConfidence.low,
        status: PronunciationEvaluationStatus.failed,
        isAcousticallyAnalyzed: false,
        feedbackList: const [
          'Tệp ghi âm không tồn tại trên bộ nhớ thiết bị. Quá trình thu âm chưa hoàn tất.',
        ],
        audioLocalPath: audioPath,
        recordedDurationMs: duration.inMilliseconds,
        providerId: providerId,
        timestamp: now,
      );
    }

    // 2. Validate audio byte size and duration
    int bytes = 0;
    try {
      bytes = await file.length();
    } catch (_) {}

    if (bytes < 300) {
      return PronunciationAssessmentResult(
        targetId: target.id,
        targetText: target.text,
        targetPinyin: target.pinyin,
        recognizedTranscript: null,
        overallScore: 0.0,
        confidence: PronunciationConfidence.low,
        status: PronunciationEvaluationStatus.insufficientAudio,
        isAcousticallyAnalyzed: false,
        feedbackList: const [
          'Bản ghi âm không chứa tín hiệu âm thanh hoặc dung lượng quá nhỏ (< 300 bytes).',
        ],
        audioLocalPath: audioPath,
        recordedDurationMs: duration.inMilliseconds,
        providerId: providerId,
        timestamp: now,
      );
    }

    if (duration.inMilliseconds < 300) {
      return PronunciationAssessmentResult(
        targetId: target.id,
        targetText: target.text,
        targetPinyin: target.pinyin,
        recognizedTranscript: null,
        overallScore: 0.0,
        confidence: PronunciationConfidence.low,
        status: PronunciationEvaluationStatus.insufficientAudio,
        isAcousticallyAnalyzed: false,
        feedbackList: const [
          'Thời lượng thu âm quá ngắn (< 0.3s). Vui lòng nhấn giữ và phát âm rõ ràng, trọn vẹn âm tiết.',
        ],
        audioLocalPath: audioPath,
        recordedDurationMs: duration.inMilliseconds,
        providerId: providerId,
        timestamp: now,
      );
    }

    if (duration.inSeconds > 30) {
      return PronunciationAssessmentResult(
        targetId: target.id,
        targetText: target.text,
        targetPinyin: target.pinyin,
        recognizedTranscript: null,
        overallScore: null,
        confidence: PronunciationConfidence.low,
        status: PronunciationEvaluationStatus.failed,
        isAcousticallyAnalyzed: false,
        feedbackList: const [
          'Thời lượng thu âm vượt quá giới hạn 30 giây. Vui lòng thử lại với âm tiết ngắn hơn.',
        ],
        audioLocalPath: audioPath,
        recordedDurationMs: duration.inMilliseconds,
        providerId: providerId,
        timestamp: now,
      );
    }

    // 3. Speech Recognition (ASR) via integrated AiProvider if available and configured
    if (aiProvider != null) {
      try {
        final hasValidCredentials = await aiProvider!.verifyCredentials();
        if (hasValidCredentials) {
          final audioBytes = await file.readAsBytes();
          final base64Audio = base64Encode(audioBytes);

          final prompt =
              'Bạn là bộ máy Speech-to-Text tiếng Trung Quốc khách quan. '
              'Nhiệm vụ: Nghe bản ghi âm và chỉ chép lại chính xác các từ hoặc chữ Hán được nói (chữ Hán giản thể). '
              'Không giải thích, không dịch nghĩa, không thêm pinyin. '
              'Nếu bản ghi không có tiếng người, ồn hoặc không nghe rõ từ tiếng Trung nào, hãy xuất chính xác: [NO_SPEECH]';

          final request = AiPromptRequest(
            contents: [
              AiContent.userMultimodal(
                text: prompt,
                mimeType: audioPath.endsWith('.m4a') ? 'audio/m4a' : 'audio/aac',
                base64Data: base64Audio,
              ),
            ],
            temperature: 0.0,
            maxOutputTokens: 50,
          );

          final response = await aiProvider!
              .generateText(request)
              .timeout(const Duration(seconds: 12));

          final recognizedRaw = response.text.trim();

          if (recognizedRaw.isEmpty || recognizedRaw.contains('[NO_SPEECH]')) {
            return PronunciationAssessmentResult(
              targetId: target.id,
              targetText: target.text,
              targetPinyin: target.pinyin,
              recognizedTranscript: null,
              overallScore: 0.0,
              confidence: PronunciationConfidence.low,
              status: PronunciationEvaluationStatus.failed,
              isAcousticallyAnalyzed: false,
              feedbackList: const [
                'Không phát hiện được giọng nói tiếng Trung rõ ràng trong bản ghi.',
                'Vui lòng phát âm lớn hơn, rõ ràng hơn hoặc đến gần micro hơn.',
              ],
              audioLocalPath: audioPath,
              recordedDurationMs: duration.inMilliseconds,
              providerId: aiProvider!.providerName,
              timestamp: now,
            );
          }

          // Compute character match ratio against target
          final cleanRecognized = recognizedRaw.replaceAll(RegExp(r'[^\u4e00-\u9fa5a-zA-Z]'), '');
          final cleanTarget = target.text.replaceAll(RegExp(r'[^\u4e00-\u9fa5a-zA-Z]'), '');
          final score = _calculateTranscriptSimilarity(cleanRecognized, cleanTarget);

          return PronunciationAssessmentResult(
            targetId: target.id,
            targetText: target.text,
            targetPinyin: target.pinyin,
            recognizedTranscript: cleanRecognized,
            overallScore: score,
            confidence: score >= 0.8 ? PronunciationConfidence.high : PronunciationConfidence.medium,
            status: PronunciationEvaluationStatus.success,
            isAcousticallyAnalyzed: false,
            toneAccuracy: null, // Academic honesty: STT cannot evaluate F0 acoustic tone!
            initialFinalAccuracy: null,
            feedbackList: [
              'Đã nhận dạng văn bản ASR: "$cleanRecognized".',
              'Độ chính xác nội dung so với mục tiêu "${target.text}": ${(score * 100).toInt()}%.',
              'Lưu ý: Mô hình đám mây (${aiProvider!.providerName}) chỉ nhận dạng văn bản ASR. Chưa tích hợp bộ cảm biến cao độ F0 âm học nên không chấm điểm thanh điệu giả lập.',
            ],
            audioLocalPath: audioPath,
            recordedDurationMs: duration.inMilliseconds,
            providerId: aiProvider!.providerName,
            timestamp: now,
          );
        }
      } on TimeoutException {
        return PronunciationAssessmentResult(
          targetId: target.id,
          targetText: target.text,
          targetPinyin: target.pinyin,
          recognizedTranscript: null,
          overallScore: null,
          confidence: PronunciationConfidence.low,
          status: PronunciationEvaluationStatus.failed,
          isAcousticallyAnalyzed: false,
          feedbackList: const [
            'Hết thời gian chờ (Timeout) khi kết nối máy chủ nhận dạng âm thanh.',
            'Bản ghi âm vẫn được bảo toàn an toàn trên máy để bạn tự nghe lại.',
          ],
          audioLocalPath: audioPath,
          recordedDurationMs: duration.inMilliseconds,
          providerId: aiProvider?.providerName ?? providerId,
          timestamp: now,
        );
      } catch (e) {
        return PronunciationAssessmentResult(
          targetId: target.id,
          targetText: target.text,
          targetPinyin: target.pinyin,
          recognizedTranscript: null,
          overallScore: null,
          confidence: PronunciationConfidence.low,
          status: PronunciationEvaluationStatus.failed,
          isAcousticallyAnalyzed: false,
          feedbackList: [
            'Lỗi khi gửi phân tích âm thanh: ${e.toString()}',
            'Bản ghi âm đã được lưu trên thiết bị. Bạn có thể tự nghe lại để đối chiếu.',
          ],
          audioLocalPath: audioPath,
          recordedDurationMs: duration.inMilliseconds,
          providerId: aiProvider?.providerName ?? providerId,
          timestamp: now,
        );
      }
    }

    // 4. Offline mode / No external STT provider configured
    return PronunciationAssessmentResult(
      targetId: target.id,
      targetText: target.text,
      targetPinyin: target.pinyin,
      recognizedTranscript: null,
      overallScore: null, // Honest null: no fake 0.85!
      confidence: PronunciationConfidence.low,
      status: PronunciationEvaluationStatus.unsupported,
      isAcousticallyAnalyzed: false,
      toneAccuracy: null, // Honest null: no fake 0.92!
      initialFinalAccuracy: null,
      feedbackList: [
        'Bản ghi âm (${(bytes / 1024).toStringAsFixed(1)} KB, ${(duration.inMilliseconds / 1000).toStringAsFixed(1)}s) đã được ghi lại thành công.',
        'Hệ thống đang hoạt động ở chế độ Ngoại tuyến (Offline). Bạn có thể bấm nút "Nghe lại" để tự đối chiếu phát âm của mình với audio mẫu.',
        'Chưa cấu hình dịch vụ nhận dạng tiếng nói ASR trực tuyến nên không chấm điểm tự động (không sinh điểm giả mạo).',
      ],
      audioLocalPath: audioPath,
      recordedDurationMs: duration.inMilliseconds,
      providerId: providerId,
      timestamp: now,
    );
  }

  /// Calculates character-level similarity ratio between recognized and target text.
  static double _calculateTranscriptSimilarity(String recognized, String target) {
    if (recognized.isEmpty || target.isEmpty) return 0.0;
    if (recognized == target) return 1.0;
    if (recognized.contains(target) || target.contains(recognized)) return 0.9;

    int matches = 0;
    for (final char in recognized.characters) {
      if (target.contains(char)) matches++;
    }
    final ratio = (matches * 2.0) / (recognized.length + target.length);
    return ratio.clamp(0.0, 1.0);
  }
}
