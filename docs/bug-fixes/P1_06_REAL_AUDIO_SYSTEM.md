# HI CHINESE – IMPLEMENTATION SPECIFICATION: REAL AUDIO PLAYER & AUDIO RECORDER (P1_06)

**Document Version:** 1.0.0  
**Status:** Approved & Implemented  
**Date:** 2026-11-03  
**Authors:** Senior Flutter Audio Engineer & Systems Integration Team  
**Scope:** `lib/core/audio/audio_player_service.dart`, `lib/core/audio/audio_recorder_service.dart`, `lib/core/audio/unified_audio_playback_service.dart`, `test/helpers/mock_audio_platform.dart`, `test/core/audio/audio_services_test.dart`

---

## 1. Executive Summary & Problem Statement

Prior to this implementation, the audio subsystems (`DefaultAudioPlayerService` and `DefaultAudioRecorderService`) were relying on software-simulated timers (`Future.delayed` and `Timer.periodic`) generating artificial sinusoidal waveform values instead of communicating with native mobile audio hardware. 

This caused several critical issues:
1. **No native audio output**: Audio files downloaded from offline packs or streamed from CDN endpoints could not actually be decoded or heard through device speakers or headphones.
2. **No native microphone input**: Speech evaluation, pronunciation assessments, and shadowing exercises were processing zero-byte dummy waveforms rather than captured user acoustic signals.
3. **Hardware & Lifecycle Desynchronization**: Backgrounding the app or receiving incoming phone calls did not interrupt audio recording or playback, violating platform conventions and battery guidelines.
4. **Mocked Unit Test Fragility**: Absence of native audio platform mocks prevented headless testing of real playback/recording lifecycles.

---

## 2. Dependencies & Package Selection

In accordance with strict dependency and compatibility audits:

| Package | Version Pin | Primary Responsibility | Native Android Driver |
|---|---|---|---|
| `just_audio` | `^0.10.6` | High-fidelity audio playback (local files, assets, remote streams) | ExoPlayer (Android Media3) |
| `record` | `^7.1.2` | Native microphone audio capture, amplitude streaming, duration tracking | Android MediaRecorder / AudioRecord (AAC-LC) |
| `path_provider` | `^2.1.6` | Resolving platform-specific temporary cache directories for audio files | Android context cache dir |
| `flutter_tts` | `^4.2.5` | Chinese text-to-speech fallback (`zh-CN`), distinct from human recordings | Android TextToSpeech engine |
| `permission_handler` | `^11.4.0` | On-demand microphone permission verification & runtime requesting | Android Runtime Permissions |

---

## 3. Architecture & Implementation Details

### 3.1 Native Audio Player (`DefaultAudioPlayerService`)
- **Engine**: Powered by `just_audio.AudioPlayer()`.
- **Source Resolution**:
  - `assets/...` $\rightarrow$ `ja.AudioSource.asset(uri)`
  - `http://` / `https://` $\rightarrow$ `ja.AudioSource.uri(Uri.parse(uri))`
  - Local filesystem path $\rightarrow$ Verified via `File(cleanPath).exists()`. If the file does not exist, immediately transitions status to `AudioPlaybackStatus.error` and throws a strongly typed `AudioPlaybackException` containing the file path and localized reason.
- **Playback Controls**:
  - `play()`, `pause()`, `stop()`, `seek(Duration position)`
  - `setSpeed(double speed)` clamped within $[0.5, 2.0]$.
  - `setLooping(bool loop)` mapped to `ja.LoopMode.one` vs `ja.LoopMode.off`.
- **Reactive Streams**:
  - `playerStateStream` mapped to `AudioPlaybackStatus` (`idle`, `loading`, `playing`, `paused`, `completed`, `error`).
  - `positionStream` and `durationStream` exposed for real-time progress bars.

### 3.2 Native Audio Recorder (`DefaultAudioRecorderService`)
- **Engine**: Powered by `record.AudioRecorder()`.
- **Encoding Configuration**:
  ```dart
  final config = rec.RecordConfig(
    encoder: rec.AudioEncoder.aacLc,
    sampleRate: 16000, // 16kHz optimized for speech recognition & low latency
    numChannels: 1,    // Mono channel
    bitRate: 128000,
  );
  ```
- **Permission & Safety**:
  - Permission is checked on demand via `recorder.hasPermission()` and `PermissionHelper`.
  - Microphones are **never** requested at application launch or startup.
  - If permission is denied, transitions to `AudioRecordingStatus.error` and throws an `AudioRecordingException`.
- **Lifecycle Integration (`AppLifecycleManager`)**:
  - Observes `AppLifecycleState.paused`, `inactive`, and `detached`.
  - When the app loses focus or goes to background while recording, `AppLifecycleManager` immediately halts and cancels the recording to safeguard user privacy and prevent battery drain.
- **Waveform & Duration**:
  - Streams real peak decibels normalized to $[0.0, 1.0]$ via `recorder.getAmplitude()` polled at $60\text{ms}$ intervals.
  - Duration timer emits accurate accumulated elapsed time, correctly preserving state through `pauseRecording()` and `resumeRecording()`.

### 3.3 Test Platform Interception (`MockAudioPlatformHelper`)
To guarantee that `flutter test` executes headlessly in CI without requiring physical Android hardware or emulators:
- Implemented `MockJustAudioPlatform` extending `JustAudioPlatform`.
- Implemented `MockAudioPlayerPlatform` returning synthetic `LoadResponse`, `PlayResponse`, etc.
- Mocked method channels for `com.llfbandit.record/messages` and `flutter.baseflow.com/permissions/methods`.

---

## 4. Verification & Test Results

All verification suites executed and passed with 0 errors and 0 warnings:

```powershell
flutter test test/core/audio/audio_services_test.dart
# Output: 00:01 +7: All tests passed!

flutter test test/features/sentences/audio_pack_cdn_test.dart
# Output: 00:04 +2: All tests passed!

flutter test test/features/audio_management/audio_management_offline_test.dart
# Output: 00:01 +6: All tests passed!

dart analyze lib test
# Output: Analyzing lib, test... No issues found!
```

---

## 5. Security & Privacy Guarantees
- Temporary recordings are written to secure application cache directories (`getTemporaryDirectory()`), inaccessible to other applications without root privileges.
- Microphone hardware is released immediately on `stopRecording()`, `cancelRecording()`, or `dispose()`.
- No microphone access is triggered until the user explicitly taps a record or voice evaluation interaction.
