# ADR-0016: Sliding Window Context Limit for AI Tutor

**Date**: 2026-11-05  
**Status**: Accepted  
**Deciders**: Thread 3 (AI Intelligence & Voice Lab Lead), Architecture Board  
**Target Module**: `lib/core/database/dao/chat_dao.dart`, `lib/features/ai_tutor/data/repositories/ai_tutor_repository.dart`  
**Related Audit Item**: F-08  

---

## 1. Context & Problem Statement

In the original AI Tutor implementation, `ChatDao.getSessionMessages()` retrieved all messages belonging to a conversation session without limit. As conversation sessions lengthened, sending complete chat histories to the Gemini API led to:
- Excessive token consumption and ballooning inference costs.
- Increased latency for streaming and request turnaround.
- Vulnerability to exceeding model context limits.
- Potential degradation in model attention to recent pedagogical instructions.

## 2. Decision

We implemented a database-level **Sliding Window Context Limit** of 20 messages for AI context construction:
1. `ChatDao.getRecentSessionMessages(sessionId, limit: 20)` uses SQL `ORDER BY created_at DESC LIMIT ?` followed by reversing the result set in memory, guaranteeing chronological order (oldest to newest) without loading unneeded historical rows into Dart memory.
2. `AiTutorRepository.sendTextMessage()` and `getConversationHistory()` query this windowed context when constructing LLM prompt context.
3. Complete conversation history remains permanently preserved in SQLite for audit and full UI transcript paging.

## 3. Consequences

### Positive
- Strict bound on LLM token footprint per turn.
- Constant memory consumption regardless of session length.
- Reduced API latency and lower operating costs.

### Negative / Trade-offs
- The AI does not remember context from turns further back than 20 messages unless explicitly summarized or stored in `LearnerContext` (which is separately tracked in SQLite `learner_goals` and `learner_evidence`).
