# T4 — Async/Performance Audit (AI Tutor voice/text, audio services, lifecycle, startup, shell)

**Auditor:** perf-async (T4) · **Task:** task-4 · **Mode:** read-only static audit (no `flutter`/`dart` build or test commands were run, per task constraints)
**Repo:** `C:\Users\phama\Downloads\hi_chinese` · **Snapshot:** working tree as found during audit
**Scope:** `lib/core/audio/**`, `lib/core/utils/app_lifecycle_manager.dart`, `lib/core/startup/**`, `lib/core/router/**`, `lib/features/ai_tutor/**`, `lib/features/app_shell/**`, `lib/features/audio_management/**`, `lib/core/theme/components/**` (controller ownership only), plus repo-wide greps for `Timer(`, `Timer.periodic`, `.listen(`, `StreamController`, `WebSocket`, `AudioPlayer(`/`AudioRecorder`, `AnimationController`, `TextEditingController`, `FocusNode`, `Future.delayed`, `addPostFrameCallback`, `mounted`, `dispose()`, `autoDispose`.

All line numbers below were re-verified against the current files. Snippets are quoted verbatim (abridged with `...` where marked).

---

## Top 5 priority order

1. **[T4-F01] Critical — Leaving the AI Tutor tab (or switching to text mode) never ends the voice session: the microphone keeps recording inside the permanently-mounted `IndexedStack`.** One bottom-nav tap while the voice status is `listening` leaves the recorder hot with no visible UI.
2. **[T4-F02] Critical — An in-flight voice turn cannot be cancelled and resurrects a session that the user ended / the OS backgrounded.** `endSession()`/`_onLifecycleAbort()` stop the mic and audio, then the pending AI future resolves and the service plays TTS (possibly while backgrounded), sets status back to `listening`, and tries to resume the recorder.
3. **[T4-F03] High — Voice-session startup has no abort/cancel checkpoint.** `startSession()` has no `_isStarting` flag and no lifecycle re-check after its awaits; backgrounding during `connecting`/greeting still reaches `recorder.startRecording()`. `_onLifecycleAbort` ignores `connecting`/`requestingPermission` states.
4. **[T4-F04] High — Mic-test dialog is barrier-dismissible; tapping outside dismisses the dialog but leaves the recorder running indefinitely** (`startMicTest()` started, `stopMicTest()` never reached, `_isMicTesting` stays true).
5. **[T4-F05] High — Playback has no interruption/audio-focus handling.** Only the recorder and voice service register lifecycle callbacks; `DefaultAudioPlayerService`/TTS keep playing on app background, screen lock or incoming call. `docs/bug-fixes/P1_06_REAL_AUDIO_SYSTEM.md` claims this class of issue was fixed — code contradicts it for playback.

Then (see full list below): recorder lifecycle-callback leak (F06), double-tap `startSession` race (F07), eager instantiation of all 5 tabs + full voice audio stack at shell mount (F08), duplicated amplitude stream + async `Timer.periodic` (F09), per-token `setState`/`animateTo` streaming storm (F10), unbounded chat history + full-history DB fetch per turn (F11), unbounded transcript list with per-event O(n) copies (F12), and the N+1/UI-isolate work items in `audio_management` and content-pack startup import (F13–F15).

---

## Severity / confidence counts

| Severity | Count | IDs |
|---|---|---|
| Critical | 2 | F01, F02 |
| High | 5 | F03, F04, F05, F06, F07 |
| Medium | 12 | F08–F19 |
| Low / Low–Medium | 6 | F20–F25 |

Confidence: every finding has CONFIRMED code evidence (read + line-verified); 7 findings carry an explicit LIKELY qualifier for device-visible impact (F02, F05, F07, F18, F19, F20, F24) and 1 a RISK qualifier for a real-device outcome that depends on OS mic policy (F03). No finding is based on documentation alone.

---

## Resource ownership matrix

> "Released where" is the code path that actually disposes the resource today. **Gap** = the ownership/release defect.

| Owner file | Creates | Released where | Gap |
|---|---|---|---|
| `lib/core/audio/audio_player_service.dart` (`DefaultAudioPlayerService`) | `just_audio.AudioPlayer`, 3 stream subscriptions, 2 broadcast `StreamController`s | `dispose()` L262–271 (cancels 3 subs, disposes owned player, closes controllers) | Release is fire-and-forget (`_player.dispose()` not awaited); no lifecycle/interruption hook; if an external player is injected the wrapper's controllers are still closed but the player is not paused (owned by caller). |
| `lib/core/audio/audio_recorder_service.dart` (`DefaultAudioRecorderService`) | `record.AudioRecorder`, `Timer.periodic` duration poll, amplitude subscription, 3 broadcast controllers, **`AppLifecycleManager` callback** | `dispose()` L300–310 (timer + amp sub + native recorder + controllers) | **`AppLifecycleManager.unregisterAudioSession()` is never called** → callback list grows for every created recorder; native `dispose()` not awaited; temp recording file never deleted. |
| `lib/core/audio/tts_service.dart` (`DefaultTtsService`) | `FlutterTts` engine + 4 handlers | `dispose()` L109–114 (`stop()` only, unawaited) | Handlers never cleared, no `isSpeaking` stream/status, `stop()` is a no-op when internal `_isSpeaking == false`. One engine per widget (see F18). |
| `lib/core/audio/unified_audio_playback_service.dart` (singleton) | wrapped `DefaultAudioPlayerService`, 2 subscriptions, 2 broadcast controllers | `dispose()` L114–118 — **never called in app code** | 2 controllers never closed; API not serialized (F16); most feature modules bypass it (F19). |
| `lib/features/ai_tutor/domain/voice/voice_conversation_service.dart` (`DefaultVoiceConversationService`) | 4 broadcast controllers, recorder/player/tts refs, `_transcripts` list, `AppLifecycleManager` callback | `dispose()` L524–539 (unregisters callback ✔, cancels 2 subs, closes 4 controllers) | Only runs at `ProviderContainer` teardown (non-autoDispose provider); disposes the **TTS instance it does not own** (F22); `_transcripts` unbounded (F12); no session teardown on screen dispose (F01). |
| `lib/features/ai_tutor/presentation/providers/ai_tutor_providers.dart` | `TtsService`, `AudioRecorderService`, `AudioPlayerService`, `VoiceConversationService`, `AiTutorRepository` | `ref.onDispose` for each (L43–79) | Providers are **not `autoDispose`** → resources live for the whole app run even if AI Tutor is never used (but they are eagerly created at shell mount — F08). |
| `lib/features/shadowing/presentation/screens/shadowing_screen.dart` | `DefaultAudioPlayerService` + `DefaultAudioRecorderService` per screen instance, 3 subs | `dispose()` L66–75 | Recorder's `AppLifecycleManager` callback leaks per screen visit (F06). |
| `lib/features/pronunciation/presentation/screens/pronunciation_lab_screen.dart` | player + recorder per screen, 3 subs | `dispose()` L73–80 | Same callback leak (F06). |
| `lib/features/sentences/presentation/screens/sentence_shadowing_screen.dart` | `SentenceAudioManager` (own player + TTS) + recorder + second player, 4 **untracked** `.listen()` subs | `dispose()` L68–73 | Recorder callback leak; untracked subscriptions (F23). |
| `lib/features/vocabulary_srs/presentation/widgets/flashcard_card.dart` | `AnimationController` + `DefaultAudioPlayerService` + `DefaultTtsService` **per card** | `dispose()` L83–94 (correct, owner flags respected) | One native player + one TTS engine per flashcard instance (F18). |
| `lib/features/curriculum/presentation/widgets/lesson_vocab_view.dart` | player + TTS per view, un-tracked status `.listen()` | `dispose()` L64–75 | Subscription never cancelled when dependencies are injected (F23). |
| `lib/features/sentences/domain/services/sentence_audio_manager.dart` | player + native TTS + 2 controllers + **untracked** `.listen()` subs | `dispose()` L141–148 | Untracked subs; disposes injected player it does not own. |
| `lib/features/ai_tutor/presentation/screens/ai_tutor_text_chat_screen.dart` | 2 `TextEditingController`/`ScrollController`, `CancelToken`, stream sub, dialog `TextEditingController` | `dispose()` L43–49 | Dialog-scoped controller never disposed (F24); per-token setState (F10). |
| `lib/features/ai_tutor/presentation/screens/ai_tutor_voice_chat_screen.dart` | 2 controllers, 2 subs, `WidgetsBindingObserver` | `dispose()` L68–75 | Does **not** end session / stop mic test on dispose (F01/F04). |
| `lib/core/utils/app_lifecycle_manager.dart` | `WidgetsBindingObserver` registration + callback list | `dispose()` L27–33 | `dispose()` is never called; callback list has no per-owner removal (consumers must unregister — recorder doesn't). |

---

## Findings

### [T4-F01] Voice session survives tab switch / mode switch — microphone stays recording while another tab is visible
- **Severity:** Critical
- **Confidence:** CONFIRMED
- **Location:** `lib/features/app_shell/presentation/screens/app_shell.dart:104-119`; `lib/features/ai_tutor/presentation/screens/ai_tutor_tab_screen.dart:269-275`; `lib/features/ai_tutor/domain/voice/voice_conversation_service.dart:389-390`
- **Evidence:**
```dart
// app_shell.dart:103-119
      child: Scaffold(
        body: IndexedStack(
          index: currentTab.index,
          children: const [
            HomeScreen(),
            LearningScreen(),
            AiTutorTabScreen(),
            ReviewScreen(),
            ProfileScreen(),
          ],
        ),
        bottomNavigationBar: HiBottomNavBar(
          currentTab: currentTab,
          onTabSelected: (tab) {
            ref.read(selectedTabProvider.notifier).selectTab(tab);
          },
        ),
      ),
```
```dart
// ai_tutor_tab_screen.dart:269-275 — both chat screens are mounted simultaneously
      body: IndexedStack(
        index: mode == AiTutorMode.text ? 0 : 1,
        children: const [
          AiTutorTextChatScreen(),
          AiTutorVoiceChatScreen(),
        ],
      ),
```
```dart
// voice_conversation_service.dart:389-390 — "listening" == mic actually recording
    await recorder.startRecording();
    _setStatus(VoiceConversationStatus.listening);
```
- **Root cause:** `IndexedStack` mounts all five tabs permanently; the AI Tutor tab mounts both text and voice chat screens permanently. The recording session is owned by the non-autoDispose singleton `voiceConversationServiceProvider`, and nothing ties it to tab visibility. The only `endSession()` call site in the whole repo is the in-screen end button (`ai_tutor_voice_chat_screen.dart:115`). Switching bottom tabs or switching the text/voice `SegmentedButton` only changes provider state/stack index — it never touches `player`/`recorder`/voice service.
- **Impact (user-visible / device):** user starts a voice conversation, taps “Trang chủ” to browse while the AI is in the `listening` state → the OS microphone stays active indefinitely behind another screen (privacy guarantee broken, Android mic indicator shows), the 100 ms duration/amplitude timers keep firing, the hidden waveform/tab keeps rebuilding, and the AI session/DB session stays open. Battery drain and user trust impact.
- **Fix:** explicitly end or suspend the session when the tab/mode becomes inactive. Minimal, ownership-preserving fix:
```dart
// app_shell.dart
onTabSelected: (tab) {
  final previous = ref.read(selectedTabProvider);
  ref.read(selectedTabProvider.notifier).selectTab(tab);
  if (previous == AppTab.aiTutor && tab != AppTab.aiTutor) {
    // fire-and-forget but safe: service keeps its own state machine
    ref.read(voiceConversationServiceProvider).endSession();
  }
},
```
Better: expose `VoiceConversationService.onHostInactive()` and call it from `AiTutorTabScreen.onSelectionChanged` (when leaving voice mode) and from a `TickerMode`/`Visibility`-aware ancestor; add `deactivate()`/`dispose()` teardown in `AiTutorVoiceChatScreen`:
```dart
@override
void dispose() {
  final service = ref.read(voiceConversationServiceProvider);
  service.endSession();            // release mic + player
  WidgetsBinding.instance.removeObserver(this);
  _statusSub?.cancel();
  _transcriptSub?.cancel();
  ...
}
```
- **Verification status:** traced `onTabSelected` → `SelectedTabNotifier.selectTab` only (`app_shell_providers.dart:13-15`); grepped `endSession` — only definition + one call in `_endVoiceSession`; voice screen `dispose()` (L68–75) does not call it. Recorder is native (`record` package) so offstage UI does not stop capture.

---

### [T4-F02] In-flight voice turn is not cancellable — stale result resurrects an ended/backgrounded session and plays TTS after teardown
- **Severity:** Critical
- **Confidence:** CONFIRMED (code path); LIKELY for audible background playback (depends on OS/audio-focus behavior)
- **Location:** `lib/features/ai_tutor/domain/voice/voice_conversation_service.dart:394-454` (submit), `:456-469` (interrupt), `:483-494` (endSession), `:496-512` (`_onLifecycleAbort`)
- **Evidence:**
```dart
// submitSpeechInput (394-446): no CancelToken is passed even though the repository supports one
      final tutorResponse = await repository.sendMessage(
        sessionId: sessionId,
        userText: userText.trim(),
        learnerHskLevel: _learnerHskLevel,
        persona: _activePersona,
        scenario: _activeScenario,
      );
      ...
      _setStatus(VoiceConversationStatus.speaking);
      ...
      } else if (tts != null) {
        await tts!.speak(...);
      }
      ...
      _setStatus(VoiceConversationStatus.listening);
      await recorder.resumeRecording();
```
```dart
// interrupt (456-468) — does nothing while the AI request is in flight (status == processing)
  Future<void> interrupt() async {
    if (_status == VoiceConversationStatus.speaking ||
        player.status == AudioPlaybackStatus.playing) {
      ...
    }
  }
```
```dart
// endSession (483-494) — stops mic/audio, but the pending future above is untouched
  Future<void> endSession() async {
    await stopPersonaVoicePreview();
    await player.stop();
    ...
    await recorder.stopRecording();
    ...
    _setStatus(VoiceConversationStatus.ended);
  }
```
- **Root cause:** `submitSpeechInput` has no session-generation token, no `CancelToken`, and no post-await check of `_status`/`_activeSessionId`. `interrupt()` cannot cancel a `processing` turn. `endSession()`/`_onLifecycleAbort()` only stop the current hardware/audio — the awaited repository future continues and then unconditionally: appends an assistant transcript, sets `speaking`, plays the persona sample/TTS/pause, sets `listening`, and calls `recorder.resumeRecording()`. (`resumeRecording()` is only a no-op because `endSession` moved the recorder status to `stopped` — correctness depends on that incidental state, not on intent.)
- **Impact:** (a) after pressing “Kết thúc đàm thoại” while the AI is answering, the reply is still spoken aloud and the UI flips back to “Đang lắng nghe…” with an end-call button, while the recorder is actually stopped — the user talks and nothing is captured; (b) if the app was backgrounded mid-request, `_onLifecycleAbort` sets `interrupted`, then the stale continuation plays TTS in the background and flips the state machine; (c) the in-flight HTTP request consumes tokens/network with no way to stop it. This directly contradicts the privacy intent of `P1_06` §5.
- **Fix:** introduce a monotonically increasing session/turn generation and a `CancelToken`:
```dart
int _turnGeneration = 0;
CancelToken? _turnCancelToken;
...
final generation = ++_turnGeneration;
_turnCancelToken = CancelToken();
...
final tutorResponse = await repository.sendMessage(
  ...,
  cancelToken: _turnCancelToken,
);
if (generation != _turnGeneration || _status == VoiceConversationStatus.ended) return;
...
// endSession / interrupt / _onLifecycleAbort:
_turnGeneration++;
_turnCancelToken?.cancel('session ended');
_turnCancelToken = null;
```
and in `interrupt()` also cancel when `_status == processing`.
- **Verification status:** read both service and repository (`sendMessage` accepts `CancelToken? cancelToken`, `lib/features/ai_tutor/data/repositories/ai_tutor_repository.dart:39-48`); the voice path never passes it. Traced every status transition after the `await`.

---

### [T4-F03] Voice-session startup has no abort checkpoint — backgrounding during `connecting`/greeting still starts the microphone
- **Severity:** High
- **Confidence:** CONFIRMED (code path); RISK on real-device behavior (Android may withhold mic in background)
- **Location:** `lib/features/ai_tutor/domain/voice/voice_conversation_service.dart:334-391` (`startSession`), `:496-512` (`_onLifecycleAbort`)
- **Evidence:**
```dart
// startSession (349-390)
    _setStatus(VoiceConversationStatus.requestingPermission);
    final hasPerm = await recorder.checkPermission();
    ...
    _setStatus(VoiceConversationStatus.connecting);
    await Future.delayed(const Duration(milliseconds: 300));
    ...
    _setStatus(VoiceConversationStatus.speaking);
    ...
    } else if (tts != null && persona.voiceConfig.sourceType == PersonaVoiceSourceType.ttsSynthesis) {
      try {
        await tts!.speak(...);
      } catch (_) {}
    }

    await recorder.startRecording();
    _setStatus(VoiceConversationStatus.listening);
```
```dart
// _onLifecycleAbort (496-512) — connecting / requestingPermission are not handled at all
  void _onLifecycleAbort(String reason) {
    debugPrint('[VoiceConversationService] Lifecycle abort triggered: $reason');
    stopPersonaVoicePreview();
    if (_status == VoiceConversationStatus.listening ||
        _status == VoiceConversationStatus.speaking ||
        _status == VoiceConversationStatus.processing) {
      ...
      _setStatus(VoiceConversationStatus.interrupted);
    }
  }
```
- **Root cause:** `startSession` has no `_isStarting` guard, no abort flag, and no re-check of lifecycle state after each `await`. If the app is backgrounded while the status is `requestingPermission` or `connecting`, `_onLifecycleAbort` intentionally does nothing; if backgrounded during greeting playback (`speaking`), the abort stops the player/recorder but the continuation then executes `await recorder.startRecording()` and forces `listening`.
- **Impact:** mic activation while the app is not in the foreground (privacy-indicator and battery), or a thrown hardware exception from `record` that is never caught inside `startSession` (screen handler is an unawaited `onPressed`), leaving the UI in a dead `interrupted` state. The permission dialog itself also produces `inactive` lifecycle events, so an abort path here is not hypothetical.
- **Fix:** add an abort-aware guard at each step:
```dart
bool _aborted = false; // set by _onLifecycleAbort() and endSession()
...
await Future.delayed(const Duration(milliseconds: 300));
if (_aborted) return;
...
if (_aborted) return;
await recorder.startRecording();
if (_aborted) { await recorder.cancelRecording(); return; }
```
and treat `requestingPermission`/`connecting` as abortable in `_onLifecycleAbort` (set `_aborted`, set status `interrupted`).
- **Verification status:** line-by-line read of `startSession` + `_onLifecycleAbort`; confirmed no `_aborted`/generation flag exists anywhere in the service.

---

### [T4-F04] Mic-test dialog is barrier-dismissible — dismissing it leaves the microphone recording forever
- **Severity:** High
- **Confidence:** CONFIRMED
- **Location:** `lib/features/ai_tutor/presentation/screens/ai_tutor_voice_chat_screen.dart:138-225` (dialog), `:186-205` (start/stop buttons), `:68-75` (dispose)
- **Evidence:**
```dart
  void _showMicTestDialog() {
    final service = ref.read(voiceConversationServiceProvider);
    showDialog(               // no barrierDismissible: false
      context: context,
      builder: (ctx) => StatefulBuilder(
...
              if (!_isMicTesting)
                HiButton(
                  ...
                  onPressed: () async {
                    setDialogState(() => _isMicTesting = true);
                    await service.startMicTest();
                  },
                )
              else
                HiButton(
                  text: 'Dừng đo',
                  ...
                  onPressed: () async {
                    setDialogState(() => _isMicTesting = false);
                    await service.stopMicTest();
                  },
                ),
```
```dart
  Future<void> startMicTest() async {
    final granted = await checkPermission();
    ...
    await recorder.startRecording();
  }
```
- **Root cause:** `showDialog` defaults to `barrierDismissible: true`. Tapping the scrim (or Android back) pops the dialog without executing `stopMicTest()`; the only stop paths are the “Dừng đo” and “Đóng” buttons. `_isMicTesting` (a field of the screen, mutated inside the dialog `StatefulBuilder`) also stays `true`.
- **Impact:** when `startMicTest()` had called `recorder.startRecording()`, dismissing the dialog leaves native recording active with no visible control (outside the closed dialog) → mic stays hot until the screen/service is disposed, which for the AI Tutor tab is effectively never (F01). Later `startSession()` calls `recorder.startRecording()` on an already-recording `record` instance, producing undefined behavior/`PlatformException`, which `startSession` rethrows as an unhandled async error.
- **Fix:** make it non-dismissible and always release on every exit path, e.g.:
```dart
showDialog(
  barrierDismissible: false,
  context: context,
  builder: (ctx) => PopScope(
    canPop: !_isMicTesting,
    child: ...,
  ),
).whenComplete(() async {
  if (_isMicTesting) {
    _isMicTesting = false;
    await ref.read(voiceConversationServiceProvider).stopMicTest();
  }
});
```
Also reset `_isMicTesting = false` in the screen's `dispose()` and call `stopMicTest()` there.
- **Verification status:** traced `startMicTest`/`stopMicTest` call sites (grep: only lines 193/203/212); `showDialog` call has no `barrierDismissible`; screen `dispose()` (L68–75) cancels subs/controllers but does not stop the mic test.

---

### [T4-F05] No playback interruption / audio-focus handling — backgrounding or a phone call does not pause AI voice or TTS
- **Severity:** High
- **Confidence:** CONFIRMED for missing app-level handling; LIKELY for user-visible overlap
- **Location:** `lib/core/audio/audio_player_service.dart` (no lifecycle hook anywhere in the class), `lib/core/utils/app_lifecycle_manager.dart:47-68`, `pubspec.yaml:46-49`
- **Evidence:**
```dart
// app_lifecycle_manager.dart:51-67 — the only lifecycle reaction is "stop audio *sessions*"
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // App backgrounded, incoming phone call, or screen locked:
        // 1. Force-stop all recording sessions immediately to protect user privacy.
        _stopAllActiveAudioSessions('App backgrounded or focus lost ($state)');
        ...
      case AppLifecycleState.resumed:
        // App regained foreground. Microphone remains released until explicit user action.
        break;
```
Grep of `registerAudioSession(` shows exactly two registrants: `audio_recorder_service.dart:75` and `voice_conversation_service.dart:120`. There is **no** audio-focus/interruption handling in `lib/`: grep for `audio_session|AudioSession|AudioFocus|setAudioContext|handleInterruptions` matches only app-defined *names* (`AudioSessionStopCallback` in `app_lifecycle_manager.dart`, the unused `AudioSessionInterruptionReason` enum in `audio_models.dart:28-34`) — no `audio_session` import, no `AudioSession.instance` call anywhere in `lib/` — and `DefaultAudioPlayerService` never observes lifecycle:
```dart
class DefaultAudioPlayerService implements AudioPlayerService {
  final ja.AudioPlayer _player;
  ...
  // resume(), pause(), ... — no lifecycle/interruption awareness
```
(`audio_session` is only present as a transitive package in `pubspec.lock:28-34`, never configured by app code.)
- **Root cause:** Lifecycle handling was implemented only for recording (“audio sessions” callbacks are only mic-safety). Playback (just_audio/ExoPlayer and FlutterTts) is not paused on `paused`/`inactive`, and no app-level audio-focus/interruption listener exists.
- **Impact:** incoming call, screen lock, notification shade or another media app does not pause AI voice/TTS/audio playback; playback may continue in the background or fight for focus with the call/music (device-dependent). `docs/bug-fixes/P1_06_REAL_AUDIO_SYSTEM.md` §1 item 3 states “Backgrounding the app or receiving incoming phone calls did not interrupt audio recording or playback” as a fixed defect — for playback the code shows the defect still exists.
- **Fix:** configure an audio session once at startup and subscribe to interruptions, then fan out to registered players:
```dart
// main.dart (async init) or AppLifecycleManager.initialize
final session = await AudioSession.instance;
await session.configure(const AudioSessionConfiguration.speech());
session.interruptionEventStream.listen((event) {
  if (event.begin) unawaited(UnifiedAudioPlaybackService.instance.pause());
});
unawaited(session.setActive(true)); // when playback starts
```
and extend `AudioSessionStopCallback` usage so `DefaultAudioPlayerService` (or `UnifiedAudioPlaybackService`) pauses/stops on `AppLifecycleState.paused`/`inactive` (phone-call detection on Android via `audio_session`).
- **Verification status:** repo-wide grep for audio-focus APIs (zero in `lib/`); read `AppLifecycleManager` entirely; read `DefaultAudioPlayerService` entirely (no lifecycle observer); read `pubspec.yaml` deps.

---

### [T4-F06] `DefaultAudioRecorderService` never unregisters its `AppLifecycleManager` callback — per-screen recorder instances accumulate forever
- **Severity:** High
- **Confidence:** CONFIRMED
- **Location:** `lib/core/audio/audio_recorder_service.dart:70-76` (register), `:300-310` (dispose); consumers `lib/features/shadowing/presentation/screens/shadowing_screen.dart:44-45`, `lib/features/pronunciation/presentation/screens/pronunciation_lab_screen.dart:43-44`, `lib/features/sentences/presentation/screens/sentence_shadowing_screen.dart:42-44`
- **Evidence:**
```dart
  DefaultAudioRecorderService({
    this.hasMicrophone = true,
    rec.AudioRecorder? recorder,
  })  : _recorder = recorder ?? rec.AudioRecorder(),
        _ownsRecorder = recorder == null {
    AppLifecycleManager.instance.registerAudioSession(_onLifecycleStop);
  }
...
  @override
  void dispose() {
    _durationTimer?.cancel();
    _amplitudeSub?.cancel();
    if (_ownsRecorder) {
      _recorder.dispose();
    }
    _statusController.close();
    _amplitudeController.close();
    _durationController.close();
  }
```
```dart
// app_lifecycle_manager.dart:37-45
  void registerAudioSession(AudioSessionStopCallback onMustStop) {
    if (!_audioStopCallbacks.contains(onMustStop)) {
      _audioStopCallbacks.add(onMustStop);
    }
  }

  void unregisterAudioSession(AudioSessionStopCallback onMustStop) {
    _audioStopCallbacks.remove(onMustStop);
  }
```
- **Root cause:** The ownership contract is inverted: the recorder registers itself with the global `AppLifecycleManager` in its constructor, but its `dispose()` never unregisters. `AppLifecycleManager` keeps a strong reference to `_onLifecycleStop`, which keeps the disposed recorder (and its closed `StreamController`s / native recorder) reachable. Screen-level consumers instantiate a **new** recorder on every screen visit, so the callback list grows without bound: `shadowing_screen.dart:45`, `pronunciation_lab_screen.dart:44`, `sentence_shadowing_screen.dart:43`, plus every `ProviderContainer` creation in tests.
- **Impact:** unbounded memory growth (one dead service + controllers per screen visit) and, on every app background/focus-loss, `_stopAllActiveAudioSessions` calls `cancelRecording()` on already-disposed recorders (`record` plugin calls throw and are silently swallowed by the manager's `try/catch`). Also `AppLifecycleManager.dispose()` is never invoked in `main.dart`, so the list is only cleared at process death. Related ordering defect in the same file: `_onLifecycleStop` (`:105-110`) calls `cancelRecording()` without awaiting and then sets `error`; when `cancelRecording` completes it overwrites the status with `idle` (`:297`), so the UI never sees the error state.
- **Fix:**
```dart
  @override
  void dispose() {
    AppLifecycleManager.instance.unregisterAudioSession(_onLifecycleStop);
    _durationTimer?.cancel();
    _amplitudeSub?.cancel();
    ...
  }
```
and make `_onLifecycleStop` async-safe: `Future<void> _onLifecycleStop(String reason) async { ... await cancelRecording(); ... }` (callback typedef already returns `void`, so wrap with `unawaited`). Also consider `unawaited(_recorder.dispose())` with error handling.
- **Verification status:** grepped every `DefaultAudioRecorderService(` instantiation (5 call sites) and every `unregisterAudioSession` call (only `main.dart:96` skeleton screen and `voice_conversation_service.dart:525`) — the recorder never unregisters. Read `AppLifecycleManager` fully to confirm strong references.

---

### [T4-F07] `startSession()` double-tap race: call button remains enabled during `requestingPermission`, creating two sessions and two recordings
- **Severity:** High
- **Confidence:** CONFIRMED (missing guard / reachable state); LIKELY for the hardware exception outcome
- **Location:** `lib/features/ai_tutor/presentation/screens/ai_tutor_voice_chat_screen.dart:89-111` (start handler), `:666-671` (isSessionActive), `:694-704` (button); service `voice_conversation_service.dart:333-391`
- **Evidence:**
```dart
  Future<void> _startVoiceSession() async {
    final service = ref.read(voiceConversationServiceProvider);
    final persona = ref.read(activePersonaProvider);
    final scenario = ref.read(activeScenarioProvider);

    var sessionId = ref.read(currentChatSessionIdProvider);
    if (sessionId == null) {
      final repo = ref.read(aiTutorRepositoryProvider);
      final title = 'Hội thoại thoại: ${scenario.titleVi}';
      sessionId = await repo.createSession(...);   // async gap #1
      ref.read(currentChatSessionIdProvider.notifier).selectSession(sessionId);
    }

    await service.startSession(...);                // async gap #2
  }
```
```dart
// isSessionActive (666-671) — requestingPermission is NOT included
    final isSessionActive = _currentStatus == VoiceConversationStatus.listening ||
        _currentStatus == VoiceConversationStatus.speaking ||
        _currentStatus == VoiceConversationStatus.processing ||
        _currentStatus == VoiceConversationStatus.connecting ||
        _currentStatus == VoiceConversationStatus.interrupted;
```
```dart
// service.startSession — no re-entrancy guard
  Future<void> startSession({...}) async {
    await stopPersonaVoicePreview();
    _activeSessionId = sessionId;
```
- **Root cause:** the start button is an unguarded `onPressed: _startVoiceSession`; the status is only changed *inside* `startSession` after an awaited `stopPersonaVoicePreview()` (and after `createSession` on first use). While status is `requestingPermission` the button stays visible because that state is not in `isSessionActive`. Two overlapping `startSession` invocations then both add the greeting transcript, both call `player.play(...)` (concurrent `setAudioSource` on the same `just_audio` player → `PlayerInterruptedException`/`PlatformException` possible) and both call `recorder.startRecording()`. Errors from the second call propagate out of an unawaited `onPressed` future as unhandled async errors.
- **Impact:** duplicated chat sessions in SQLite (double network turns and duplicate greeting rows), double audio playback, recorder start failures, state machine corruption; user sees two greetings/cut-off speech.
- **Fix:** guard at the top of `_startVoiceSession` and inside the service:
```dart
bool _isStarting = false;
Future<void> _startVoiceSession() async {
  if (_isStarting) return;
  _isStarting = true;
  try { ... } finally { _isStarting = false; }
}
```
plus include `requestingPermission` in `isSessionActive` (or disable the button while a start future is pending), and add `if (_status == connecting || _status == listening || _status == speaking) return;` in `startSession`.
- **Verification status:** read the full screen/service paths; grepped `_isStarting`-style guards (none). Confirmed `isSessionActive` state list and that `requestingPermission` only exists transiently inside `startSession`.

---

### [T4-F08] All five tabs and the full AI-Tutor audio stack are instantiated eagerly when the shell mounts (startup burst)
- **Severity:** Medium
- **Confidence:** CONFIRMED (eager instantiation); LIKELY for measurable startup cost
- **Location:** `lib/features/app_shell/presentation/screens/app_shell.dart:104-113`; `lib/features/ai_tutor/presentation/screens/ai_tutor_tab_screen.dart:269-275`; `ai_tutor_voice_chat_screen.dart:32-58`; `ai_tutor_providers.dart:43-79`
- **Evidence:**
```dart
// voice screen initState — runs as soon as the AI Tutor tab is mounted
    final service = ref.read(voiceConversationServiceProvider);
    _currentStatus = service.status;
    _transcripts = service.transcripts;
```
```dart
// providers: each creates a native-backed service
final aiTutorAudioRecorderProvider = Provider<AudioRecorderService>((ref) {
  final recorder = DefaultAudioRecorderService();
  ref.onDispose(() => recorder.dispose());
  return recorder;
});
final aiTutorAudioPlayerProvider = Provider<AudioPlayerService>((ref) {
  final player = DefaultAudioPlayerService();   // just_audio player (ExoPlayer on Android)
  ref.onDispose(() => player.dispose());
  return player;
});
```
```dart
// review_screen.dart:24-32 — another tab's initState runs at the same moment
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lifecycleListener = AppLifecycleListener(
      onResume: () {
        ref.read(srsDueCountProvider.notifier).refreshCount();
      },
    );
  }
```
- **Root cause:** `IndexedStack` builds/mounts every child immediately, and the AI Tutor tab itself uses an `IndexedStack`, so `AiTutorVoiceChatScreen.initState` runs at shell mount and synchronously reads `voiceConversationServiceProvider` → creates `DefaultAudioRecorderService` (native recorder), `DefaultAudioPlayerService` (`just_audio.AudioPlayer`; platform player is initialized in its constructor) and `DefaultTtsService` even if the user only ever uses text chat. At the same frame Home/Learning/Review/Profile all start their DB-backed providers, and the text chat screen fires `_ensureActiveSession()` in a post-frame callback (DB query + possible `createSession` insert).
- **Impact:** the first interactive frame after the splash pays for: ExoPlayer/native player creation, recorder object + lifecycle registration, TTS engine init, plus a thundering herd of 5 tab screens' DB loads at once → visible jank right when the UI appears and extra startup memory/time on low-end Android. Resources remain alive for the entire process (providers are non-autoDispose).
- **Fix:** make tab content lazy (`IndexedStack` + `Offstage` is not lazy enough) — e.g. build lazily with `PageStorage`/`ValueKey` and instantiate the voice service only when the voice mode is selected:
```dart
// AiTutorTabScreen: only mount the voice screen once the mode was opened
body: mode == AiTutorMode.text
    ? const AiTutorTextChatScreen()
    : const AiTutorVoiceChatScreen(),
```
(keep-alive text chat if desired via `AutomaticKeepAlive`), and defer `_ensureActiveSession` to the first visible frame after startup. Alternatively drop the outer `IndexedStack` for a lazy `IndexedStack`-like implementation that only instantiates a tab when first selected.
- **Verification status:** read `AppShell.build` gating (`isInitializing` branch returns early; the tab tree is built right after `isReady`), inner `IndexedStack` children, and both `initState` methods. `DefaultAudioPlayerService` constructor subscribes to `_player.playerStateStream`, proving the player object is active at construction.

---

### [T4-F09] Recorder emits every amplitude sample twice per 100 ms (timer poll + native stream) and re-enters the async timer callback
- **Severity:** Medium
- **Confidence:** CONFIRMED
- **Location:** `lib/core/audio/audio_recorder_service.dart:171-188` (timer), `:190-203` (native stream)
- **Evidence:**
```dart
      _durationTimer?.cancel();
      _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
        if (_status != AudioRecordingStatus.recording) return;
        final elapsed = DateTime.now().difference(_recordingStartTime!) + _accumulatedDuration;
        ...
        try {
          final amp = await _recorder.getAmplitude();      // extra platform round-trip every 100 ms
          final normalized = ((amp.current + 60.0) / 60.0).clamp(0.05, 1.0);
          if (!_amplitudeController.isClosed) {
            _amplitudeController.add(normalized);
          }
        } catch (_) {}
      });

      // Stream hardware amplitude
      _amplitudeSub?.cancel();
      _amplitudeSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        ...
          if (!_amplitudeController.isClosed) {
            _amplitudeController.add(normalized);
          }
      }, onError: ...);
```
- **Root cause:** two independent amplitude producers feed the same `_amplitudeController`: a manual 100 ms `Timer.periodic` poll of `getAmplitude()` and the plugin's own `onAmplitudeChanged(100 ms)` stream. Both clamp/normalize and `add` to the same broadcast stream. The timer callback is `async` inside `Timer.periodic`, so a slow `getAmplitude()` platform call does not delay the next tick — callbacks can overlap and pile up behind the platform channel.
- **Impact:** ~2× the waveform events/second (each triggering `VoiceConversationService._recorderAmpSub` → amplitude controller → `StreamBuilder` → `WaveformVisualizer` rebuild), 2× platform-channel traffic and battery cost while recording, and avoidable jank during long recording sessions; also contradicts `P1_06` §3.2 ("polled at 60 ms intervals"). The plugin stream alone is sufficient.
- **Fix:** remove one producer (keep `onAmplitudeChanged` and drop the manual poll), and set a re-entrancy guard if polling must stay:
```dart
bool _polling = false;
_durationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
  ...
  if (_polling) return;
  _polling = true;
  try { ... await _recorder.getAmplitude(); ... } finally { _polling = false; }
});
```
- **Verification status:** read both producers; both add to `_amplitudeController`; no dedup/throttle exists. `resumeRecording()` (`:241-256`) duplicates the same double-producer pattern.

---

### [T4-F10] Text chat streaming rebuilds the whole screen and starts a new scroll animation for every token, even when the tab is hidden
- **Severity:** Medium
- **Confidence:** CONFIRMED
- **Location:** `lib/features/ai_tutor/presentation/screens/ai_tutor_text_chat_screen.dart:147-171` (stream listener), `:92-102` (`_scrollToBottom`), `:134-145` (onComplete), `app_shell.dart:104-113` (hidden tabs still mounted)
- **Evidence:**
```dart
      _streamSub = stream.listen(
        (chunk) {
          if (mounted) {
            setState(() {
              _streamBuffer += chunk;
            });
            _scrollToBottom();
          }
        },
```
```dart
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }
```
- **Root cause:** each SSE chunk (per token/word) calls `setState`, rebuilding the whole `Scaffold` subtree including the `ListView` of the entire session, the input bar, suggestion chips and app bar; then it schedules a post-frame callback that starts a **new 250 ms** `animateTo`. Chunks arrive faster than 250 ms, so the previous scroll animation is constantly interrupted/restarted. Because the AI Tutor tab is inside the permanently-mounted `IndexedStack`, this continues (and animates) even when a different bottom tab is selected.
- **Impact:** high CPU/jank during every AI answer (worst on long answers/history), battery drain, and unnecessary work while the tab is invisible. Long answers make the effect worse because the `ListView` and message list are rebuilt per token.
- **Fix:** throttle buffer flushes and only auto-scroll when near the bottom:
```dart
Timer? _flushTimer;
void _onChunk(String chunk) {
  _pendingBuffer.write(chunk);
  _flushTimer ??= Timer(const Duration(milliseconds: 50), () {
    _flushTimer = null;
    if (!mounted) return;
    setState(() { _streamBuffer += _pendingBuffer.toString(); _pendingBuffer.clear(); });
    if (_scrollController.hasClients &&
        _scrollController.offset >= _scrollController.position.maxScrollExtent - 120) {
      _scrollToBottom();
    }
  });
}
```
Use a `ValueListenableBuilder`/isolated streaming bubble widget so the rest of the tree (input bar, chips, app bar) is not rebuilt.
- **Verification status:** read the full stream pipeline from screen → repository → provider; confirmed one `setState` + one `animateTo` per chunk and no throttling anywhere.

---

### [T4-F11] Chat history is unbounded, and every turn re-reads/maps the entire session history (no LIMIT) while session providers are cached forever
- **Severity:** Medium
- **Confidence:** CONFIRMED
- **Location:** `lib/core/database/dao/chat_dao.dart:46-53` (no LIMIT), `lib/features/ai_tutor/data/repositories/ai_tutor_repository.dart:306-310` (full fetch per turn), `lib/features/ai_tutor/presentation/providers/ai_tutor_providers.dart:139-143` (non-autoDispose family), screen `:510` (`ref.watch(sessionMessagesProvider(sessionId))`)
- **Evidence:**
```dart
// chat_dao.dart:46-53
  Future<List<Map<String, dynamic>>> getMessagesBySessionId(String sessionId) async {
    return await _db.query(
      DatabaseConstants.tableChatMessages,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'created_at ASC',
    );
  }
```
```dart
// repository (streaming path): full history fetched, only the last 10 are used by the context builder
          final rawHistory = await chatDao.getMessagesBySessionId(sessionId);
          final historyExcludingLast =
              rawHistory.isNotEmpty && rawHistory.last['id'] == userMessageId
                  ? rawHistory.sublist(0, rawHistory.length - 1)
                  : rawHistory;
```
```dart
// providers: cached for the app lifetime, one entry per session ever opened
final sessionMessagesProvider =
    FutureProvider.family<List<TutorChatTurn>, String>((ref, sessionId) async {
  final repository = ref.watch(aiTutorRepositoryProvider);
  return repository.getSessionTurns(sessionId);
});
```
- **Root cause:** `TutorContextBuilder` already applies a 10-message sliding window, but the repository fetches **all** messages first (twice per turn: once for the prompt, and once more after `ref.invalidate(sessionMessagesProvider)` at `text_chat_screen.dart:141`, which calls `getSessionTurns` → another full fetch + `fromMap` mapping on the UI isolate). Nothing ever prunes `chat_messages`; `ChatDao.deleteSession` only sets `deleted_at` (`chat_dao.dart:69-81`), leaving messages forever. The `FutureProvider.family` cache retains the mapped `TutorChatTurn` list of every session opened during the process.
- **Impact:** O(history) DB read + JSON/map deserialization on the UI isolate per turn, per invalidate; memory grows with total chat history (DB itself grows without bound across sessions). Long-running conversations become progressively slower and jankier; the app's memory footprint never shrinks (no autoDispose).
- **Fix:** (1) add a bounded query for context and a paginated query for UI:
```dart
Future<List<Map<String, dynamic>>> getLastMessages(String sessionId, {int limit = 20}) => _db.query(
  tableChatMessages,
  where: 'session_id = ?', whereArgs: [sessionId],
  orderBy: 'created_at DESC', limit: limit,
);
```
(2) append the new turn incrementally in the UI instead of invalidating the whole provider; (3) make `sessionMessagesProvider` `autoDispose.family` (or evict on session switch), and add retention/pruning (e.g. keep last N turns per session or delete `deleted_at` sessions' messages).
- **Verification status:** read DAO, both repository paths, provider definitions, screen invalidation points; confirmed absence of LIMIT and of any DELETE for messages; confirmed `autoDispose` not used.

---

### [T4-F12] Voice transcript list grows without bound and is copied in full on every update (O(n²) over a session)
- **Severity:** Medium
- **Confidence:** CONFIRMED
- **Location:** `lib/features/ai_tutor/domain/voice/voice_conversation_service.dart:69` (`_transcripts`), `:167-190` (`_addTranscript` / `_updateLastInterimTranscript`), `:347` (clear only at `startSession`)
- **Evidence:**
```dart
  final List<VoiceTranscriptSegment> _transcripts = [];
...
  void _addTranscript(VoiceTranscriptSegment segment) {
    _transcripts.add(segment);
    if (!_transcriptController.isClosed) {
      _transcriptController.add(List.unmodifiable(_transcripts));
    }
  }
...
    if (!_transcriptController.isClosed) {
      _transcriptController.add(List.unmodifiable(_transcripts));
    }
```
- **Root cause:** every turn/interim update appends to a single growable list and broadcasts `List.unmodifiable(_transcripts)` — a full copy of all segments accumulated since the session started. The list is only cleared in `startSession()`. The screen then replaces its `_transcripts` field and rebuilds the whole `ListView` (`ai_tutor_voice_chat_screen.dart:50-57`).
- **Impact:** per-event cost grows linearly with session length, per-turn total cost grows quadratically; a long voice session (hundreds of turns) creates large temporary lists and increasingly expensive UI rebuilds, plus the singleton keeps everything in memory for the app lifetime (only the last session is cleared, previous ones are dropped at next `startSession` but the list's capacity stays large).
- **Fix:** keep only what the UI needs (e.g. cap at last 50 segments / windowed list) and emit deltas rather than full snapshots:
```dart
static const int _maxTranscripts = 100;
void _addTranscript(VoiceTranscriptSegment s) {
  _transcripts.add(s);
  if (_transcripts.length > _maxTranscripts) _transcripts.removeAt(0);
  if (!_transcriptController.isClosed) _transcriptController.add(s); // delta
}
```
(adjust the screen's `StreamBuilder`/listener to append instead of replace), or use a `ValueNotifier<List<...>>` with the same cap.
- **Verification status:** read the full service; confirmed full-list copies on every `_addTranscript`/`_updateLastInterimTranscript` and single clear site.

---

### [T4-F13] `AudioCoverageAuditor` performs an N+1 of `File.exists()` syscalls (thousands) on the UI isolate
- **Severity:** Medium
- **Confidence:** CONFIRMED
- **Location:** `lib/features/audio_management/data/audio_coverage_auditor.dart:24-35` (level 0), `:66-84` (HSK 1–6)
- **Evidence:**
```dart
      final assets = await _db.query(
        DatabaseConstants.tableAudioAssets,
        where: 'hsk_level = ? AND status = ?',
        whereArgs: [lvl, 'ready'],
      );

      int verified = 0;
      ...
      for (final a in assets) {
        ...
        final path = a['local_path'] as String?;
        if (path != null && await File(path).exists()) {
          verified++;
        }
      }
```
- **Root cause:** for each of the 7 levels, all `ready` assets are loaded and then a separate awaited `File.exists()` stat is issued per asset. With a fully installed HSK 6 pack (the catalog advertises 2 600 files) this is thousands of sequential `await`s per audit, each a platform-channel hop, all sequenced on the UI isolate. No batching and no caching of the existence result.
- **Impact:** opening the Audio Pack Manager (it watches `audioCoverageReportProvider`, `audio_pack_manager_screen.dart:13,46`) performs seconds of async file IO; the provider result is cached but any `ref.invalidate` (e.g. `deletePack`/`refresh`) repeats it. Contends with video/frame scheduling and can ANR on low-end devices with a large installed pack.
- **Fix:** (a) trust `audio_assets.status = 'ready'` (already maintained by the downloader) or (b) batch the existence checks off the UI isolate:
```dart
final paths = assets.map((a) => a['local_path'] as String?).whereType<String>().toList();
final verified = await Isolate.run(() => paths.where((p) => File(p).existsSync()).length);
```
Do it once inside `auditCoverage` (not per level), or move the whole audit into a background isolate and return the report model.
- **Verification status:** read the entire auditor; confirmed 7 queries + per-row await; read the screen/provider that trigger it.

---

### [T4-F14] Content-pack import is an N+1 write pattern with per-item JSON decoding on the UI isolate
- **Severity:** Medium
- **Confidence:** CONFIRMED
- **Location:** `lib/features/content_packs/data/content_pack_manager.dart:385-426` (per content item), `:428-481` (per-word SELECT+INSERT/UPDATE), `:30-50` (`_safeUpsert` SELECT-then-write)
- **Evidence:**
```dart
        for (final item in contentItemsList) {
          ...
          // Parse and normalize into core relational tables & knowledge_registry
          Map<String, dynamic> parsedContent = {};
          try {
            parsedContent = item['content_json'] is Map<String, dynamic>
                ? item['content_json'] as Map<String, dynamic>
                : json.decode(rawContentJson) as Map<String, dynamic>;   // main-isolate decode per item
          } catch (_) {}
          ...
            for (final w in words) {
              ...
              final existingVocab = await txn.query(
                DatabaseConstants.tableVocabularies,
                columns: ['id'],
                where: 'id = ?',
                whereArgs: [vocabId],
                limit: 1,
              );
              if (existingVocab.isNotEmpty) {
                await txn.update(...);
              } else {
                await txn.insert(...);
              }

              // 2. Insert/update sense
              final existingSense = await txn.query(
                DatabaseConstants.tableVocabularySenses,
```
- **Root cause:** inside a single transaction the importer performs nested loops (`units → lessons → segments → content items → words → senses/examples → knowledge_registry → lesson_knowledge_items`); each entity goes through `_safeUpsert` = one `SELECT` + one `UPDATE`/`INSERT` awaited sequentially. On top of that, `content_json` is decoded per content item on the main isolate (`json.decode(rawContentJson)`), while only the *top-level* pack body was decoded in an isolate (`:156-158`). The mandatory startup packs (`app_startup_provider.dart:140-162`) run this on first install, twice, sequentially.
- **Impact:** first-launch (and retry) startup spends most of its time in thousands of sequential platform-channel DB round trips and per-item JSON parses; progress UI updates only between phases. Contributes directly to slow first-run startup. (Related remaining N+1s in scope: `audio_pack_providers.dart:118-125` issues 7 sequential COUNT queries; `learner_context_service.dart` runs 5 queries per turn.)
- **Fix:** bulk-load existing ids once (`SELECT id FROM ... WHERE id IN (...)`), pre-decode/transform all `content_json` in the same `Isolate.run` used for the pack body, then write with `txn.batch()` and `commit(noResult: true)` instead of per-row awaits; consider `INSERT ... ON CONFLICT(id) DO UPDATE` (already used in `seed_loader.dart:186-197`) to remove the SELECT+UPDATE pattern entirely.
- **Verification status:** read the import loops and `_safeUpsert`; read `app_startup_provider.dart` steps 6–7; confirmed the pack install is invoked on startup for both mandatory packs.

---

### [T4-F15] `AppStartupNotifier.initialize()` has no in-flight guard — the retry button can start concurrent seeds/imports
- **Severity:** Medium
- **Confidence:** CONFIRMED (no guard); LIKELY for corruption/lock symptoms
- **Location:** `lib/core/startup/app_startup_provider.dart:62-96`, retry call site `lib/features/app_shell/presentation/screens/app_shell.dart:45-56`
- **Evidence:**
```dart
  @override
  AppStartupState build() {
    // Automatically trigger initialization on startup
    Future.microtask(() => initialize());
    ...
  }

  Future<void> initialize({
    AssetBundle? bundle,
    Database? databaseOverride,
    AiCredentialStorage? credentialStorageOverride,
  }) async {
    state = state.copyWith(
      isInitializing: true,
      isReady: false,
      error: null,
      statusMessage: '1/10: Khởi tạo môi trường ứng dụng...',
    );
```
```dart
// app_shell.dart:45-56 — retry invokes initialize directly, unguarded
          onRetry: () {
            ref.read(appStartupProvider.notifier).initialize();
          },
```
- **Root cause:** `initialize()` unconditionally flips state back to initializing and proceeds; there is no `_isInitializing`/Completer guard and no early-return. Tapping “Thử lại kết nối” twice (or tapping during an in-flight auto-start microtask) runs the whole 10-step sequence concurrently: both calls may hit `seedLoader.seedFromAsset`/`packManager.installOrUpdatePack` for the same bundles, interleaving multi-statement transactions and duplicate phase progress updates.
- **Impact:** `database is locked` / transaction interleaving errors on slow devices, duplicated work and longer recovery, confusing status messages (`5/10` and `9/10` interleaved), potential duplicate seed history rows. Retry is exactly the state a user will hammer when startup fails.
- **Fix:**
```dart
Future<void>? _initFuture;
Future<void> initialize({...}) {
  return _initFuture ??= _runInitialization(...).whenComplete(() => _initFuture = null);
}
```
and disable the retry button while `state.isInitializing` (it currently renders only on error, but a fast double-tap can fire twice before the first `state` update is observed).
- **Verification status:** grepped all `initialize()` call sites (build microtask + retry); read the full method — no guard. (Also verified the seed JSON parsing itself *is* correctly offloaded — see claims section.)

---

### [T4-F16] `UnifiedAudioPlaybackService.playAudio` is not serialized, and its callers drop the returned `Future` (unhandled exceptions, overlapping playback)
- **Severity:** Medium
- **Confidence:** CONFIRMED
- **Location:** `lib/core/audio/unified_audio_playback_service.dart:50-80`; callers `lib/features/pinyin_foundation/presentation/screens/pinyin_practice_screen.dart:174-179`, `lib/features/pinyin_foundation/presentation/screens/pinyin_lesson_screen.dart:122-129`
- **Evidence:**
```dart
  Future<void> playAudio(
    String uri, {
    double speed = 1.0,
    bool loop = false,
    Duration? simulatedDuration,
  }) async {
    // 1. Single-player focus: Stop previous playback immediately
    if (_player.status == AudioPlaybackStatus.playing || _player.status == AudioPlaybackStatus.paused) {
      await _player.stop();
    }

    _speed = speed.clamp(0.5, 2.0);
    _currentlyPlayingUri = uri;

    // 2. Offline file verification
    if (!uri.startsWith('assets/') && !uri.startsWith('http://') && !uri.startsWith('https://')) {
      final file = File(uri);
      if (!await file.exists()) {
        _statusController.add(AudioPlaybackStatus.error);
        throw AudioPlaybackException('Tệp âm thanh ngoại tuyến không tồn tại trên thiết bị.', uri: uri);
      }
    }

    // 3. Delegate to player
    await _player.play(...);
  }
```
```dart
// caller — returned Future intentionally/accidentally dropped
                      onPressed: () {
                        UnifiedAudioPlaybackService.instance.playAudio(
                          currentEx.audioUri,
                          simulatedDuration: const Duration(milliseconds: 1600),
                        );
                      },
```
- **Root cause:** check-then-act on `_player.status` across `await`s with no mutex/queue: two rapid taps both observe a non-playing status, both call `stop()`/`play()`, and the underlying `DefaultAudioPlayerService.play` interleaves `setAudioSource` calls → likely `PlayerInterruptedException`/stale source wins. Callers `onPressed` use a block body and never await or `catchError` the future, so any `AudioPlaybackException` (missing asset/file — paths like `item.audioUri` from static pinyin data) surfaces as an unhandled asynchronous error (crash in debug/red error in release logs; no user feedback).
- **Impact:** double-tap → unhandled exception / wrong audio; missing assets produce silent failures with global error reports; “single-audio focus” not actually enforced for concurrent calls.
- **Fix:** serialize playback with a queue/mutex and make the API contract explicit:
```dart
Future<void>? _pending;
Future<void> playAudio(...) {
  return _pending = (_pending ?? Future.value()).then((_) => _playAudioInner(...));
}
```
Callers: `onPressed: () async { try { await ... } on AudioPlaybackException catch (e) { HiSnackBar.showWarning(context, e.message); } }`.
- **Verification status:** read the service; confirmed no lock/queue fields; read both call sites (fire-and-forget).

---

### [T4-F17] Recording temp files are never deleted — unbounded growth of `rec_*.m4a` in the cache directory
- **Severity:** Medium
- **Confidence:** CONFIRMED
- **Location:** `lib/core/audio/audio_recorder_service.dart:145-156` (path creation), `:263-277` (`stopRecording`), `lib/features/ai_tutor/domain/voice/voice_conversation_service.dart:483-494` (`endSession`), `:216-221` (`stopMicTest`)
- **Evidence:**
```dart
        _currentAudioPath =
            '${tempDir.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';
...
      await _recorder.start(config, path: _currentAudioPath!);
...
  Future<String?> stopRecording() async {
    _durationTimer?.cancel();
    _amplitudeSub?.cancel();
    _recordingStartTime = null;

    try {
      final path = await _recorder.stop();
      _updateStatus(AudioRecordingStatus.stopped);
      return path ?? _currentAudioPath;
```
- **Root cause:** every `startRecording()` (voice session, mic test, shadowing/pronunciation flows) creates a timestamped file in the cache dir. `cancelRecording()` deletes it (`:280-298`), but `stopRecording()` — the normal completion path — returns the path and never deletes it. No caller deletes the AI-Tutor voice recording: `endSession()` and `stopMicTest()` discard the returned path. No cache sweep exists (grep for `rec_`/recording cleanup finds only pronunciation/shadowing **user-recording** deletes via their repositories).
- **Impact:** AAC-LC mono 16 kHz at 128 kbps ≈ 16 KB/s → a 10-minute voice session leaves ~9.6 MB in the app cache; mic tests and every session add up. Android may eventually clear the cache under storage pressure, but there is no app-level bound; this is unbounded device storage growth plus wasted disk I/O. Also `stopRecording()` leaves `_currentAudioPath` pointing at the last file (stale state read by `currentAudioPath` consumers).
- **Fix:** delete the temp file after the turn/session no longer needs it:
```dart
// voice_conversation_service.endSession
final path = await recorder.stopRecording();
if (path != null) { try { await File(path).delete(); } catch (_) {} }
```
or make `DefaultAudioRecorderService.stopRecording()` accept a `keepFile` flag and delete by default; add a startup cache sweep for `rec_*.m4a` older than N days.
- **Verification status:** read recorder + all stopRecording call sites (`grep`); confirmed only `cancelRecording` deletes files and no cleanup service exists.

---

### [T4-F18] Native audio engines are created per widget/card (FlashcardCard, LessonVocabView) rather than shared
- **Severity:** Medium
- **Confidence:** CONFIRMED for creation; LIKELY for cost
- **Location:** `lib/features/vocabulary_srs/presentation/widgets/flashcard_card.dart:47-64`; `lib/features/curriculum/presentation/widgets/lesson_vocab_view.dart:41-48`; per-screen instances at `shadowing_screen.dart:44-45`, `pronunciation_lab_screen.dart:43-44`, `sentence_shadowing_screen.dart:42-44`
- **Evidence:**
```dart
// flashcard_card.dart — one just_audio player + one FlutterTts engine per card
    _ownsAudioPlayer = widget.audioPlayerOverride == null;
    _ownsTts = widget.ttsServiceOverride == null;
    _audioPlayer = widget.audioPlayerOverride ?? DefaultAudioPlayerService();
    _ttsService = widget.ttsServiceOverride ?? DefaultTtsService();
```
```dart
// lesson_vocab_view.dart — same pattern per vocabulary view
    _audioPlayer = widget.audioPlayerOverride ?? DefaultAudioPlayerService();
    _ttsService = widget.ttsServiceOverride ?? DefaultTtsService();
```
- **Root cause:** each widget eagerly constructs a full `DefaultAudioPlayerService` (which creates a `just_audio.AudioPlayer`; on Android a native ExoPlayer + 3 stream subscriptions) and a `FlutterTts` engine in `initState`, even though most cards are silent and use the shared `onPlayAudio` callback parent. SRS/lesson lists instantiate one per visible/recycled item.
- **Impact:** repeated native player/TTS engine creation and disposal while scrolling SRS/lesson content (allocation churn, main-thread `init` calls, native resource pressure); several engines can speak at once because each has its own queue (see F19). `docs/bug-fixes/F20_LEARNING_UI_AUDIO_ACCESSIBILITY.md` claims clean resource management — disposal is correct, but the per-widget creation is itself the performance problem.
- **Fix:** inject the app-level services from providers (as the `*Override` params already allow) at the list/screen level:
```dart
final audioPlayer = ref.watch(audioPlayerServiceProvider);
final tts = ref.watch(ttsServiceProvider);
...
FlashcardCard(audioPlayerOverride: audioPlayer, ttsServiceOverride: tts, ...)
```
and remove the default-construction fallback (or make it lazy: create only on first playback).
- **Verification status:** read all three widgets; confirmed eager constructors and ownership flags; grepped all call sites of the widgets (no provider injection found in-tree).

---

### [T4-F19] “Single audio focus” architecture claim is false — multiple independent players/TTS engines can play simultaneously
- **Severity:** Medium
- **Confidence:** CONFIRMED (multiple instances); LIKELY (audible overlap)
- **Location:** `lib/core/audio/unified_audio_playback_service.dart:6-8` (claim), usages vs. direct instantiations: `shadowing_screen.dart:44-45`, `flashcard_card.dart:62-63`, `lesson_vocab_view.dart:47-48`, `sentence_audio_manager.dart:26-27`, `level_exit_exam_screen.dart:66`, pinyin screens (the only `UnifiedAudioPlaybackService` users)
- **Evidence:**
```dart
/// Unified, lifecycle-safe, and singleton audio playback coordinator for HI Chinese.
/// Ensures single-audio focus across Pinyin, Vocabulary, Listening, Reading, and Shadowing.
class UnifiedAudioPlaybackService {
  static final UnifiedAudioPlaybackService instance = UnifiedAudioPlaybackService._internal();
```
```dart
// examples of modules bypassing the "coordinator"
lib/features/shadowing/presentation/screens/shadowing_screen.dart:44:    _player = DefaultAudioPlayerService();
lib/features/vocabulary_srs/presentation/widgets/flashcard_card.dart:62:    _audioPlayer = widget.audioPlayerOverride ?? DefaultAudioPlayerService();
lib/features/curriculum/presentation/widgets/lesson_vocab_view.dart:47:    _audioPlayer = widget.audioPlayerOverride ?? DefaultAudioPlayerService();
lib/features/sentences/domain/services/sentence_audio_manager.dart:26:  })  : _audioPlayer = audioPlayer ?? DefaultAudioPlayerService(),
lib/features/curriculum/presentation/screens/level_exit_exam_screen.dart:66:    _audioPlayer = widget.audioPlayer ?? DefaultAudioPlayerService();
```
- **Root cause:** the coordination singleton is only used by the two pinyin screens; every other audio surface owns its own player. TTS adds another layer: each `DefaultTtsService` wraps its own `FlutterTts` instance, and sentence/lesson/flashcard flows create their own, so Android can queue overlapping utterances from different engine instances. Nothing pauses other players when a new one starts (only same-instance `stop()` is called).
- **Impact:** e.g. AI-Tutor greeting/preview keeps playing while the user opens a vocabulary card or a pinyin exercise and starts another sound; two TTS voices can overlap; no deterministic “one thing plays” behavior, causing confusing audio and mic/playback conflicts. It also makes the “single focus” design documentation misleading.
- **Fix:** route all playback through `UnifiedAudioPlaybackService` (or an injected app-level `AudioPlayerService`/`TtsService` provider) and give TTS a single coordinator that stops the player and other TTS before speaking; add a global “audio focus” token/session (`acquireFocus(ownerId)`) that pauses the previous owner.
- **Verification status:** grepped every `AudioPlayer(`, `DefaultAudioPlayerService(`, `DefaultTtsService(`, `UnifiedAudioPlaybackService` use; read each instantiation site.

---

### [T4-F20] `startRecording()` has no re-entrancy guard — double tap starts an overlapping recording / hardware exception
- **Severity:** Low–Medium
- **Confidence:** CONFIRMED (no guard); LIKELY (exception path)
- **Location:** `lib/core/audio/audio_recorder_service.dart:124-166`
- **Evidence:**
```dart
  Future<void> startRecording({String? destinationPath}) async {
    if (!hasMicrophone) { ... }

    _updateStatus(AudioRecordingStatus.requestingPermission);

    final hasPerm = await checkPermission();
    ...
    try {
      _recordingDuration = Duration.zero;
      ...
      await _recorder.start(config, path: _currentAudioPath!);
      _recordingStartTime = DateTime.now();
      _updateStatus(AudioRecordingStatus.recording);
```
- **Root cause:** no check of the current `_status`/native recording state at entry. Callers are UI taps (`_handleToggleRecording`, mic test dialog, voice start) that can fire twice or race with each other (see F04/F07); the plugin's `start()` is then called while already started.
- **Impact:** record plugin/platform errors (“already recording”), two timers churn (old timer cancelled only after `start` returns), duplicate files written to `_currentAudioPath`/stale path, state machine stuck in error. Since callers often don't await/catch (F16/F07), it surfaces as unhandled async errors.
- **Fix:**
```dart
if (_status == AudioRecordingStatus.recording || _status == AudioRecordingStatus.requestingPermission) {
  throw const AudioRecordingHardwareException('Recording already in progress');
}
```
plus a `bool _isStarting` guard around the permission/start section.
- **Verification status:** read the full method; no status guard; traced all call sites.

---

### [T4-F21] `LearnerContextService` static cache never evicts expired sessions
- **Severity:** Low–Medium
- **Confidence:** CONFIRMED
- **Location:** `lib/features/ai_tutor/domain/context/learner_context_service.dart:36-45` (cache + invalidation), `:167-170` (insert)
- **Evidence:**
```dart
  // In-memory cache for session learner contexts to avoid redundant DB joins during multi-turn chat
  static final Map<String, ({LearnerContext context, DateTime expiresAt})> _cache = {};

  /// Clears in-memory cache for a given session or all sessions.
  static void invalidateCache([String? sessionId]) {
    if (sessionId != null) {
      _cache.remove(sessionId);
    } else {
      _cache.clear();
    }
  }
...
    _cache[sessionId] = (
      context: assembledContext,
      expiresAt: now.add(cacheTtl),
    );
```
- **Root cause:** the TTL (`cacheTtl = 30s`) is checked on read (`:72-77`), but expired entries are never removed unless that exact session is rebuilt or `invalidateCache` is called. Every new AI-Tutor session id adds an entry that stays for the rest of the process; the static map is also shared across `ProviderContainer`s (test leakage).
- **Impact:** slow unbounded memory growth proportional to the number of chat sessions used in a process (each context object holds vocab/error/evidence lists), plus cross-container state in tests. Low per-entry, but no eviction policy at all.
- **Fix:** on read, drop expired entries and cap size (LRU):
```dart
_cache.removeWhere((_, v) => !v.expiresAt.isAfter(now));
if (_cache.length > 64) _cache.remove(_cache.keys.first);
```
(prefer an LRU `LinkedHashMap`), and clear cache in `AiTutorRepository.deleteSession`/startup.
- **Verification status:** read the full service; confirmed no `removeWhere`/size cap anywhere and per-turn invalidation for the active session only (`ai_tutor_repository.dart:410`).

---

### [T4-F22] `DefaultVoiceConversationService.dispose()` disposes dependencies it does not own and fires async stops without awaiting
- **Severity:** Low
- **Confidence:** CONFIRMED
- **Location:** `lib/features/ai_tutor/domain/voice/voice_conversation_service.dart:524-539`; provider ownership `ai_tutor_providers.dart:43-79`
- **Evidence:**
```dart
  @override
  void dispose() {
    AppLifecycleManager.instance.unregisterAudioSession(_onLifecycleAbort);
    _recorderAmpSub?.cancel();
    _playerStatusSub?.cancel();
    player.stop();
    if (tts != null) {
      tts!.stop();
      tts!.dispose();
    }
    recorder.stopRecording();
    _previewStatus = PersonaVoicePreviewStatus.initial;
    if (!_statusController.isClosed) _statusController.close();
    ...
  }
```
```dart
// providers: the three services are owned and disposed by their own providers
final aiTutorTtsServiceProvider = Provider<TtsService>((ref) {
  final tts = DefaultTtsService();
  ref.onDispose(() => tts.dispose());
  return tts;
});
```
- **Root cause:** ownership is inverted for TTS: the voice service disposes the shared `tts` instance it received by injection, while the `aiTutorTtsServiceProvider` also disposes it; `player`/`recorder` are stopped but not disposed (inconsistent). All four release calls are unawaited (`player.stop()`, `tts.stop()`, `tts.dispose()`, `recorder.stopRecording()`), so `dispose()` returns before native state settles; `recorder.stopRecording()` can throw outside any `try` (unhandled async error during provider teardown).
- **Impact:** double-dispose of the TTS engine, undefined ordering when the provider graph tears down (e.g. `aiServiceProvider` invalidation recreates repo → voice service), and unhandled errors in debug logs. Not a large leak (FlutterTts has no close), but it is a real ownership violation that will bite if TTS gains a hard dispose.
- **Fix:** remove `tts!.dispose()` from the voice service (only `await tts!.stop()`), wrap async releases with `unawaited(...)` + `catchError`, and make the provider graph the single owner of recorder/player/TTS.
- **Verification status:** read service + all four providers; confirmed double ownership and unawaited calls.

---

### [T4-F23] Untracked `.listen()` subscriptions in widgets/managers — cannot be cancelled, retain dead `State` objects
- **Severity:** Low
- **Confidence:** CONFIRMED
- **Location:** `lib/features/curriculum/presentation/widgets/lesson_vocab_view.dart:50-60`; `lib/features/sentences/domain/services/sentence_audio_manager.dart:28-49`; `lib/features/sentences/presentation/screens/sentence_shadowing_screen.dart:46-58`; `sentence_reading_screen.dart:30`; `sentence_listening_screen.dart:51-55`
- **Evidence:**
```dart
// lesson_vocab_view.dart — subscription result discarded, dispose() has no cancel
    _audioPlayer.statusStream.listen((status) {
      if (mounted) {
        if (status == AudioPlaybackStatus.completed ||
            status == AudioPlaybackStatus.stopped ||
            status == AudioPlaybackStatus.error) {
          setState(() {
            _currentlyPlayingHanzi = null;
          });
        }
      }
    });
```
```dart
// sentence_audio_manager.dart — two untracked subscriptions in the constructor
    _audioPlayer.statusStream.listen((status) { ... });
    _ttsService.isSpeakingStream.listen((speaking) { ... });
```
- **Root cause:** `StreamSubscription` handles are not stored, so `dispose()` cannot cancel them. The leak becomes real whenever the underlying source outlives the consumer: `LessonVocabView` accepts `audioPlayerOverride` (lines 16-17, 44-48) — with an injected shared player the listener survives widget disposal and keeps calling `setState` on a dead `State` (guarded by `mounted`, so no crash, but the closure + State stay reachable forever). `SentenceAudioManager` leaks both subscriptions if it is disposed after/independently of the player/TTS or when overrides are injected.
- **Impact:** slow accumulation of listeners/State objects per visited lesson/sentence screen when shared services are used (tests, any future provider injection); repeated stale callbacks on every playback event (wasted work, duplicate rebuilds).
- **Fix:** store and cancel:
```dart
StreamSubscription<AudioPlaybackStatus>? _statusSub;
...
_statusSub = _audioPlayer.statusStream.listen(...);
...
@override void dispose() { _statusSub?.cancel(); ... }
```
- **Verification status:** read all five sites; confirmed no subscription fields in the classes. (Cross-module note: same pattern in T6 feature scope.)

---

### [T4-F24] Text chat: dialog controller leak, unbounded translation set, duplicate-session on double tap, `ref.read` in post-frame without mounted check
- **Severity:** Low
- **Confidence:** CONFIRMED (controller/set/ref patterns); LIKELY (duplicate session)
- **Location:** `lib/features/ai_tutor/presentation/screens/ai_tutor_text_chat_screen.dart:32` (`_expandedTranslations`), `:361-384` (`_promptRenameSession`), `:473-477` (app-bar “new session”), `:34-40` + `:51-72` (`_ensureActiveSession`)
- **Evidence:**
```dart
  // Track expanded Vietnamese translations per message ID
  final Set<String> _expandedTranslations = {};
...
  void _promptRenameSession(String sessionId, String currentTitle) {
    final controller = TextEditingController(text: currentTitle);   // never disposed
    HiDialog.show( ... );
  }
```
```dart
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureActiveSession();
    });
  }
...
  Future<void> _ensureActiveSession() async {
    try {
      final currentSessionId = ref.read(currentChatSessionIdProvider);   // no mounted check
```
```dart
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'Phiên mới',
            onPressed: _createNewSession,   // no in-flight guard
          ),
```
- **Root cause / Impact:** (a) a `TextEditingController` is created per rename dialog and never disposed (small leak, repeated dialog openings); (b) `_expandedTranslations` grows per distinct assistant message id for the process lifetime (every session opened without app restart) and is never cleared on session switch — unbounded `Set<String>`; (c) the app-bar “new session” button calls `_createNewSession` with no guard → double tap inserts two empty sessions (and two greeting rows) that the user must delete; (d) `_ensureActiveSession` can execute after the screen was disposed (`ref.read` on a dead `ConsumerState`) if the widget is torn down before the first post-frame — Riverpod throws `Cannot use ref after widget was disposed`.
- **Fix:** dispose the dialog controller (`controller.dispose()` after the dialog completes / in `onConfirm`), clear `_expandedTranslations` when `currentChatSessionIdProvider` changes (`ref.listen`), add a `_creatingSession` bool guard around `_createNewSession`, and start `_ensureActiveSession` with `if (!mounted) return;`.
- **Verification status:** read the full screen; grepped `_creatingSession`/`mounted` in this method (absent); read `HiDialog.show` signature (no controller ownership).

---

### [T4-F25] `AudioStorageManager` hashes whole files synchronously on the UI isolate; “sufficient storage” check is a stub
- **Severity:** Low
- **Confidence:** CONFIRMED (code); downloader path currently unreferenced (dead code) — impact latent
- **Location:** `lib/features/audio_management/data/audio_storage_manager.dart:39-55`, `:120-133`; unused caller `lib/features/audio_management/data/audio_pack_downloader.dart` (not referenced from any UI/provider — `audio_pack_manager_screen.dart:137-144` only shows a SnackBar on download)
- **Evidence:**
```dart
    try {
      final bytes = await file.readAsBytes();
      final actualSha256 = sha256.convert(bytes).toString();
      return actualSha256.toLowerCase() == expectedSha256.toLowerCase();
    } catch (e) {
```
```dart
  Future<bool> hasSufficientStorage(int requiredBytes) async {
    try {
      // In standard desktop / unit tests or non-rooted mobile, stat fs
      // We check if target base storage exists and is writable
      final dir = Directory(baseStoragePath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return true;          // never compares against requiredBytes / free space
```
- **Root cause:** `promoteFromStaging` → `verifyFileIntegrity` reads each audio file entirely into memory and runs `sha256.convert` synchronously on the calling (UI) isolate — for a 250 MB pack of many files this creates a per-file memory spike and main-thread hashing time, repeated in the download loop (`downloader:87-168`). `hasSufficientStorage` never evaluates free space, so the downloader's advertised disk-space guard silently passes and a large pack can fill storage then fail mid-loop.
- **Impact:** current user-visible impact is nil because the downloader is not wired to the UI (the “Tải” button only shows a SnackBar) — flagged as a latent defect that will materialize once audio-pack download is enabled. Docs/pack catalog advertise 8–250 MB packs.
- **Fix:** hash in a background isolate / streamed chunks (`sha256.bind(stream)`), compare free space (`StatFs` plugin) against `requiredBytes` with margin; or verify server-provided checksums off the UI isolate before promotion.
- **Verification status:** read storage manager + downloader; grepped `AudioPackDownloader` usage (only its own file) and confirmed the manager screen's download handler does not invoke it.

---

## Documentation claims vs. code (gaps found)

| Doc claim | Evidence in code | Verdict |
|---|---|---|
| `docs/bug-fixes/P1_06_REAL_AUDIO_SYSTEM.md` §1 item 3: backgrounding/app call “did not interrupt audio recording **or playback**” was fixed | Only recording is lifecycle-aware (`AppLifecycleManager` callbacks from recorder & voice service). `DefaultAudioPlayerService` has no lifecycle/interruption handling; no `audio_session`/audio-focus configuration in `lib/` (only unused naming) → **F05**. | **GAP** for playback. |
| `P1_06` §5: “Microphone hardware is released immediately on `stopRecording()`, `cancelRecording()`, or `dispose()`” | `dispose()` releases the native recorder but never unregisters the `AppLifecycleManager` callback (`audio_recorder_service.dart:75` vs `:300-310`) → dead services accumulate and are invoked on every background transition → **F06**. | **GAP** (callback/listener not released; native handle is). |
| `P1_06` §3.2: amplitude “polled at 60 ms intervals” | Code polls at **100 ms** *and* additionally subscribes to `onAmplitudeChanged(100 ms)`, emitting duplicate samples (`audio_recorder_service.dart:173-203`, `:241-256`) → **F09**. | **GAP** (rate + duplication). |
| `P1_06` §3.2 / `audio_models.dart`: lifecycle/privacy guarantees | Voice service can start the recorder after an abort during session startup (**F03**) and stale turns run after `endSession`/abort (**F02**). | **GAP** for the voice pipeline (recorder-level abort logic itself exists). |
| `docs/bug-fixes/F13_N_PLUS_ONE_QUERY_OPTIMIZATION.md`: N+1 eliminated (Hanzi, Sentence modules) | The documented hanzi/sentence bulk APIs exist, but N+1 patterns remain elsewhere in T4 scope: `AudioCoverageAuditor` per-asset `File.exists()` (**F13**), content-pack import per-row SELECT+UPDATE (**F14**), `audio_packs_provider._loadPacks` 7 sequential COUNT queries, `LearnerContextService` 5 queries per chat turn. | **PARTIAL** — fix is module-scoped, not repo-wide. |
| `docs/bug-fixes/F20_LEARNING_UI_AUDIO_ACCESSIBILITY.md` §2.2/2.3: “Quản lý Timer highlight và giải phóng tài nguyên sạch sẽ trong `dispose()`” | `AnimationController` is disposed correctly in `FlashcardCard`; but `LessonVocabView` never cancels its discarded status subscription (**F23**) and both widgets create a native player + TTS engine per instance (**F18**). | **PARTIAL** — disposal mostly correct, resource volume/listener tracking is not. |
| `docs/bug-fixes/P0_01_STARTUP_SEED_LOADING.md` §2.5: “Giải mã JSON trong Background Isolate để giữ 60 FPS” | Verified true: `seed_loader.dart:71-81` uses `Isolate.run` for `json.decode` + `SeedBundle.fromJson` + SHA-256; Flutter's `AssetBundle.loadString` also offloads UTF-8 decode for >50 KB assets (`C:\src\flutter\packages\flutter\lib\src\services\asset_bundle.dart:91-101`). | **VERIFIED** for seed parsing. Remaining startup costs: content-pack import N+1 (**F14**), re-entrant retry (**F15**), eager 5-tab + audio-stack init (**F08**). |
| `P0_01` §4: idempotent restart “< 50 ms” | Static inspection cannot confirm timing (no app run allowed); code path on restart includes DB open, seed-count query, 2× pack queries, `FlutterSecureStorage` migration (Android KeyStore) and an artificial `Future.delayed(50ms)` (`app_startup_provider.dart:188`) before `isReady`. | **UNVERIFIED / LIKELY OPTIMISTIC** (flagged for the Lead's device profiling). |
| `unified_audio_playback_service.dart:6-8`: “Ensures single-audio focus across Pinyin, Vocabulary, Listening, Reading, and Shadowing” | Only pinyin screens use the singleton; 6+ other modules instantiate their own players/TTS → **F19**. | **GAP**. |

---

## Verified-clean / non-findings (avoiding false positives)

- `lib/core/theme/components/**`: no `AnimationController`/`FocusNode`/`TextEditingController` ownership at all (grep: only `HiTextField` accepting an external controller/focus node — correctly not disposing caller-owned resources). No T4 finding.
- `DefaultAudioPlayerService.dispose()` (`audio_player_service.dart:262-271`) correctly cancels all three subscriptions, disposes only an owned player and closes both controllers.
- `DefaultVoiceConversationService.dispose()` correctly calls `AppLifecycleManager.instance.unregisterAudioSession(_onLifecycleAbort)` — the pattern the recorder is missing (F06).
- `AiTutorTextChatScreen.dispose()` cancels `_streamSub` + `_cancelToken` and disposes both controllers; the stream pipeline checks `mounted` in `onComplete`/`onError`/chunk handlers (per-token rebuild is a perf issue, F10, not a crash).
- `AiTutorVoiceChatScreen.dispose()` removes its `WidgetsBindingObserver` and cancels both subscriptions; scroll/text controllers disposed — the gap is session/mic teardown (F01/F04), not classic controller leaks.
- `AiTutorTabScreen` uses `AutomaticKeepAliveClientMixin` correctly and disposes nothing it owns (it owns no resources).
- `AppRouter`/`AppRoutes`: no timers, controllers, subscriptions or isolates; the `addPostFrameCallback(selectTab)` closures are cheap and provider-only (no `State`/`BuildContext` capture), so no leak.
- `SeedLoader.seedFromJsonString` offloads JSON decode + hashing to `Isolate.run` (verified) and uses batched transactions for writes; `content_pack_manager.installOrUpdatePack` offloads the top-level JSON decode (the per-item decode is flagged in F14).
- `AppLifecycleManager.registerAudioSession` de-duplicates by callback identity; Dart tear-off equality means the same recorder instance registers only once (the leak in F06 is about *different* recorder instances never being removed).
- `AppDatabase.open()` is idempotent (`if (_db != null && _db!.isOpen) return _db!;`), so concurrent `initialize()` calls don't double-open the DB (they still double-run the seeding/import phases — F15).
- `main()` does **not** block before `runApp`; startup work runs inside a Riverpod notifier after the first frame (`app_startup_provider.dart:62-71`) — the splash is responsive by design.
- `gemini_rest_ai_provider.streamText` implements real cancellation: `CancelToken.onCancelled` cancels the HTTP subscription and pushes `AiCancelledException` (`gemini_rest_ai_provider.dart:354-382`) — the text chat uses it, only the voice service ignores it (F02).

---

## Appendix A — Async lifecycle paths traced

1. **Voice start path:** `AiTutorVoiceChatScreen._startVoiceSession` → `repo.createSession` (await) → `service.startSession` → `stopPersonaVoicePreview` (await) → `checkPermission` (await; permission dialog → lifecycle `inactive`) → `Future.delayed(300ms)` → greeting playback (await) → `recorder.startRecording` (await) → `listening`. No abort flag ⇒ F03. Button remains tappable until status becomes `connecting`, and `requestingPermission` is not in `isSessionActive` ⇒ F07.
2. **Voice turn path:** `submitSpeechInput` → `recorder.pauseRecording()` → `repo.sendMessage` (await; **no CancelToken**) → `_addTranscript` → `speaking` → TTS/sample playback (await) → `listening` → `recorder.resumeRecording()`. `endSession`/`_onLifecycleAbort` can run during the await ⇒ F02.
3. **Voice teardown paths:** button `_endVoiceSession` only; screen `dispose()` does not end session; tab switch/mode switch do not end session ⇒ F01.
4. **Text stream path:** `_sendMessage` → `repo.sendMessageStream` (StreamController `onListen`) → DB writes → context build → AI stream → per-chunk `controller.add` → screen `setState` per chunk; on completion repo writes assistant turn + evidence + calls `onComplete` → screen `ref.invalidate(sessionMessagesProvider)` → full re-fetch ⇒ F10/F11.
5. **Recorder lifecycle:** ctor registers callback → `didChangeAppLifecycleState(paused|inactive|hidden)` → `_stopAllActiveAudioSessions` → `recorder._onLifecycleStop` → `cancelRecording()` (unawaited) + `_updateStatus(error)`; `dispose()` never unregisters ⇒ F06.
6. **Startup path:** `main` (sync) → `runApp` → `AppShell` builds → `appStartupProvider.build` microtask → `initialize()` 10 steps (DB → migrations → seed check → seed (isolate parse) → 2 packs (N+1 import) → integrity → credential migration/profile) → `ready`; retry button re-invokes `initialize` unguarded ⇒ F14/F15. On `ready`, `AppShell` mounts all five tabs + AI Tutor text+voice screens at once ⇒ F08.

## Appendix B — Full instrumentation greps used

`Timer(`, `Timer.periodic`, `StreamSubscription`, `.listen(`, `StreamController`, `WebSocketChannel|WebSocket`, `AudioPlayer(|AudioRecorder(`, `AnimationController`, `TextEditingController(`, `ScrollController(`, `FocusNode(`, `Future.delayed`, `addPostFrameCallback`, `mounted`, `dispose()`, `autoDispose`, `AudioSession|AudioFocus|setAudioContext|handleInterruptions`, `AppLifecycleManager|registerAudioSession|unregisterAudioSession`, `UnifiedAudioPlaybackService`, `DefaultAudioPlayerService|DefaultAudioRecorderService|DefaultTtsService`, `invalidate(appStartupProvider)`, `endSession|startMicTest|stopMicTest`.

No source files were modified; only this report was written. `dart analyze` is intentionally left to the Lead per task split.
