# Thread 2: Pedagogy, Learning Experience & Curriculum Architecture — Status

- **Agent Role**: Senior Curriculum Specialist & Chinese Language Pedagogist · Pedagogy Lead
- **Branch**: `feature/thread-2-learning`
- **Current Status**: ACTIVE / TASK-T2-006 (ONBOARDING DOWNLOAD INTERCEPTOR & FLOW LIFECYCLE) COMPLETED
- **Health**: HEALTHY (Onboarding Interceptor 100% Verified, LessonFlow autoDispose & warmup Lifecycle Standardized, All Tests PASS)

---

## 1. Scope of Ownership

- **Pedagogical Curriculum Architecture**: HSK 1–6 Content Packs (`hsk1_pack_v1` through `hsk6_pack_v1`), 6-stage lesson structure (`warmup`, `vocabulary`, `grammar`, `dialogue`, `exercise`, `mastery`).
- **Linguistic & Pedagogical Quality**: Elimination of machine translation slop and formulaic strings, contextual turn-based dialogues with accurate tone-marked Pinyin, natural Vietnamese translations.
- **Assessment & Exercise Design (Chặng 5 & 6)**: Curated high-discrimination multiple-choice items, plausible distractors, explicit synonym differentiation pairs, and comprehensive Vietnamese pedagogical explanations.
- **Graded Readers & Reading Comprehension**: Thematic classification of passages, vocabulary coverage verification (>=85% level-appropriate words), pedagogical distractors for comprehension questions.
- **Anti-Cheating & Assessment Rules**: Minimum reading duration thresholds, WPM pacing constraints, rigorous scoring algorithms.
- **Handover to AI Voice (Thread 3)**: Readying verified text dialogues (`text_zh`) for edge-tts / neural voice pipeline synthesis.

---

## 2. Component Implementation State Matrix

| Level / Component | Lessons | Dialogue Turns | Assessment Questions (Chặng 5 + 6) | Pedagogical Focus | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **HSK 1 Content Pack** | 15 Lessons | 4–8 turns | 150 questions (10/lesson) | Daily life, greetings, family, shopping, numbers, basic time | **COMPLETED & VERIFIED** |
| **HSK 2 Content Pack** | 15 Lessons | 4–8 turns | 150 questions (10/lesson) | Dining, hospital, travel, work, transport, accommodations | **COMPLETED & VERIFIED** |
| **HSK 3 Content Pack** | 15 Lessons | 6–8 turns | 150 questions (10/lesson) | HSK 3.0 standards, 20 vocab + 3 grammar points / lesson | **COMPLETED & VERIFIED** |
| **HSK 4 Content Pack** | 30 Lessons | 6 turns (180 turns) | 300 questions (10/lesson) | Workplace, social communication, emotional intelligence, green living | **COMPLETED & VERIFIED** |
| **HSK 5 Content Pack** | 36 Lessons | 8 turns (288 turns) | 360 questions (10/lesson) | In-depth social discussion, economics, philosophy, cultural aesthetics | **COMPLETED & VERIFIED** |
| **HSK 6 Content Pack** | 50 Lessons | 8 turns (400 turns) | 500 questions (10/lesson) | Academic debate, linguistics, philosophy, science, classical idioms | **COMPLETED & VERIFIED** |

---

## 3. Latest Deliverables: Task 2.2 Complete (Exercises Refinement)

- **Total Curated Questions**: **1,160 assessment items** (580 practice in Chặng 5 + 580 mastery check in Chặng 6) across 116 lessons in HSK 4, HSK 5, and HSK 6.
- **Pedagogical Standards Achieved**:
  - Purged 100% of synthetic fill-in templates (e.g. *"在这个问题上，我们需要进一步___。"*).
  - Explicitly integrated high-frequency synonym distinction questions (近义词辨析: 深刻 vs 深厚, 忽视 vs 疏忽, 持续 vs 连续, 遏制 vs 抑制, 飞跃 vs 跃进, 腐败 vs 堕落, 隔阂 vs 障碍, 姑且 vs 暂且, 机构 vs 机关, 权衡 vs 衡量, 准则 vs 原则, etc.).
  - Exactly 4 plausible, semantically balanced distractors per question.
  - 100% of questions equipped with detailed, non-empty Vietnamese explanations citing grammar structures, collocations, and contextual rationales.
  - Consistent ID formatting: `ex_hsk{lvl}_{lesson}_{1..5}` for practice and `m_ex_{lvl}_{lesson}_{1..5}` for mastery check.
  - Fully compatible with `LessonPracticeView` and `LessonMasteryView` (`answer_index` and `correct_answer` strictly aligned).
- **Test Gate**:
  - `test_verify_hsk4.py`: 300/300 PASS.
  - `test_verify_hsk5.py`: 360/360 PASS.
  - `test_verify_hsk6.py`: 500/500 PASS.
  - `verify_all_exercises_integrity.py`: 2,320 checks across local and mirror packs PASS.
  - Flutter `content_pack_loader_test.dart`: 4/4 PASS.
  - Flutter `content_pack_service_test.dart`: 4/4 PASS.

---

## 4. Latest Deliverables: Task 2.3 Complete (Level Graduation Exit Exam Calibration)

- **Total Calibrated Exit Exam Questions**: **75 items** across 3 levels:
  - **HSK 4**: 20 questions, 40 minutes, passing score 160/200 (80%).
  - **HSK 5**: 25 questions, 60 minutes, passing score 160/200 (80%).
  - **HSK 6**: 30 questions, 75 minutes, passing score 160/200 (80%).
- **Standardized 3-Part Structure per Exam**:
  - **Phần 1: Vocabulary & Grammar Precision** (Đọc hiểu từ vựng & Ngữ pháp: phân biệt cận nghĩa, cấu trúc ngữ pháp, thành ngữ).
  - **Phần 2: Reading Comprehension** (Đọc hiểu đoạn văn nghị luận, kinh tế, công nghệ, bảo tồn di sản, sinh học, triết học ngôn ngữ).
  - **Phần 3: Cloze Test** (Điền từ vào chỗ trống đoạn văn học thuật / khoa học với 4 phương án nhiễu đồng nhất từ loại và văn phong).
- **UI & Scoring Compatibility**:
  - Hardened `LevelExitExamScreen` to scale reading points to 200 when exams focus on reading and grammar mastery (`listeningQuestions.isEmpty`), ensuring the 80% passing threshold is mathematically achievable.
  - Maintained full dual compatibility with SQLite table `level_exit_exams` via `exam_data_json` and in-memory list `questions`.
- **Test Gate**:
  - `test_verify_exit_exams.py`: 75/75 PASS.
  - Flutter `real_level_exit_exam_test.dart`: 5/5 PASS.
  - Flutter `content_pack_loader_test.dart`: 4/4 PASS.
  - Flutter `content_pack_service_test.dart`: 4/4 PASS.
- **Detailed Report**: [TASK-T2-005-EXIT-EXAM-CALIBRATION.md](file:///C:/Users/phama/.gemini/antigravity/worktrees/hi_chinese/thread_2_learning/docs/agent-coordination/reports/thread-2/TASK-T2-005-EXIT-EXAM-CALIBRATION.md).

---

## 5. Latest Deliverables: Task LEARN-HSK46-VI-001 (Parallel Corpus Curation & Example Approval)

- **Execution Mode**: **Content Curation & Staging Only** (Zero production file modifications).
- **Corpus License Gate Completed**:
  - **APPROVED**: Tatoeba Project (`CC BY 2.0 FR`), CVDICT (`CC BY-SA 4.0`), AllSet Learning Grammar Wiki (`CC BY-NC-SA 3.0`), HSK Standard Curriculum Sentences (`CC-BY-NC-SA-3.0`).
  - **REJECTED**: OPUS TED2020 (`CC BY-NC-ND 4.0` NoDerivatives violation), C3 (Research-only & Monolingual Chinese), OPUS OpenSubtitles (Copyright risks), StoryWeaver (Juvenile literacy register unsuitable for HSK 4–6), AnkiWeb Shared Decks (TOS personal use & BLCUP textbook copyright).
- **Staging Datasets Generated in `audit/hsk46_vi_enrichment/thread-2_candidates/`**:
  - `hsk4_candidates.jsonl`: 594 candidates (4 APPROVED, 590 TRANSLATION_REVIEW).
  - `hsk5_candidates.jsonl`: 1,279 candidates (27 APPROVED, 1,252 TRANSLATION_REVIEW).
  - `hsk6_candidates.jsonl`: 1,942 candidates (43 APPROVED, 1,899 TRANSLATION_REVIEW).
  - `rejected_candidates.jsonl`: 5 sample candidate rejections across all failed license categories.
  - `unresolved_mappings.jsonl`: 586 items (6 polyphones `MAPPING_AMBIGUOUS` + 575 Category 1 `NO_VALID_PARALLEL_EXAMPLE` + 5 Category 3 `STANDALONE_OMITTED_FROM_LESSONS`).
  - `human_review_required.json`: 3,764 items awaiting human pedagogue sign-off.
  - `corpus_source_manifest.json`: Provenance manifest of 8 surveyed corpus sources.
  - `license_review.md`: Full legal & pedagogical review.
  - `candidate_summary.md`: Summary breakdown.
- **Pre-Handover Verification Gate**:
  - `verify_candidates_integrity.py`: **PASS (3,815/3,815)** (0 ID collisions, 100% vocab_id referential integrity, 100% lesson/segment hierarchy integrity, 100% original_example_hash exact baseline match, 100% target headword presence).
- **Detailed Report**: [LEARN-HSK46-VI-001.md](file:///C:/Users/phama/.gemini/antigravity/worktrees/hi_chinese/thread_2_learning/docs/agent-coordination/reports/thread-2/LEARN-HSK46-VI-001.md).

---

## 6. Latest Deliverables: Task LEARN-HSK46-VI-002 (Post-Ingestion Validation & Bilingual Acceptance)

- **Execution Mode**: **Read-Only Post-Ingestion Validation** (0 production file modifications).
- **Validation Verdict**: **PASS WITH WARNINGS** (Ingested subset 100% verified; 3 Correction Requests logged).
- **Audit Deliverables in `audit/hsk46_vi_enrichment/post_ingestion/`**:
  - `bilingual_quality_report.json`: Line-by-line quality audit of 50 applied candidates (100% PASS).
  - `sense_alignment_report.json`: Proof of 100% sense alignment between sentence usage and lexical sense.
  - `pinyin_validation_report.json`: Verified tone sandhi, neutral tones, and punctuation spacing normalization.
  - `identity_preservation_report.json`: Proof of zero identity shifts (116 lessons, 696 segments, 4,401 vocabularies preserved).
  - `source_provenance_report.json`: Verification of license gate compliance and zero unauthorized source leakage.
  - `unresolved_corrections.json`: Registry of `CORR-HSK5-001` (简历), `CORR-HSK4-001` (polyphones), and `CORR-HSK6-001` (575 missing examples).
  - `final_pedagogy_acceptance.md`: Official acceptance certificate.
- **Content Coverage Balance Sheet**:
  - 50 Applied Candidates: 100% verified and accepted.
  - 2,340 English Gloss Sentences: Documented in baseline balance sheet.
  - 3,764 Pending Review Candidates: Safely quarantined in staging.
  - 575 Missing Curriculum Examples: Escalated to Project Owner for professional curriculum authoring.
- **Detailed Report**: [LEARN-HSK46-VI-002.md](file:///C:/Users/phama/.gemini/antigravity/worktrees/hi_chinese/thread_2_learning/docs/agent-coordination/reports/thread-2/LEARN-HSK46-VI-002.md).

---

## 7. Latest Deliverables: Task TASK-T2-006 (Onboarding Download Interceptor & Flow Lifecycle)

- **Execution Scope**:
  1. **Onboarding Download Interceptor (HSK 3+)**:
     - Check `isHskLevelInstalledProvider(currentHsk)` when learner finishes personalization or placement test with `currentHsk >= 3`.
     - Standardized Pedagogical Interceptor Dialog:
       - **Tiêu đề:** `"Bạn đã sẵn sàng học HSK $currentHsk!"`
       - **Nội dung:** `"Để học ngay giáo trình và từ vựng chuẩn HSK $currentHsk, ứng dụng cần tải gói học liệu (~350KB - 1.5MB). Bạn muốn tải ngay bây giờ không?"`
       - **Nút hành động 1:** `"Tải ngay & Bắt đầu"` -> Kích hoạt tải gói từ CDN GitHub / asset fallback với hộp thoại tiến trình trực quan.
       - **Nút hành động 2:** `"Để sau"` -> Vẫn lưu cấu hình HSK đã chọn, điều hướng sang Lộ trình kèm SnackBar chỉ dẫn trực quan.
  2. **Chuẩn hóa vòng đời `LessonFlowNotifier`**:
     - Chuyển `lessonFlowNotifierProvider` sang `autoDispose`.
     - Bổ sung `resetToStep(LessonStep step)`.
     - Đảm bảo mở bất kỳ bài học nào luôn khởi động tại Chặng 1 (`LessonStep.warmup`), trừ khi người dùng chủ động chọn `Tiếp tục` (truyền `resumeStep`).
- **Test Gate**:
  - `test/features/curriculum/lesson_flow_providers_test.dart`: 9/9 PASS.
  - `test/features/onboarding/onboarding_download_interceptor_test.dart`: 3/3 PASS.
  - `test/features/onboarding/onboarding_flow_test.dart`: 6/6 PASS.
  - `flutter analyze lib/`: 0 errors, 0 warnings (PASS).
- **Detailed Report**: [TASK-T2-006-ONBOARDING-DOWNLOAD-INTERCEPTOR.md](file:///C:/Users/phama/.gemini/antigravity/worktrees/chinese/pedagogy_learning_experience/docs/agent-coordination/reports/thread-2/TASK-T2-006-ONBOARDING-DOWNLOAD-INTERCEPTOR.md).
