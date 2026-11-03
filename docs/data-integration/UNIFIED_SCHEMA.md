# HI CHINESE – UNIFIED DATABASE SCHEMA (SQLITE)
**Đặc tả Schema Cơ sở Dữ liệu Toàn diện Phiên bản 15**
*Ngày lập: 03/11/2026 | Phiên bản: 1.0.0 | Tác giả: Principal Software Architect & Senior Data Engineer*

---

## 1. BẢNG ĐIỀU PHỐI TRI THỨC (KNOWLEDGE REGISTRY)

```sql
CREATE TABLE knowledge_registry (
  id TEXT PRIMARY KEY,                       -- e.g. 'KNOW_VOCAB_老师_laoshi', 'KNOW_GRAM_as_a1_001'
  entity_type TEXT NOT NULL,                 -- 'vocabulary', 'grammar', 'hanzi', 'sentence'
  canonical_id TEXT NOT NULL,                -- '老师', 'as_a1_001', '学'
  hsk_level INTEGER NOT NULL,                -- 1 to 6
  title TEXT NOT NULL,                       -- Display title / label
  is_deprecated INTEGER NOT NULL DEFAULT 0,  -- 0: active, 1: deprecated
  replaced_by_id TEXT,                       -- Mapping to newer knowledge item if deprecated
  package_id TEXT,                           -- Content pack identifier
  metadata_json TEXT NOT NULL DEFAULT '{}',  -- Additional attributes
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE UNIQUE INDEX idx_knowledge_type_canonical ON knowledge_registry (entity_type, canonical_id);
CREATE INDEX idx_knowledge_hsk_level ON knowledge_registry (hsk_level);
```

---

## 2. MIỀN TỪ VỰNG VÀ TỪ ĐIỂN (VOCABULARY DOMAIN)

```sql
-- 1. Từ vựng chính
CREATE TABLE vocabularies (
  id TEXT PRIMARY KEY,                       -- e.g. 'voc_hsk1_001'
  simplified TEXT NOT NULL,                  -- '老师'
  traditional TEXT,                          -- '老師'
  pinyin TEXT NOT NULL,                      -- 'lǎo shī'
  pinyin_clean TEXT,                         -- 'laoshi'
  pinyin_numeric TEXT,                       -- 'lao3shi1'
  hanviet TEXT,                              -- 'lão sư'
  hsk_level INTEGER NOT NULL,                -- 1 to 6
  stroke_count INTEGER,                      -- Total stroke count
  radicals TEXT,                             -- Comma-separated radicals
  frequency_rank INTEGER,                    -- Frequency ranking
  audio_uri TEXT,                            -- Local/remote audio URI
  source TEXT,                               -- 'clem109;CVDICT'
  license TEXT,                              -- 'MIT / CC-BY-SA-4.0'
  verification_status TEXT DEFAULT 'verified',
  is_polyphone INTEGER DEFAULT 0,            -- 1 if multi-reading word
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT
);

CREATE INDEX idx_vocab_simplified ON vocabularies (simplified);
CREATE INDEX idx_vocab_hsk_level ON vocabularies (hsk_level);
CREATE INDEX idx_vocab_pinyin_clean ON vocabularies (pinyin_clean);
CREATE INDEX idx_vocab_hanviet ON vocabularies (hanviet);

-- 2. Nghĩa của từ vựng (hỗ trợ một từ nhiều nghĩa)
CREATE TABLE vocabulary_senses (
  id TEXT PRIMARY KEY,                       -- e.g. 'sns_voc_hsk1_001_1'
  vocabulary_id TEXT NOT NULL,               -- FK to vocabularies.id
  part_of_speech TEXT,                       -- 'noun', 'verb', 'adj'
  meaning_vi TEXT NOT NULL,                  -- Vietnamese definition
  meaning_en TEXT,                           -- English definition
  example_cn TEXT,                           -- Chinese example
  example_pinyin TEXT,                       -- Example Pinyin
  example_vi TEXT,                           -- Vietnamese translation
  example_en TEXT,                           -- English translation
  source TEXT,                               -- Source dictionary
  order_index INTEGER DEFAULT 1,             -- Ordering of senses
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  FOREIGN KEY (vocabulary_id) REFERENCES vocabularies (id) ON DELETE CASCADE
);

CREATE INDEX idx_vocab_senses_vocab_id ON vocabulary_senses (vocabulary_id);

-- 3. Ví dụ minh họa từ vựng
CREATE TABLE vocabulary_examples (
  id TEXT PRIMARY KEY,
  vocabulary_id TEXT NOT NULL,
  sense_id TEXT,
  hsk_level INTEGER NOT NULL,
  example_cn TEXT NOT NULL,
  example_pinyin TEXT NOT NULL,
  example_vi TEXT,
  example_en TEXT,
  audio_uri TEXT,
  source TEXT,
  order_index INTEGER DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (vocabulary_id) REFERENCES vocabularies (id) ON DELETE CASCADE
);

-- 4. Bảng từ điển toàn diện tra cứu Offline
CREATE TABLE dictionary_entries (
  id TEXT PRIMARY KEY,
  simplified TEXT NOT NULL,
  traditional TEXT,
  pinyin TEXT NOT NULL,
  pinyin_clean TEXT NOT NULL,
  pinyin_numeric TEXT,
  hanviet TEXT,
  hsk_level INTEGER DEFAULT 0,
  senses_json TEXT NOT NULL,                 -- JSON array of senses
  source TEXT NOT NULL,
  is_custom INTEGER DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX idx_dict_simplified ON dictionary_entries (simplified);
CREATE INDEX idx_dict_pinyin_clean ON dictionary_entries (pinyin_clean);
CREATE INDEX idx_dict_hanviet ON dictionary_entries (hanviet);
```

---

## 3. MIỀN NGỮ PHÁP (GRAMMAR DOMAIN)

```sql
-- 1. Điểm ngữ pháp chuẩn hóa
CREATE TABLE grammar_items (
  id TEXT PRIMARY KEY,                       -- e.g. 'gram_as_a1_001'
  grammar_id TEXT NOT NULL,                  -- Code slug
  title TEXT NOT NULL,                       -- Grammar title
  structure TEXT NOT NULL,                   -- Pattern / formula
  explanation_vi TEXT NOT NULL,              -- Detailed explanation
  topic_category TEXT NOT NULL DEFAULT 'other', -- e.g. 'particle', 'comparison'
  topic_name_vi TEXT NOT NULL DEFAULT '',
  category_chinese TEXT NOT NULL DEFAULT '',
  category_english TEXT NOT NULL DEFAULT '',
  original_level TEXT NOT NULL DEFAULT '',   -- Original level from source ('A1', 'B2', 'HSK 1')
  hsk_level_mapped INTEGER NOT NULL DEFAULT 1, -- Mapped HSK level 1 to 6
  mapping_basis TEXT NOT NULL DEFAULT '',
  is_reference_only INTEGER NOT NULL DEFAULT 0,
  verification_status TEXT NOT NULL DEFAULT 'verified_open_source',
  license TEXT NOT NULL DEFAULT '',
  attribution TEXT NOT NULL DEFAULT '',
  wiki_link TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_grammar_hsk_level ON grammar_items (hsk_level_mapped);
CREATE INDEX idx_grammar_topic ON grammar_items (topic_category);

-- 2. Ví dụ ngữ pháp
CREATE TABLE grammar_examples (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  grammar_id TEXT NOT NULL,                  -- FK to grammar_items.id
  chinese TEXT NOT NULL,
  chinese_segmented TEXT,
  pinyin TEXT,
  translation_en TEXT,
  translation_vi TEXT,
  sound_ref TEXT,
  source TEXT,
  order_index INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  FOREIGN KEY (grammar_id) REFERENCES grammar_items (id) ON DELETE CASCADE
);

CREATE INDEX idx_grammar_examples_item ON grammar_examples (grammar_id);

-- 3. Phân loại chủ đề ngữ pháp
CREATE TABLE grammar_topics (
  code TEXT PRIMARY KEY,                     -- e.g. 'particle', 'verb_predicate'
  name_vi TEXT NOT NULL,
  name_zh TEXT NOT NULL,
  description_vi TEXT,
  display_order INTEGER NOT NULL DEFAULT 0
);
```

---

## 4. MIỀN CHỮ HÁN & THỨ TỰ NÉT (CHARACTER DOMAIN)

```sql
-- 1. Chữ Hán và dữ liệu đường nét vector
CREATE TABLE hanzi_characters (
  id TEXT PRIMARY KEY,                       -- e.g. 'char_674e'
  character TEXT NOT NULL UNIQUE,            -- '学'
  stroke_count INTEGER NOT NULL,             -- Total strokes
  hsk_level INTEGER NOT NULL DEFAULT 1,      -- 1 to 6
  all_hsk_levels TEXT,                       -- Comma-separated levels
  pinyin TEXT,                               -- 'xué'
  hanviet TEXT,                              -- 'học'
  meaning_vi TEXT,                           -- Meaning in Vietnamese
  definition_en TEXT,                        -- Meaning in English
  radical TEXT,                              -- Radical character
  decomposition TEXT,                        -- Ideographic decomposition
  strokes_json TEXT NOT NULL,                -- Array of SVG d path strings
  medians_json TEXT NOT NULL,                -- Array of coordinate median lines
  sample_words_json TEXT,                    -- Array of common vocabulary containing this char
  is_supported INTEGER NOT NULL DEFAULT 1,
  source TEXT NOT NULL DEFAULT 'Make Me a Hanzi',
  license TEXT NOT NULL DEFAULT 'Arphic Public License / OFL',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_hanzi_char ON hanzi_characters (character);
CREATE INDEX idx_hanzi_hsk ON hanzi_characters (hsk_level);

-- 2. Tiến độ luyện viết chữ Hán của người học
CREATE TABLE hanzi_writing_progress (
  id TEXT PRIMARY KEY,
  character TEXT NOT NULL UNIQUE,            -- Character practiced
  accuracy_score REAL NOT NULL DEFAULT 0.0,  -- 0.0 to 100.0
  strokes_mastered INTEGER NOT NULL DEFAULT 0,
  stroke_order_errors INTEGER NOT NULL DEFAULT 0,
  attempts_count INTEGER NOT NULL DEFAULT 0,
  last_practiced_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  history_json TEXT NOT NULL DEFAULT '[]'
);
```

---

## 5. MIỀN CÂU VÍ DỤ & ÂM THANH (SENTENCE & AUDIO DOMAIN)

```sql
-- 1. Kho câu ví dụ
CREATE TABLE sentences (
  id TEXT PRIMARY KEY,                       -- 'tat_100123' or 'sent_hsk1_001'
  chinese TEXT NOT NULL,                     -- Chinese text
  traditional TEXT,                          -- Traditional Chinese
  pinyin TEXT NOT NULL,                      -- Pinyin with accents
  pinyin_numbered TEXT,                      -- Pinyin numbered
  translation_vi TEXT,                       -- Vietnamese translation
  translation_en TEXT,                       -- English translation
  translation_vi_source TEXT NOT NULL DEFAULT 'verified',
  hsk_level INTEGER NOT NULL DEFAULT 1,      -- 1 to 6
  hsk_level_basis TEXT NOT NULL DEFAULT 'exact_match',
  tokens_json TEXT,                          -- Tokenized word objects with POS and meanings
  matched_vocab_ids_json TEXT,               -- Array of matched vocabulary IDs
  grammar_tags_json TEXT,                    -- Array of grammar tags appearing in sentence
  topic TEXT NOT NULL DEFAULT 'general',     -- Sentence topic
  contributor TEXT,                          -- Native contributor name
  source TEXT NOT NULL DEFAULT 'Tatoeba Project',
  license TEXT NOT NULL DEFAULT 'CC BY 2.0 FR',
  has_human_audio INTEGER NOT NULL DEFAULT 0,
  has_tts_fallback INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_sentences_hsk ON sentences (hsk_level);
CREATE INDEX idx_sentences_audio ON sentences (has_human_audio);

-- 2. Quản lý âm thanh đa nguồn cho câu
CREATE TABLE sentence_audio (
  id TEXT PRIMARY KEY,                       -- Audio identifier
  sentence_id TEXT NOT NULL,                 -- FK to sentences.id
  audio_type TEXT NOT NULL,                  -- 'humanRecording', 'nativeOsTts', 'studioSimulation'
  speaker_name TEXT,                         -- e.g. 'LeviHighway'
  license_type TEXT,                         -- 'CC BY-NC 4.0', 'CC BY-SA 3.0'
  url_remote TEXT,                           -- Direct remote download link
  local_path TEXT,                           -- Cached local path
  is_downloaded INTEGER DEFAULT 0,           -- 1 if stored offline
  duration_ms INTEGER,                       -- Duration in milliseconds
  sha256 TEXT,                               -- File integrity hash
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (sentence_id) REFERENCES sentences (id) ON DELETE CASCADE
);

CREATE INDEX idx_sentence_audio_sent ON sentence_audio (sentence_id);

-- 3. Tiến độ luyện nghe và Shadowing của người học
CREATE TABLE sentence_practice_progress (
  id TEXT PRIMARY KEY,
  sentence_id TEXT NOT NULL UNIQUE,          -- FK to sentences.id
  listening_attempts INTEGER DEFAULT 0,
  shadowing_attempts INTEGER DEFAULT 0,
  reading_attempts INTEGER DEFAULT 0,
  last_score REAL DEFAULT 0.0,
  best_score REAL DEFAULT 0.0,
  last_recorded_path TEXT,                   -- Path to user voice recording
  last_practiced_at INTEGER,
  next_review_at INTEGER,
  interval_days INTEGER DEFAULT 1,
  ease_factor REAL DEFAULT 2.5,
  FOREIGN KEY (sentence_id) REFERENCES sentences (id) ON DELETE CASCADE
);
```

---

## 6. MIỀN TIẾN ĐỘ HỌC TẬP VÀ SRS (LEARNER PROGRESS DOMAIN)

```sql
-- 1. Bằng chứng học tập bất biến (Append-only)
CREATE TABLE learner_evidence (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  knowledge_id TEXT NOT NULL,                -- FK to knowledge_registry.id
  activity_id TEXT NOT NULL,
  activity_type TEXT NOT NULL,               -- 'flashcard', 'writing', 'listening', 'shadowing', 'exercise'
  score REAL NOT NULL,                       -- 0.0 to 1.0
  confidence REAL NOT NULL DEFAULT 1.0,
  duration_ms INTEGER NOT NULL DEFAULT 0,
  metadata_json TEXT NOT NULL DEFAULT '{}',
  created_at TEXT NOT NULL
);

CREATE INDEX idx_evidence_knowledge ON learner_evidence (knowledge_id);
CREATE INDEX idx_evidence_user_time ON learner_evidence (user_id, created_at);

-- 2. Trạng thái thuần thục của người học (Mastery State)
CREATE TABLE mastery_snapshots (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  knowledge_id TEXT NOT NULL,                -- FK to knowledge_registry.id
  mastery_state TEXT NOT NULL,               -- 'unseen', 'exposed', 'learning', 'proficient', 'mastered'
  mastery_score REAL NOT NULL DEFAULT 0.0,
  stability REAL NOT NULL DEFAULT 1.0,
  difficulty REAL NOT NULL DEFAULT 2.5,
  last_activity_at TEXT,
  next_review_due TEXT,
  updated_at TEXT NOT NULL
);

CREATE UNIQUE INDEX idx_mastery_user_knowledge ON mastery_snapshots (user_id, knowledge_id);

-- 3. Mục ôn tập ngắt quãng (Spaced Repetition System)
CREATE TABLE srs_items (
  id TEXT PRIMARY KEY,
  knowledge_id TEXT NOT NULL,                -- FK to knowledge_registry.id
  item_type TEXT NOT NULL,                   -- 'vocabulary', 'grammar', 'hanzi', 'sentence'
  interval_days INTEGER NOT NULL DEFAULT 1,
  ease_factor REAL NOT NULL DEFAULT 2.5,
  repetitions INTEGER NOT NULL DEFAULT 0,
  last_reviewed_at TEXT,
  due_date TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX idx_srs_due ON srs_items (due_date);
```
