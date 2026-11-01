import 'package:flutter/material.dart';
import '../database/app_database.dart';

typedef AudioSessionStopCallback = void Function(String reason);

/// Manages application lifecycle transitions to guarantee Android policy compliance:
/// - Immediately releases microphone upon app pause, incoming call, or screen lock.
/// - Prevents any silent or background audio recording.
class AppLifecycleManager with WidgetsBindingObserver {
  AppLifecycleManager._();

  static final AppLifecycleManager instance = AppLifecycleManager._();

  final List<AudioSessionStopCallback> _audioStopCallbacks = [];
  bool _isInitialized = false;
  AppLifecycleState _lastState = AppLifecycleState.resumed;

  AppLifecycleState get lastState => _lastState;

  void initialize() {
    if (!_isInitialized) {
      WidgetsBinding.instance.addObserver(this);
      _isInitialized = true;
    }
  }

  void dispose() {
    if (_isInitialized) {
      WidgetsBinding.instance.removeObserver(this);
      _audioStopCallbacks.clear();
      _isInitialized = false;
    }
  }

  /// Register a callback to abort and release microphone recording immediately
  /// whenever the app loses active focus.
  void registerAudioSession(AudioSessionStopCallback onMustStop) {
    if (!_audioStopCallbacks.contains(onMustStop)) {
      _audioStopCallbacks.add(onMustStop);
    }
  }

  void unregisterAudioSession(AudioSessionStopCallback onMustStop) {
    _audioStopCallbacks.remove(onMustStop);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lastState = state;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // App backgrounded, incoming phone call, or screen locked:
        // 1. Force-stop all recording sessions immediately to protect user privacy.
        _stopAllActiveAudioSessions('App backgrounded or focus lost ($state)');
        // 2. Perform background SQLite WAL checkpoint to flush dirty pages to disk safely
        _triggerBackgroundCheckpoint();
        break;
      case AppLifecycleState.detached:
        _stopAllActiveAudioSessions('App detached / terminated');
        break;
      case AppLifecycleState.resumed:
        // App regained foreground. Microphone remains released until explicit user action.
        break;
    }
  }

  void _stopAllActiveAudioSessions(String reason) {
    for (final callback in List.unmodifiable(_audioStopCallbacks)) {
      try {
        callback(reason);
      } catch (_) {
        // Silently isolate callback errors to ensure all callbacks execute
      }
    }
  }

  void _triggerBackgroundCheckpoint() {
    try {
      final db = AppDatabase.instance;
      if (db.isOpen) {
        db.checkpoint(truncate: false).catchError((_) {});
      }
    } catch (_) {
      // Non-fatal background flush
    }
  }
}
