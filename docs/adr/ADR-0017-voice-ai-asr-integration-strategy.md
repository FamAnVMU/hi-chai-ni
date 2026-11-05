# ADR-0017: Voice AI Speech-to-Text (ASR) Integration Strategy

**Date**: 2026-11-05  
**Status**: Proposed / Accepted  
**Deciders**: Thread 3 (AI Intelligence & Voice Lab Lead), Thread 5 (Independent QA Auditor), Architecture Board  
**Target Module**: `lib/features/ai_tutor/`, `lib/core/audio/`  
**Related Audit Item**: BUG-NEW-003, F-06, F-18  

---

## 1. Context & Problem Statement

HI Chinese provides an **AI Tutor Voice Chat** experience (`AiTutorVoiceChatScreen`) designed to enable spoken Mandarin conversations between Vietnamese learners and pedagogical AI personas (e.g., Teacher Qiaoqiao, Local Elder Lao Wang, Classmate Xiao Ming).

During the QA Round 3 independent audit, Thread 5 identified a architectural gap (**BUG-NEW-003**):
1. The user interface presented a "Voice Chat" mode with real-time waveform visualization, but the underlying application lacked an Automatic Speech Recognition (ASR / STT) engine in `pubspec.yaml` (neither on-device `speech_to_text` nor cloud ASR WebSocket stream).
2. Consequently, learners were required to manually type text into a fallback `TextField` (`'Nhập tiếng Trung nếu cần giả lập giọng nói...'`), while the AI response was vocalized via `FlutterTts` (TTS working reliably).
3. Attempting to start voice recording without speech recognition caused confusion, wasted device resources (continuous mic capture without consumption), and triggered permission exceptions if microphone access was denied.

### Specific Challenges of Mandarin Chinese Speech Recognition in Pedagogy:
- **Tonal Homophones**: Mandarin Chinese has 4 lexical tones plus a neutral tone. A syllable like *shi* corresponds to dozens of different characters (是, 十, 时, 事, 视, 师...). Generic ASR engines frequently transcribe the wrong Hanzi unless informed by pedagogical grammatical context and active lesson vocabulary.
- **Learner Phoneme Deviations**: Foreign learners frequently make tonal errors (e.g., pronouncing tone 1 as tone 4) and retroflex consonant confusion (zh/z, ch/c, sh/s). Generic STT either rejects their audio or silently substitutes unintended characters.
- **Offline-First Architectural Guarantee**: HI Chinese operates under a strict offline-first doctrine (SQLite database, bundled offline content packs). Relying solely on cloud APIs would break offline accessibility.
- **Cost & Bandwidth Constraints**: Continuous cloud streaming incurs token and audio egress costs, requiring budget guardrails.

---

## 2. Decision

We adopt a **Hybrid Two-Tier ASR Architecture with Graceful Fallback** (Tiered Fallback Architecture):

1. **Short-Term Phase (Immediate - QA Round 3 UX Transparency)**:
   - Expose explicit `voiceInputSupported` capability on `VoiceConversationService` (default `false`).
   - Disable misleading recording wave animations when native ASR is inactive.
   - Display clear, transparent pedagogical messaging: *"Chế độ hội thoại văn bản có hỗ trợ phát âm AI (Tính năng nhận diện giọng nói đang phát triển)"*.
   - Decouple hardware recorder from session start to eliminate background mic draining and prevent unhandled `AudioRecordingPermissionException`.

2. **Tier 1 (On-Device Baseline / Offline Free)**:
   - Integrate `speech_to_text` (wrapping Android `SpeechRecognizer` / iOS `SFSpeechRecognizer`).
   - Provide zero-cost, offline Mandarin speech recognition (`zh-CN`).
   - Augment raw ASR output with local Pinyin phonetic matching against current HSK vocabulary tables in SQLite.

3. **Tier 2 (Pro / Cloud Real-time Streaming)**:
   - Integrate Gemini 3.8 Live API via bidirectional WebSockets (16kHz 16-bit PCM mono).
   - Deliver full conversational audio loop with native barge-in (interruption), tone correction, and spontaneous dialogue.
   - Gate behind valid Gemini API Key / Firebase AI Logic authentication.

4. **Tier 0 (Graceful Fallback - Text + AI Speech)**:
   - If mic is unavailable, permissions denied, or offline without language packs, seamlessly fall back to text typing with AI audio response, ensuring 100% app reliability.

---

## 3. Alternatives Considered

### Alternative A: Pure On-Device STT (`speech_to_text`)
- **Pros**:
  - Free, zero recurring API cost.
  - Operates offline (if OEM offline Mandarin language model is installed).
  - Ultra-low latency (< 200ms).
- **Cons**:
  - Heavily reliant on device OEM implementation (Google Speech Services on Pixel/Samsung vs proprietary engines on Xiaomi/Oppo/Vivo).
  - Chinese language packs are often missing by default on non-Chinese Android ROMs, requiring manual user download.
  - Zero tone diagnostic feedback: it only outputs Hanzi characters without confidence scores for tones or Pinyin accuracy.
- **Why rejected as sole solution**: Inadequate for foreign language pedagogy where tonal precision and accent feedback are paramount.

---

### Alternative B: Pure Cloud Real-Time Streaming (Gemini 3.8 Live API via WebSockets)
- **Pros**:
  - Unrivaled Mandarin understanding and context-aware Hanzi disambiguation.
  - Native bidirectional streaming: user audio in -> AI audio out with natural barge-in.
  - Can assess tone contours, pronunciation errors, and respond pedagogically in real time.
- **Cons**:
  - Requires continuous, stable Internet connection.
  - Token consumption cost (audio input/output tokens per minute).
  - Latency jitter over mobile 3G/4G networks (300ms - 900ms RTT).
- **Why rejected as sole solution**: Violates HI Chinese's offline-first core requirement; inaccessible to learners without network connection.

---

### Alternative C: Hybrid 2-Tier ASR Architecture (Selected)
- Combines the offline resilience of On-Device STT with the pedagogical excellence of Gemini Live API.
- Automatically selects the optimal tier based on network connectivity, device capabilities, and user tier.

---

## 4. Technical Architecture & Integration Specification

```
┌─────────────────────────────────────────────────────────────────┐
│                    AiTutorVoiceChatScreen                       │
│  - WaveformVisualizer (active only when ASR recording is real)  │
│  - Transcript Bubble List (Interim vs Final segments)           │
│  - Transparent Status Banner & Mode Switcher                    │
└────────────────────────────────┬────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────┐
│                   VoiceConversationService                      │
│  - status: idle | requestingPermission | listening | ...        │
│  - voiceInputSupported: bool                                    │
│  - engineMode: onDeviceStt | cloudLiveApi | textFallback        │
└───────────────┬────────────────────────────────┬────────────────┘
                │                                │
    [voiceInputSupported = true]                 │ [voiceInputSupported = false]
                │                                │
        ┌───────┴────────┐                       ▼
        │                │             ┌──────────────────────────┐
        ▼                ▼             │     Tier 0 (Fallback)    │
 ┌─────────────┐  ┌─────────────┐      │  - Manual Text Input     │
 │   Tier 1    │  │   Tier 2    │      │  - FlutterTts Speech     │
 │  On-Device  │  │ Gemini Live │      │  - 100% Reliable, No Mic │
 │   (STT)     │  │ (WebSocket) │      └──────────────────────────┘
 └─────────────┘  └─────────────┘
```

### 4.1. Audio Pipeline Specifications
- **Sample Rate**: 16,000 Hz (16 kHz).
- **Channel**: Single channel (Mono).
- **Bit Depth**: 16-bit Linear PCM (`audio/pcm;rate=16000`).
- **Chunk Size**: 100ms - 200ms frame slices for WebSocket streaming.

### 4.2. State Machine Guarantees
- `idle`: Audio hardware completely released; zero background energy drain.
- `requestingPermission`: Asynchronous permission query; failures degrade cleanly to Tier 0 without throwing uncaught exceptions.
- `listening`: Hardware mic active; emits amplitude stream to `WaveformVisualizer`.
- `processing`: Mic recording paused; awaiting LLM response stream.
- `speaking`: Audio player active; barge-in listener active to trigger immediate `interrupt()`.

---

## 5. Implementation Roadmap

| Phase | Milestone | Scope / Deliverables | Target Timeline |
|---|---|---|---|
| **Phase 0** | **UX Transparency & Guardrails** | • Set `voiceInputSupported = false`<br>• Eliminate fake listening wave animations<br>• Add informative UI banner<br>• Graceful mic permission handling | **Completed (Round 3 Fix)** |
| **Phase 1** | **On-Device STT (Tier 1)** | • Add `speech_to_text: ^6.6.0`<br>• Implement `OnDeviceSttService` with `zh-CN` locale detection<br>• Add offline language pack installation guide | Sprint 12 |
| **Phase 2** | **Gemini Live API (Tier 2)** | • Implement WebSocket bidirectional audio protocol (`wss://generativelanguage.googleapis.com/ws/...`)<br>• 16kHz PCM streaming pipeline<br>• Real-time barge-in & interruption synchronization | Sprint 13 |
| **Phase 3** | **Pedagogical Pinyin Disambiguation** | • SQLite lexicon re-ranking for homophones<br>• Tone contour confidence scoring | Sprint 14 |

---

## 6. Consequences & Trade-offs

### Positive
- **Integrity & Trust**: Learners and auditors have full transparency; no fake or mock speech recognition animations.
- **Stability**: Zero unhandled exceptions or crashes when microphone permissions are denied or unavailable.
- **Battery & Privacy**: Microphone hardware is only engaged when an active ASR engine is actually consuming the audio stream.
- **Future-Ready**: The domain interfaces (`VoiceConversationService`, `voiceInputSupportedProvider`) are already designed to seamlessly switch on Tier 1 and Tier 2 without refactoring the UI.

### Negative / Challenges
- Two audio pathways will need ongoing maintenance once Tier 1 and Tier 2 are built.
- Android OEM fragmentation requires defensive handling for offline Chinese speech models.
