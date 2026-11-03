# HI CHINESE – AUDIT & SPECIFICATION: GOOGLE GEMINI AI MODEL REGISTRY (P0_05)

**Document Version:** 1.0.0  
**Status:** Approved & Implemented  
**Date:** 2026-11-03  
**Authors:** Principal AI Integration Engineer & Mobile Security Team  
**Scope:** `lib/core/network/ai/models/ai_model_config.dart`, `lib/core/network/ai/providers/gemini_rest_ai_provider.dart`, `lib/features/settings/presentation/screens/ai_settings_screen.dart`

---

## 1. Executive Summary & Audit Findings

During the system reliability audit of HI Chinese, the Gemini AI Model Registry was reviewed to ensure all configured Model IDs correspond to actual Google Gemini API production and preview endpoints, align with strict capability boundaries, and pass credentials securely via headers rather than query strings.

### Official Upstream Verification (Google Gemini Documentation)

We verified each reported model code against the official Google Gemini API documentation:

| Model ID | Official Display Name | Lifecycle Status | Context Window (In/Out) | Official Capabilities | Supported HI Chinese Task |
|---|---|---|---|---|---|
| `gemini-3.8-flash` | Gemini 3.8 Flash | **GA / Stable** (Sep 2026) | 1,048,576 / 65,536 | Multimodal (Text/Img/Audio/Video/PDF), Streaming, Function Calling, Thinking, Grounding | Grammar Analysis, Reading Comprehension, Complex Feedback |
| `gemini-3.5-flash-lite` | Gemini 3.5 Flash Lite | **Stable** (Jul 2026) | 1,048,576 / 65,536 | Ultra-low latency text & multimodal input, streaming, function calling. (No TTS/No Live API) | Conversational Tutor, Quick Dictionary Definition, Pronunciation Scoring |
| `gemini-3.1-pro-preview` | Gemini 3.1 Pro Preview | **Preview** (Feb 2026) | 1,048,576 / 65,536 | Deep pedagogical reasoning, classical Chinese / Chengyu etymology, complex syntax | Advanced Linguistics & Translation Breakdown |
| `gemini-3.8-live` | Gemini 3.8 Live | **GA / Stable** (2026) | Audio/Text streaming | Bidirectional streaming (WebSockets / Live Connect), real-time duplex voice | Live Spoken Dialogue (Interactive voice chat) |
| `gemini-2.5-flash` | Gemini 2.5 Flash | **Stable Fallback** | 1,048,576 / 8,192 | General multimodal, streaming | Production Fallback Tier |
| `gemini-2.5-flash-lite` | Gemini 2.5 Flash Lite | **Stable Fallback** | 1,048,576 / 8,192 | Fast text & multimodal input | Production Fallback Tier (Lite) |
| `gemini-2.5-pro` | Gemini 2.5 Pro | **Stable Fallback** | 2,097,152 / 8,192 | Deep reasoning fallback | Production Fallback Tier (Pro) |

---

## 2. Architectural Principles & Implementation

### 2.1 Single Source of Truth
Model IDs are defined strictly in `AiModelRegistry` (`lib/core/network/ai/models/ai_model_config.dart`). Individual application modules (chat, dictionary, grammar, pronunciation) never hard-code raw model strings.

### 2.2 Explicit Capability Matrix (No Heuristic Guessing)
Capabilities are defined via the strongly typed `AiModelCapability` struct:
```dart
class AiModelCapability {
  final bool supportsText;
  final bool supportsStreaming;
  final bool supportsAudioInput;
  final bool supportsTts;
  final bool supportsLiveApi;
  final bool supportsVision;
}
```
Capabilities are **never** inferred by regex or substring matching on model names. A model must explicitly declare `supportsLiveApi: true` or `supportsTts: true` to be surfaced for voice or audio-generation tasks.

### 2.3 Secure Header-Based Credential Transmission
In `GeminiRestAiProvider`, all REST and SSE streaming requests transmit the Gemini API Key exclusively via the HTTP header:
```http
x-goog-api-key: AIzaSy...
Content-Type: application/json
```
Keys are never passed as cleartext URL query parameters (`?key=...`), preventing key leakage in proxy logs, server access logs, and referral headers.

### 2.4 Error Classification & Troubleshooting Hints
Diagnostic failures from `testConnection()` or generation calls are mapped to granular domain error types:
- **HTTP 400 (API_KEY_INVALID)** or **HTTP 401**: `ConnectionErrorType.unauthorized` with actionable user guidance to verify the Google AI Studio key.
- **HTTP 429**: `ConnectionErrorType.quotaExceeded` with cooldown notice and link to AI Studio quota tier.
- **HTTP 404**: `ConnectionErrorType.modelUnavailable` with fallback switch hint.
- **HTTP 403 (App Check)**: `ConnectionErrorType.appCheckFailed` with Play Integrity notice.
- **Network / SocketException**: `ConnectionErrorType.networkError` with offline check.
- **TimeoutException**: `ConnectionErrorType.timeout`.

All error logs and exception messages pass through `AiCredentialStorage.sanitizeSecret(text, apiKey)` ensuring raw secrets are strictly replaced with `[REDACTED_API_KEY]`.

---

## 3. Automated Verification & Test Results

The following test suites were executed and passed 100%:

1. **`test/features/settings/ai_settings_test.dart` (16/16 Passed)**:
   - Model Registry single-source-of-truth verification.
   - Explicit capability checking (e.g. `gemini-3.5-flash-lite` rejects TTS/Live API, `gemini-3.8-live` confirms Live API).
   - Dynamic default model update and task route re-binding.
   - Secure credential storage, retrieval, and secret masking (`AIza...1234`).
   - Zero-log secret sanitization.
   - Live connection diagnostics (HTTP 400, 401, 404, 429, SocketException, Timeout).
   - Widget tests for all 4 sections of `AiSettingsScreen`.

2. **`test/core/startup/app_startup_integration_test.dart` (7/7 Passed)**:
   - Verifies canonical 10-step startup sequence.
   - Confirms `AiModelRegistry` routes default tasks safely with fallback compatibility.

3. **`dart analyze lib test`**:
   - `No issues found!` (0 warnings, 0 errors, 0 lints).
