import 'package:sqflite/sqflite.dart';
import '../database_constants.dart';
import 'migration.dart';

/// Migration v9: Adds tables for modular Content Packs, Curriculum syllabus,
/// Content Catalog (CMS), and Curriculum Mastery.
class MigrationV9 implements Migration {
  const MigrationV9();

  @override
  int get version => 9;

  @override
  String get description => 'Add content packs, curriculum hierarchy, content catalog, and mastery tables';

  @override
  Future<void> up(DatabaseExecutor db) async {
    // 1. Content Packs Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableContentPacks} (
        id TEXT PRIMARY KEY,
        hsk_level INTEGER NOT NULL,
        version TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        is_bundled INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'not_installed',
        size_bytes INTEGER NOT NULL DEFAULT 0,
        checksum_sha256 TEXT,
        installed_at TEXT,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_content_packs_level ON ${DatabaseConstants.tableContentPacks} (hsk_level);
    ''');

    // 2. Curriculums Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableCurriculums} (
        id TEXT PRIMARY KEY,
        pack_id TEXT NOT NULL,
        code TEXT NOT NULL,
        standard_name TEXT NOT NULL,
        hsk_level INTEGER NOT NULL,
        total_units INTEGER NOT NULL DEFAULT 0,
        total_lessons INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (pack_id) REFERENCES ${DatabaseConstants.tableContentPacks}(id) ON DELETE CASCADE
      );
    ''');

    // 3. Curriculum Units Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableCurriculumUnits} (
        id TEXT PRIMARY KEY,
        curriculum_id TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        title_vi TEXT NOT NULL,
        title_zh TEXT NOT NULL,
        description_vi TEXT,
        icon_name TEXT,
        is_locked INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (curriculum_id) REFERENCES ${DatabaseConstants.tableCurriculums}(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_units_curr_order ON ${DatabaseConstants.tableCurriculumUnits} (curriculum_id, order_index);
    ''');

    // 4. Curriculum Lessons Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableCurriculumLessons} (
        id TEXT PRIMARY KEY,
        unit_id TEXT NOT NULL,
        order_index INTEGER NOT NULL,
        title_vi TEXT NOT NULL,
        title_zh TEXT NOT NULL,
        pinyin TEXT NOT NULL,
        estimated_minutes INTEGER NOT NULL DEFAULT 15,
        is_locked INTEGER NOT NULL DEFAULT 1,
        unlock_score_threshold REAL NOT NULL DEFAULT 0.8,
        prerequisites_json TEXT NOT NULL DEFAULT '[]',
        status TEXT NOT NULL DEFAULT 'not_started',
        completed_at TEXT,
        credited_reason TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (unit_id) REFERENCES ${DatabaseConstants.tableCurriculumUnits}(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_lessons_unit_order ON ${DatabaseConstants.tableCurriculumLessons} (unit_id, order_index);
    ''');

    // 5. Lesson Segments Table (6 chặng sư phạm)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableLessonSegments} (
        id TEXT PRIMARY KEY,
        lesson_id TEXT NOT NULL,
        step_order INTEGER NOT NULL,
        segment_type TEXT NOT NULL,
        title TEXT NOT NULL,
        content_ref_id TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (lesson_id) REFERENCES ${DatabaseConstants.tableCurriculumLessons}(id) ON DELETE CASCADE
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_segments_lesson_order ON ${DatabaseConstants.tableLessonSegments} (lesson_id, step_order);
    ''');

    // 6. Content Items Table (CMS Catalog)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableContentItems} (
        id TEXT PRIMARY KEY,
        content_id TEXT NOT NULL UNIQUE,
        curriculum_id TEXT NOT NULL,
        hsk_level INTEGER NOT NULL,
        knowledge_type TEXT NOT NULL,
        title TEXT NOT NULL,
        content_json TEXT NOT NULL,
        objectives_json TEXT NOT NULL DEFAULT '[]',
        source_reference TEXT,
        audit_status TEXT NOT NULL DEFAULT 'verified',
        content_version TEXT NOT NULL DEFAULT '1.0.0',
        metadata_json TEXT NOT NULL DEFAULT '{}',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_content_items_lookup ON ${DatabaseConstants.tableContentItems} (hsk_level, knowledge_type);
    ''');

    // 7. Curriculum Mastery Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableCurriculumMastery} (
        id TEXT PRIMARY KEY,
        item_id TEXT NOT NULL UNIQUE,
        item_type TEXT NOT NULL,
        mastery_state TEXT NOT NULL DEFAULT 'not_started',
        score REAL NOT NULL DEFAULT 0.0,
        attempts_count INTEGER NOT NULL DEFAULT 0,
        last_attempt_at TEXT,
        due_review_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_mastery_state ON ${DatabaseConstants.tableCurriculumMastery} (mastery_state);
    ''');

    // 8. Level Exit Exams Table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseConstants.tableLevelExitExams} (
        id TEXT PRIMARY KEY,
        curriculum_id TEXT NOT NULL,
        hsk_level INTEGER NOT NULL,
        title TEXT NOT NULL,
        passing_score INTEGER NOT NULL DEFAULT 120,
        duration_minutes INTEGER NOT NULL DEFAULT 35,
        exam_data_json TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (curriculum_id) REFERENCES ${DatabaseConstants.tableCurriculums}(id) ON DELETE CASCADE
      );
    ''');
  }
}
