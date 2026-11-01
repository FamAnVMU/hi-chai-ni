/// Represents the startup and initialization state of HI Chinese.
class AppStartupState {
  final bool isInitializing;
  final bool isReady;
  final String? error;
  final String statusMessage;

  const AppStartupState({
    this.isInitializing = true,
    this.isReady = false,
    this.error,
    this.statusMessage = 'Đang khởi động HI Chinese...',
  });

  AppStartupState copyWith({
    bool? isInitializing,
    bool? isReady,
    String? error,
    String? statusMessage,
  }) {
    return AppStartupState(
      isInitializing: isInitializing ?? this.isInitializing,
      isReady: isReady ?? this.isReady,
      error: error,
      statusMessage: statusMessage ?? this.statusMessage,
    );
  }
}
