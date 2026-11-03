# F14: Secure Python Data Pipeline & Remove Machine-Specific Paths

## 1. Executive Summary
This document records the security audit, remediation, and architectural enhancements applied to the Python offline data pipeline (`data_pipeline/`) of the HI Chinese project.

Previously:
- Multiple scripts in `data_pipeline/` suppressed TLS certificate validation (`ctx.verify_mode = ssl.CERT_NONE`, `ctx.check_hostname = False`), introducing critical vulnerabilities to Man-in-the-Middle (MitM) attacks.
- 14 locations hardcoded machine-specific absolute file paths (`C:\Users\phama\Downloads\hi_chinese`), preventing the pipeline from running on other developer workstations, Linux servers, or CI/CD runners.

All certificate bypasses have been eradicated. A centralized, secure, cross-platform configuration module (`data_pipeline/pipeline_config.py`) was introduced to resolve paths dynamically using `pathlib.Path` relative to the project root, support environment variable overrides, and enforce strict TLS verification with custom CA bundle support.

---

## 2. Security Findings & Remediation

### 2.1 Elimination of SSL/TLS Verification Bypass
The following 6 scripts previously created unverified SSL contexts:
1. `download_grammar_sources.py`
2. `inspect_gushi.py`
3. `inspect_gushi_breakdown.py`
4. `inspect_gushi_data.py`
5. `inspect_sources.py`
6. `test_allset_page.py`

**Remediation Applied**:
- Removed all occurrences of `ssl.CERT_NONE` and `check_hostname = False`.
- Replaced custom insecure contexts with `pipeline_config.get_secure_ssl_context()`, which enforces `ssl.CERT_REQUIRED` and `check_hostname = True`.
- Added support for custom CA certificates via `SSL_CERT_FILE` or `REQUESTS_CA_BUNDLE` environment variables if corporate proxies require private roots.
- Provided `pipeline_config.secure_open_url()` and `pipeline_config.download_file_secure()` with standard user agents and explicit socket timeouts.

### 2.2 Removal of Machine-Specific Absolute Paths
The following 14 locations hardcoded `C:\Users\phama\Downloads\hi_chinese`:
1. `build_hanzi_dataset.py` (Line 5)
2. `build_hanzi_reports.py` (Line 4)
3. `build_hsk_vocabulary_dataset.py` (Line 171)
4. `build_sentences_dataset.py` (Line 6)
5. `build_sentences_reports.py` (Line 4)
6. `check_hanzi_coverage.py` (Lines 4-5)
7. `download_hanzi_sources.py` (Line 5)
8. `download_tatoeba_sources.py` (Line 5)
9. `generate_all_audio.py` (Line 8)
10. `test_build_tatoeba_subset.py` (Line 6)
11. `test_coverage.py` (Line 6)
12. `test_hanviet_trad.py` (Line 6)
13. `test_sentences.py` (Line 4)

**Remediation Applied**:
- Replaced all hardcoded string paths with dynamic path resolution via `data_pipeline/pipeline_config.py`:
  - `get_project_root()`: resolves dynamically via `Path(__file__).resolve().parent.parent` or `HI_CHINESE_PROJECT_ROOT`.
  - `get_data_pipeline_dir()`: resolves via `HI_CHINESE_DATA_PIPELINE_DIR` or `<root>/data_pipeline`.
  - `get_raw_dir(category)`: resolves via `HI_CHINESE_RAW_DIR` or `<pipeline>/raw/<category>`.
  - `get_processed_dir()`: resolves via `HI_CHINESE_PROCESSED_DIR` or `<pipeline>/processed`.
  - `get_reports_dir()`: resolves via `HI_CHINESE_REPORTS_DIR` or `<pipeline>/reports`.
  - `get_assets_data_dir()`: resolves via `HI_CHINESE_ASSETS_DATA_DIR` or `<root>/assets/data`.
- Automatically ensures target output directories are created using `mkdir(parents=True, exist_ok=True)`.

---

## 3. Cross-Platform Compatibility & Encoding
- **OS Portability**: Fully compatible across Windows, Linux, and macOS by relying exclusively on `pathlib.Path` instead of backslash string concatenation.
- **Character Encoding**: Verified that all Chinese characters (Simplified/Traditional), Pinyin diacritics, and Vietnamese translations are read and written using explicit `encoding="utf-8"`.

---

## 4. Test Suite & Verification Results

A dedicated automated test suite was added at `test/pipeline/test_pipeline_security.py` verifying:
1. `test_no_cert_none_in_pipeline`: Confirms 0 scripts in `data_pipeline/` contain `CERT_NONE`, `verify=False`, or `_create_unverified_context`.
2. `test_no_hardcoded_machine_specific_paths`: Confirms 0 scripts contain `C:\Users` or user home path patterns.
3. `test_project_root_detection`: Verifies project root resolves accurately to the workspace root containing `pubspec.yaml`.
4. `test_env_var_override_project_root`: Verifies project root override via environment variable.
5. `test_env_var_override_directories`: Verifies directory overrides via environment variable.
6. `test_secure_ssl_context_enforces_verification`: Confirms `CERT_REQUIRED` and `check_hostname == True`.
7. `test_bad_ssl_cert_is_rejected`: Confirms invalid / self-signed certificates (e.g. `self-signed.badssl.com`) raise SSL validation errors.
8. `test_valid_https_works_with_verification`: Confirms legitimate HTTPS downloads work cleanly under full TLS verification.
9. `test_chinese_unicode_handling`: Confirms UTF-8 serialization of Chinese and Pinyin data.

### Test Execution Summary
- Python Pipeline Security Suite: **9/9 tests PASSED** in 1.69s.
- Dart Analysis (`dart analyze lib test`): **0 issues found**.
