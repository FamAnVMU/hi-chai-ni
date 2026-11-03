# F16: Fix Tutor Persona Voice Preview & Missing Audio Assets

## 1. Executive Summary
This document details the analysis, architectural redesign, and verification for the AI Tutor Persona Voice Preview feature in HI Chinese.

Prior to this fix, `TutorPersona` generated speculative audio asset paths (`assets/audio/personas/${id.name}_preview.mp3`). However, the `assets/audio/personas/` directory did not exist on disk nor was it declared in `pubspec.yaml`. When a learner attempted to preview a tutor's voice, the audio player threw unhandled playback exceptions, degrading user experience.

The fix replaces hardcoded speculative asset assumptions with a multi-tiered voice preview architecture powered by real Speech Synthesis (`flutter_tts`) with custom persona prosody (pitch and speech rate) and graceful fallback handling.

---

## 2. Root Cause Analysis

1. **Missing Audio Asset Directory**:
   - `pubspec.yaml` declared only `assets/audio/hsk1/` and `assets/audio/hsk2/`.
   - `assets/audio/personas/` did not exist in the repository.
   - `TutorPersona.voicePreviewSampleUri` generated paths dynamically based on enum names (`qiaoqiao_preview.mp3`, `laowang_preview.mp3`, `xiaoming_preview.mp3`).
2. **Crash on Audio Playback**:
   - Calling `player.play('assets/audio/personas/...')` triggered `AudioPlaybackException` / `PlatformException` when asset bundle lookup failed.
3. **Missing Lifecycle and Concurrency Controls**:
   - Switching personas while audio was playing did not halt the previous preview.
   - Closing sheets or disposing the voice conversation service during playback caused stream controller race conditions (`Bad state: Cannot add new events after calling close`).

---

## 3. Architecture & Implementation

### 3.1 Multi-Tier Voice Strategy (Plan A / B / C)

```
                       ┌───────────────────────────────┐
                       │ User taps Voice Preview       │
                       └───────────────┬───────────────┘
                                       │
                        Source == assetAudio?
                                ├── Yes ──> Asset exists in rootBundle?
                                │                 ├── Yes ──> Play via AudioPlayerService
                                │                 └── No  ──┐
                                └── No  ──┐                 │
                                          │                 │
                        Source == ttsSynthesis?             │
                                ├── Yes ──> TTS ready & 'zh-CN' available?
                                │                 ├── Yes ──> Speak via TtsService (Custom pitch & rate)
                                │                 └── No  ──┐
                                └── No  ────────────────────┼──> Status: unsupported (Clear UI Message)
```

1. **Plan A (Asset Audio)**:
   - Used when high-fidelity human recordings are bundled.
   - Verified via `rootBundle.load(assetPath)` before playback to prevent unhandled exceptions.
2. **Plan B (TTS Synthesis)**:
   - Primary operational tier for AI Tutor Personas.
   - Leverages `flutter_tts: ^4.2.5` via abstract `TtsService`.
   - Checks device language support (`isLanguageAvailable('zh-CN')`) before speaking.
   - Applies distinct prosody settings (pitch, rate) and persona-specific introductory scripts.
3. **Plan C (Graceful Fallback)**:
   - If neither asset nor TTS is available, `PersonaPreviewPlaybackState.unsupported` is broadcast.
   - UI displays clear, user-friendly feedback without crashing or playing silence.

### 3.2 Tutor Persona Voice Profiles

All registered personas in `lib/features/ai_tutor/domain/models/tutor_persona.dart` are configured with realistic TTS parameters:

| Persona | Chinese Name | Role | Source Type | Locale | Pitch | Rate | Introductory Sample Text |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Qiao Qiao** | 乔乔老师 | Patient Beginner Tutor (HSK 1-3) | `ttsSynthesis` | `zh-CN` | 1.15 | 0.45 | 你好！我是乔乔老师，很高兴和你一起学习汉语。 |
| **Lao Wang** | 老王老师 | Formal Business Tutor (HSK 4-6) | `ttsSynthesis` | `zh-CN` | 0.85 | 0.50 | 你好，我是老王。学习中文贵在严谨和坚持，我们开始吧。 |
| **Xiao Ming** | 小明 | Conversational Peer (HSK 2-5) | `ttsSynthesis` | `zh-CN` | 1.00 | 0.55 | 嗨！我是小明。平时有什么想聊的尽管说，咱们边聊边学！ |

- `TutorPersona.voicePreviewSampleUri` returns `null` for non-asset personas, eliminating speculative asset strings.
- Added `canPreview` property on `TutorPersona`.

### 3.3 Voice Conversation Service & Concurrency Controls

In `lib/features/ai_tutor/domain/voice/voice_conversation_service.dart`:
- Added `previewStatus` getter and `previewStatusStream`.
- Implemented `previewPersonaVoice(TutorPersona persona)`:
  - Halts any existing playback (player or TTS) before starting a new preview.
  - Updates state to `loading`, then `playing`, `stopped`, `unsupported`, or `error`.
- Implemented `stopPersonaVoicePreview()`:
  - Halts player and TTS immediately.
  - Emits `PersonaPreviewPlaybackState.stopped`.
- Added StreamController closure guards (`if (!_previewStatusController.isClosed)`) across all state-setting methods to eliminate `Bad state` exceptions during asynchronous disposal.

### 3.4 UI Integration

- **`ai_tutor_tab_screen.dart`**:
  - Persona selection bottom sheet displays stateful preview button (Loading spinner, Play icon, Stop icon).
  - Automatically invokes `stopPersonaVoicePreview()` when the modal sheet is closed.
- **`ai_tutor_voice_chat_screen.dart`**:
  - App bar includes preview toggle button tied to `personaPreviewStatusProvider`.
  - Shows localized feedback snackbars on status changes.

---

## 4. Verification & Testing

### 4.1 Unit Test Suite (`persona_voice_preview_test.dart`)
A dedicated unit test suite was implemented covering 10 distinct test scenarios:
1. Verify all registered personas have non-empty Chinese sample text, Pinyin, and Vietnamese translations.
2. Verify differentiated prosody configurations across personas (Qiao Qiao > 1.0 pitch, Lao Wang < 1.0 pitch, Xiao Ming high rate).
3. Verify TTS preview calls `speak()` with exact persona parameters (`zh-CN`, pitch, rate, sample text).
4. Verify Lao Wang and Xiao Ming invoke speech synthesis with respective parameters.
5. Verify stopping preview halts TTS and audio player and updates status to `stopped`.
6. Verify unsupported TTS locale is caught and emits graceful unsupported status without exceptions.
7. Verify `null` TTS engine is safely handled without throwing exceptions.
8. Verify missing asset audio is caught by rootBundle check without throwing `AudioPlaybackException`.
9. Verify switching personas immediately stops previous preview before initiating new preview.
10. Verify calling `dispose()` cleans up controllers and stops audio without throwing errors.

### 4.2 Module Test Results
- Ran `flutter test test/features/ai_tutor/`:
  - **All 59 tests passed** (including `persona_voice_preview_test.dart`, `ai_tutor_voice_chat_test.dart`, `ai_tutor_text_chat_test.dart`, `ai_tutor_auxiliary_guardrail_test.dart`, and `learner_context_test.dart`).
- Ran `dart analyze lib test`:
  - **0 issues found**.
