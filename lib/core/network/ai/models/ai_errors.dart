abstract class AiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic originalError;

  const AiException(this.message, {this.statusCode, this.originalError});

  @override
  String toString() => '$runtimeType: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
}

class AiAuthenticationException extends AiException {
  const AiAuthenticationException(super.message, {super.statusCode, super.originalError});
}

class AiRateLimitException extends AiException {
  final Duration? retryAfter;
  const AiRateLimitException(super.message, {super.statusCode, this.retryAfter, super.originalError});
}

class AiTimeoutException extends AiException {
  final Duration duration;
  const AiTimeoutException(super.message, {required this.duration, super.originalError});
}

class AiNetworkException extends AiException {
  const AiNetworkException(super.message, {super.originalError});
}

class AiModelNotFoundException extends AiException {
  final String modelName;
  const AiModelNotFoundException(super.message, {required this.modelName, super.statusCode, super.originalError});
}

class AiServerException extends AiException {
  const AiServerException(super.message, {super.statusCode, super.originalError});
}

class AiCancelledException extends AiException {
  const AiCancelledException([super.message = 'AI request was cancelled by the user']);
}

class AiValidationException extends AiException {
  const AiValidationException(super.message);
}
