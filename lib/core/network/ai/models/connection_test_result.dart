/// Classification of connection and credential verification errors.
enum ConnectionErrorType {
  /// HTTP 401/403: Invalid or missing API key, or unauthorized access.
  unauthorized,

  /// HTTP 429: Request quota exceeded or rate limit reached.
  quotaExceeded,

  /// HTTP 404: The specified model ID does not exist or has been deprecated.
  modelUnavailable,

  /// HTTP 403 / App Check: Firebase App Check token missing, invalid, or expired.
  appCheckFailed,

  /// SocketException / DNS error / Network disconnected.
  networkError,

  /// Request exceeded timeout threshold (e.g. 15s).
  timeout,

  /// Response could not be parsed as valid JSON or empty payload returned.
  malformedResponse,

  /// No API key or credential has been entered yet.
  emptyCredentials,

  /// General unclassified error.
  unknown,
}

/// The result of a real network round-trip connection test.
///
/// Contains latency metrics, status, classified error type, and actionable
/// Vietnamese troubleshooting recommendations that NEVER expose secrets.
class ConnectionTestResult {
  /// Whether the connection test succeeded with a valid response.
  final bool isSuccess;

  /// Name of the provider tested (e.g. 'Google Gemini REST', 'Firebase AI Logic').
  final String providerName;

  /// Exact model ID tested during the probe.
  final String modelTested;

  /// Measured round-trip network latency in milliseconds.
  final int latencyMs;

  /// Error classification if failed. Null on success.
  final ConnectionErrorType? errorType;

  /// Sanitized error description. Must NEVER contain sensitive credentials.
  final String? errorMessage;

  /// Human-friendly Vietnamese troubleshooting guidance.
  final String? troubleshootingHint;

  /// Timestamp when the test was performed (UTC).
  final DateTime testedAt;

  const ConnectionTestResult({
    required this.isSuccess,
    required this.providerName,
    required this.modelTested,
    required this.latencyMs,
    this.errorType,
    this.errorMessage,
    this.troubleshootingHint,
    required this.testedAt,
  });

  /// Factory for a successful connection test.
  factory ConnectionTestResult.success({
    required String providerName,
    required String modelTested,
    required int latencyMs,
  }) {
    return ConnectionTestResult(
      isSuccess: true,
      providerName: providerName,
      modelTested: modelTested,
      latencyMs: latencyMs,
      errorType: null,
      errorMessage: null,
      troubleshootingHint: 'Kết nối hoạt động ổn định. AI sẵn sàng phục vụ học tập.',
      testedAt: DateTime.now().toUtc(),
    );
  }

  /// Factory for a failed connection test with safe troubleshooting hints.
  factory ConnectionTestResult.failure({
    required String providerName,
    required String modelTested,
    required int latencyMs,
    required ConnectionErrorType errorType,
    required String errorMessage,
    String? customHint,
  }) {
    return ConnectionTestResult(
      isSuccess: false,
      providerName: providerName,
      modelTested: modelTested,
      latencyMs: latencyMs,
      errorType: errorType,
      errorMessage: errorMessage,
      troubleshootingHint: customHint ?? _defaultHintFor(errorType, modelTested),
      testedAt: DateTime.now().toUtc(),
    );
  }

  static String _defaultHintFor(ConnectionErrorType type, String model) {
    switch (type) {
      case ConnectionErrorType.emptyCredentials:
        return 'Vui lòng nhập API Key từ Google AI Studio (aistudio.google.com) rồi nhấn "Lưu Key".';
      case ConnectionErrorType.unauthorized:
        return 'API Key không hợp lệ hoặc không có quyền truy cập. Kiểm tra lại key trên Google AI Studio.';
      case ConnectionErrorType.quotaExceeded:
        return 'Bạn đã dùng hết hạn mức miễn phí (Rate Limit 429). Vui lòng đợi 1–2 phút hoặc nâng cấp gói trong Google Cloud Console.';
      case ConnectionErrorType.modelUnavailable:
        return 'Mô hình "$model" không tồn tại hoặc đã bị ngừng hỗ trợ. Hãy chọn mô hình khác (ví dụ: gemini-3.5-flash-lite).';
      case ConnectionErrorType.appCheckFailed:
        return 'Chứng thực Firebase App Check thất bại. Kiểm tra cấu hình Play Integrity / Debug Token trên Firebase Console.';
      case ConnectionErrorType.networkError:
        return 'Không có kết nối mạng Internet hoặc không thể kết nối tới máy chủ Google AI. Kiểm tra Wi-Fi / 4G.';
      case ConnectionErrorType.timeout:
        return 'Quá thời gian phản hồi (timeout). Kết nối mạng của bạn có thể đang chậm hoặc chập chờn.';
      case ConnectionErrorType.malformedResponse:
        return 'Máy chủ phản hồi dữ liệu không đúng định dạng JSON. Vui lòng thử lại sau.';
      case ConnectionErrorType.unknown:
        return 'Đã xảy ra lỗi không xác định khi kết nối. Vui lòng kiểm tra lại cấu hình hoặc thử lại sau.';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'is_success': isSuccess,
      'provider_name': providerName,
      'model_tested': modelTested,
      'latency_ms': latencyMs,
      'error_type': errorType?.name,
      'error_message': errorMessage,
      'troubleshooting_hint': troubleshootingHint,
      'tested_at': testedAt.toIso8601String(),
    };
  }
}
