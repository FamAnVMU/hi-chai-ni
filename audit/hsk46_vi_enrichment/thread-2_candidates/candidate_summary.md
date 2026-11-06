# Staging Candidate Dataset Summary: LEARN-HSK46-VI-001

- **Generated At**: 2026-11-06T11:45:00+07:00
- **Staging Directory**: `audit/hsk46_vi_enrichment/thread-2_candidates/`
- **Curator**: Senior Chinese–Vietnamese Bilingual Corpus Curator (Thread 2)
- **Policy Enforcement**: 100% Ingestion Gated on `curator_status == 'APPROVED'`

---

## 1. Quantitative Breakdown

| Dataset File | Total Records | APPROVED | TRANSLATION_REVIEW / SENSE_REVIEW | UNRESOLVED / REJECTED |
| :--- | :---: | :---: | :---: | :---: |
| `hsk4_candidates.jsonl` | **594** | 2 | 592 | 0 |
| `hsk5_candidates.jsonl` | **1279** | 18 | 1261 | 0 |
| `hsk6_candidates.jsonl` | **1942** | 31 | 1911 | 0 |
| `rejected_candidates.jsonl` | **5** | 0 | 0 | 5 (License Gate Rejections) |
| `unresolved_mappings.jsonl` | **586** | 0 | 0 | 586 (6 polyphones + 575 missing + 5 omitted) |
| **Total Evaluated** | **4406** | **51** | **3764** | **591** |

---

## 2. Integrity Verification
- 100% of candidate records contain valid `original_example_hash` matching Thread 1's Baseline.
- Zero synthetic fake sentences generated.
- Strict license gating enforced against TED2020 (NoDerivatives), C3 (Research only / non-parallel), OpenSubtitles (Copyright risk), and StoryWeaver (Juvenile register).
- All candidates needing pedagogical human sign-off are cataloged in `human_review_required.json`.
