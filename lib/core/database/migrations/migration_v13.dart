import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'migration.dart';

/// Migration v13: Comprehensive Chinese Grammar System (HSK 1–6)
/// Integrates 428 HSK 3.0 Syllabus points (GF0025-2021) and 599 AllSet Grammar Wiki points.
/// Normalizes grammar examples into relational storage, provides taxonomy categorization,
/// and maintains strict decoupling from user learning progress.
class MigrationV13 implements Migration {
  const MigrationV13();

  @override
  int get version => 13;

  @override
  String get description =>
      'Normalize grammar_items schema with HSK 3.0 and AllSet Wiki attributes, add grammar_examples and grammar_topics tables';

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. Add enriched attributes to grammar_items
    final columnsToAdd = <String, String>{
      'grammar_id': "TEXT NOT NULL DEFAULT ''",
      'topic_category': "TEXT NOT NULL DEFAULT 'other'",
      'topic_name_vi': "TEXT NOT NULL DEFAULT ''",
      'category_chinese': "TEXT NOT NULL DEFAULT ''",
      'category_english': "TEXT NOT NULL DEFAULT ''",
      'original_level': "TEXT NOT NULL DEFAULT ''",
      'hsk_level_mapped': 'INTEGER NOT NULL DEFAULT 1',
      'mapping_basis': "TEXT NOT NULL DEFAULT ''",
      'is_reference_only': 'INTEGER NOT NULL DEFAULT 0',
      'verification_status': "TEXT NOT NULL DEFAULT 'verified_open_source'",
      'license': "TEXT NOT NULL DEFAULT ''",
      'attribution': "TEXT NOT NULL DEFAULT ''",
      'wiki_link': 'TEXT',
    };

    final tableInfo = await db.rawQuery('PRAGMA table_info(${DatabaseConstants.tableGrammarItems})');
    final existingColumns = tableInfo.map((row) => row['name'] as String).toSet();

    for (final entry in columnsToAdd.entries) {
      if (!existingColumns.contains(entry.key)) {
        await db.execute(
          'ALTER TABLE ${DatabaseConstants.tableGrammarItems} ADD COLUMN ${entry.key} ${entry.value};',
        );
      }
    }

    // 2. Create normalized grammar_examples table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableGrammarExamples} (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        grammar_id TEXT NOT NULL,
        chinese TEXT NOT NULL,
        chinese_segmented TEXT,
        pinyin TEXT,
        translation_en TEXT,
        translation_vi TEXT,
        sound_ref TEXT,
        source TEXT,
        order_index INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (grammar_id) REFERENCES ${DatabaseConstants.tableGrammarItems} (id) ON DELETE CASCADE
      );
    ''');

    // 3. Create grammar_topics taxonomy table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableGrammarTopics} (
        code TEXT PRIMARY KEY,
        name_vi TEXT NOT NULL,
        name_zh TEXT NOT NULL,
        description_vi TEXT,
        display_order INTEGER NOT NULL DEFAULT 0
      );
    ''');

    // Pre-populate canonical grammar topics
    final standardTopics = [
      {'code': 'particle', 'name_vi': 'Trợ từ (的, 地, 得, 了, 过, 着, 吗, 呢, 吧)', 'name_zh': '助词', 'description_vi': 'Trợ từ kết cấu, trợ từ động thái và trợ từ ngữ khí', 'order': 1},
      {'code': 'preposition', 'name_vi': 'Giới từ (在, 从, 往, 跟, 对, 向, 给, 离...)', 'name_zh': '介词', 'description_vi': 'Giới từ chỉ thời gian, địa điểm, phương hướng, đối tượng', 'order': 2},
      {'code': 'conjunction', 'name_vi': 'Liên từ & câu phức (虽然...但是, 因为...所以...)', 'name_zh': '连词与复句', 'description_vi': 'Liên từ kết nối và các mẫu câu phức thường gặp', 'order': 3},
      {'code': 'adverb', 'name_vi': 'Phó từ (也, 都, 很, 太, 不, 没, 就, 才, 已经...)', 'name_zh': '副词', 'description_vi': 'Phó từ chỉ mức độ, phạm vi, thời gian, phủ định và liên kết', 'order': 4},
      {'code': 'comparison', 'name_vi': 'Câu so sánh (A 比 B, 跟...一样, 越来越...)', 'name_zh': '比较句', 'description_vi': 'Các cấu trúc so sánh hơn, bằng, kém và tăng tiến', 'order': 5},
      {'code': 'conditional', 'name_vi': 'Câu điều kiện & giả thiết (如果...就, 只要...就)', 'name_zh': '条件与假设', 'description_vi': 'Biểu đạt điều kiện cần, điều kiện đủ và giả thiết tình huống', 'order': 6},
      {'code': 'passive', 'name_vi': 'Câu bị động (被, 让, 叫)', 'name_zh': '被动句', 'description_vi': 'Cấu trúc câu biểu thị ý nghĩa bị động trong tiếng Trung', 'order': 7},
      {'code': 'ba_sentence', 'name_vi': 'Câu chữ 把 (把字句)', 'name_zh': '把字句', 'description_vi': 'Mẫu câu đặc biệt xử lý tân ngữ và kết quả hành động', 'order': 8},
      {'code': 'complement', 'name_vi': 'Câu bổ ngữ (Kết quả, xu hướng, khả năng, trạng thái)', 'name_zh': '补语', 'description_vi': 'Hệ thống bổ ngữ biểu thị kết quả, thời lượng, khả năng', 'order': 9},
      {'code': 'modal_verb', 'name_vi': 'Động từ năng nguyện (会, 能, 可以, 想, 要, 应该)', 'name_zh': '能愿动词', 'description_vi': 'Động từ biểu thị năng lực, nguyện vọng, khả năng', 'order': 10},
      {'code': 'separable_verb', 'name_vi': 'Từ ly hợp (睡觉, 唱歌, 跳舞, 帮忙...)', 'name_zh': '离合词', 'description_vi': 'Quy tắc chèn bổ ngữ, lượng từ vào giữa từ ly hợp', 'order': 11},
      {'code': 'word_part', 'name_vi': 'Ngữ tố cấu từ (Tiền tố 小-/第-, Hậu tố -们/-子/-化)', 'name_zh': '语素', 'description_vi': 'Các thành phần tiền tố, hậu tố tạo từ trong tiếng Hán', 'order': 12},
      {'code': 'pronoun', 'name_vi': 'Đại từ (Nhân xưng, chỉ thị, nghi vấn)', 'name_zh': '代词', 'description_vi': 'Cách dùng đại từ và cách dùng phiếm chỉ/nhậm chỉ', 'order': 13},
      {'code': 'measure_word', 'name_vi': 'Lượng từ (Danh lượng từ, động lượng từ, trùng điệp)', 'name_zh': '量词', 'description_vi': 'Hệ thống lượng từ phong phú và quy tắc lặp lại', 'order': 14},
      {'code': 'special_sentence', 'name_vi': 'Cấu trúc câu đặc biệt (存现句, 连动句, 兼语句, 是...的)', 'name_zh': '特殊句型', 'description_vi': 'Câu tồn hiện, câu liên động, câu kiêm ngữ và nhấn mạnh', 'order': 15},
      {'code': 'other', 'name_vi': 'Cấu trúc & Cụm từ khác', 'name_zh': '其他结构', 'description_vi': 'Các định dạng biểu đạt thành ngữ, thời gian và tiền tệ', 'order': 16},
    ];

    for (final topic in standardTopics) {
      await db.insert(
        DatabaseConstants.tableGrammarTopics,
        {
          'code': topic['code'],
          'name_vi': topic['name_vi'],
          'name_zh': topic['name_zh'],
          'description_vi': topic['description_vi'],
          'display_order': topic['order'],
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    // 4. Create Indexes
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_grammar_items_topic 
      ON ${DatabaseConstants.tableGrammarItems} (topic_category);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_grammar_items_mapped_hsk 
      ON ${DatabaseConstants.tableGrammarItems} (hsk_level_mapped);
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_grammar_examples_gid 
      ON ${DatabaseConstants.tableGrammarExamples} (grammar_id);
    ''');
  }
}
