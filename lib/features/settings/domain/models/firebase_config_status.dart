/// Status of Firebase initialization and App Check security layer.
enum FirebaseInitState {
  /// Firebase has not been configured in this build (e.g. BYOK offline mode).
  uninitialized,

  /// Firebase Core initialized successfully via google-services.json.
  initialized,

  /// Failed to initialize Firebase (e.g. missing options or network timeout).
  failed,
}

/// Status of Firebase App Check device attestation.
enum AppCheckState {
  /// App Check is disabled or not configured.
  disabled,

  /// App Check is active and enforcing valid tokens.
  active,

  /// App Check token attestation failed (e.g. untrusted device or debug token mismatch).
  tokenError,
}

/// Snapshot of Firebase AI Logic backend and App Check configuration state.
class FirebaseConfigStatus {
  final FirebaseInitState initState;
  final AppCheckState appCheckState;
  final String? projectId;
  final String? errorMessage;

  const FirebaseConfigStatus({
    this.initState = FirebaseInitState.uninitialized,
    this.appCheckState = AppCheckState.disabled,
    this.projectId,
    this.errorMessage,
  });

  bool get isReady =>
      initState == FirebaseInitState.initialized &&
      appCheckState == AppCheckState.active;

  Map<String, dynamic> toMap() {
    return {
      'init_state': initState.name,
      'app_check_state': appCheckState.name,
      'project_id': projectId,
      'error_message': errorMessage,
    };
  }
}
