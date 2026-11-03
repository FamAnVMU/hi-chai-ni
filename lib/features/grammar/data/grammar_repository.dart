import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/dao/activity_dao.dart';
import '../../../../core/database/dao/learner_evidence_dao.dart';
import '../../../../core/database/database_constants.dart';
import '../domain/catalog/grammar_catalog.dart';
import '../domain/models/grammar_models.dart';

abstract class GrammarRepository {
  Future<List<GrammarTopic>> getGrammarTopics();
  Future<List<GrammarItem>> getGrammarItems({
    int? hskLevel,
    String? topicCategory,
    String? tag,
    String? query,
  });
  Future<GrammarItem?> getGrammarItemById(String id);
  Future<List<GrammarExample>> getExamplesForGrammar(String grammarId);
  Future<GrammarProgress?> getProgress(String grammarId);
  Future<Map<String, GrammarProgress>> getAllProgressMap();
  Future<void> recordStudySession({
    required String grammarId,
    required double score,
    required int durationSeconds,
    required int exercisesCount,
  });
  Future<void> importGrammarDataset(List<Map<String, dynamic>> rawItems);
}

class DefaultGrammarRepository implements GrammarRepository {
  final DatabaseExecutor _db;
  late final LearnerEvidenceDao _evidenceDao;
  late final ActivityDao _activityDao;

  DefaultGrammarRepository(this._db) {
    final db = _db;
    if (db is Database) {
      _evidenceDao = LearnerEvidenceDao(db);
      _activityDao = ActivityDao(db);
    }
  }

  /// Ensure curated catalog items exist in SQLite
  Future<void> _ensureCatalogSeeded() async {
    final count = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableGrammarItems}'),
    );

    if (count == null || count == 0) {
      try {
        final jsonStr = await rootBundle.loadString('assets/data/hsk_grammar_all.json');
        final decoded = json.decode(jsonStr) as List<dynamic>;
        final items = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        await importGrammarDataset(items);
        return;
      } catch (_) {
        // Fallback for tests or environments where rootBundle is unavailable
      }

      for (final item in GrammarCatalog.items) {
        await _db.insert(
          DatabaseConstants.tableGrammarItems,
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    }
  }

  Future<void> _ensureTopicsSeeded() async {
    try {
      final count = Sqflite.firstIntValue(
        await _db.rawQuery('SELECT COUNT(*) FROM ${DatabaseConstants.tableGrammarTopics}'),
      );
      if (count != null && count > 0) return;

      final standardTopics = [
        {
          'code': 'particle',
          'name_vi': 'Trợ từ (的, 地, 得, 了, 过, 着, 吗, 呢, 吧)',
          'name_zh': '助词',
          'description_vi': 'Trợ từ kết cấu, trợ từ động thái và trợ từ ngữ khí',
          'display_order': 1,
        },
        {
          'code': 'preposition',
          'name_vi': 'Giới từ (在, 从, 往, 跟, 对, 向, 给, 离...)',
          'name_zh': '介词',
          'description_vi': 'Giới từ chỉ thời gian, địa điểm, phương hướng, đối tượng',
          'display_order': 2,
        },
        {
          'code': 'conjunction',
          'name_vi': 'Liên từ & câu phức (虽然...但是, 因为...所以...)',
          'name_zh': '连词与复句',
          'description_vi': 'Liên từ kết nối và các mẫu câu phức thường gặp',
          'display_order': 3,
        },
        {
          'code': 'adverb',
          'name_vi': 'Phó từ (也, 都, 很, 太, 不, 没, 就, 才, 已经...)',
          'name_zh': '副词',
          'description_vi': 'Phó từ chỉ mức độ, phạm vi, thời gian, phủ định và liên kết',
          'display_order': 4,
        },
        {
          'code': 'comparison',
          'name_vi': 'Câu so sánh (A 比 B, 跟...一样, 越来越...)',
          'name_zh': '比较句',
          'description_vi': 'Các cấu trúc so sánh hơn, bằng, kém và tăng tiến',
          'display_order': 5,
        },
        {
          'code': 'conditional',
          'name_vi': 'Câu điều kiện & giả thiết (如果...就, 只要...就)',
          'name_zh': '条件与假设',
          'description_vi': 'Biểu đạt điều kiện cần, điều kiện đủ và giả thiết tình huống',
          'display_order': 6,
        },
        {
          'code': 'passive',
          'name_vi': 'Câu bị động (被, 让, 叫)',
          'name_zh': '被动句',
          'description_vi': 'Cấu trúc câu biểu thị ý nghĩa bị động trong tiếng Trung',
          'display_order': 7,
        },
        {
          'code': 'ba_sentence',
          'name_vi': 'Câu chữ 把 (把字句)',
          'name_zh': '把字句',
          'description_vi': 'Mẫu câu đặc biệt xử lý tân ngữ và kết quả hành động',
          'display_order': 8,
        },
        {
          'code': 'complement',
          'name_vi': 'Câu bổ ngữ (Kết quả, xu hướng, khả năng, trạng thái)',
          'name_zh': '补语',
          'description_vi': 'Hệ thống bổ ngữ biểu thị kết quả, thời lượng, khả năng',
          'display_order': 9,
        },
        {
          'code': 'modal_verb',
          'name_vi': 'Động từ năng nguyện (会, 能, 可以, 想, 要, 应该)',
          'name_zh': '能愿动词',
          'description_vi': 'Động từ biểu thị năng lực, nguyện vọng, khả năng',
          'display_order': 10,
        },
        {
          'code': 'separable_verb',
          'name_vi': 'Từ ly hợp (睡觉, 唱歌, 跳舞, 帮忙...)',
          'name_zh': '离合词',
          'description_vi': 'Quy tắc chèn bổ ngữ, lượng từ vào giữa từ ly hợp',
          'display_order': 11,
        },
        {
          'code': 'word_part',
          'name_vi': 'Ngữ tố cấu từ (Tiền tố 小-/第-, Hậu tố -们/-子/-化)',
          'name_zh': '语素',
          'description_vi': 'Các thành phần tiền tố, hậu tố tạo từ trong tiếng Hán',
          'display_order': 12,
        },
        {
          'code': 'pronoun',
          'name_vi': 'Đại từ (Nhân xưng, chỉ thị, nghi vấn)',
          'name_zh': '代词',
          'description_vi': 'Cách dùng đại từ và cách dùng phiếm chỉ/nhậm chỉ',
          'display_order': 13,
        },
        {
          'code': 'measure_word',
          'name_vi': 'Lượng từ (Danh lượng từ, động lượng từ, trùng điệp)',
          'name_zh': '量词',
          'description_vi': 'Hệ thống lượng từ phong phú và quy tắc lặp lại',
          'display_order': 14,
        },
        {
          'code': 'special_sentence',
          'name_vi': 'Cấu trúc câu đặc biệt (存现句, 连动句, 兼语句, 是...的)',
          'name_zh': '特殊句型',
          'description_vi': 'Câu tồn hiện, câu liên động, câu kiêm ngữ và nhấn mạnh',
          'display_order': 15,
        },
        {
          'code': 'other',
          'name_vi': 'Cấu trúc & Cụm từ khác',
          'name_zh': '其他结构',
          'description_vi': 'Các định dạng biểu đạt thành ngữ, thời gian và tiền tệ',
          'display_order': 16,
        },
      ];

      for (final topic in standardTopics) {
        await _db.insert(
          DatabaseConstants.tableGrammarTopics,
          topic,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (_) {}
  }

  @override
  Future<List<GrammarTopic>> getGrammarTopics() async {
    await _ensureCatalogSeeded();
    await _ensureTopicsSeeded();
    try {
      final rows = await _db.query(
        DatabaseConstants.tableGrammarTopics,
        orderBy: 'display_order ASC',
      );
      return rows.map((r) => GrammarTopic.fromMap(r)).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<GrammarItem>> getGrammarItems({
    int? hskLevel,
    String? topicCategory,
    String? tag,
    String? query,
  }) async {
    await _ensureCatalogSeeded();

    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];

    if (hskLevel != null) {
      whereClauses.add('(hsk_level = ? OR hsk_level_mapped = ?)');
      whereArgs.add(hskLevel);
      whereArgs.add(hskLevel);
    }

    if (topicCategory != null && topicCategory.isNotEmpty && topicCategory != 'all') {
      whereClauses.add('topic_category = ?');
      whereArgs.add(topicCategory);
    }

    final rows = await _db.query(
      DatabaseConstants.tableGrammarItems,
      where: whereClauses.isEmpty ? null : whereClauses.join(' AND '),
      whereArgs: whereArgs.isEmpty ? null : whereArgs,
      orderBy: 'hsk_level ASC, code ASC',
    );

    var items = rows.map((r) => GrammarItem.fromMap(r)).toList();

    // In-memory filter for tags & query search
    if (tag != null && tag.isNotEmpty) {
      items = items.where((it) => it.tags.contains(tag)).toList();
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.trim().toLowerCase();
      items = items.where((it) {
        return it.title.toLowerCase().contains(q) ||
            it.structure.toLowerCase().contains(q) ||
            it.meaningVi.toLowerCase().contains(q) ||
            it.explanationVi.toLowerCase().contains(q) ||
            it.usageConditionsVi.toLowerCase().contains(q) ||
            it.categoryChinese.toLowerCase().contains(q) ||
            it.tags.any((t) => t.toLowerCase().contains(q));
      }).toList();
    }

    return items;
  }

  @override
  Future<GrammarItem?> getGrammarItemById(String id) async {
    await _ensureCatalogSeeded();

    final rows = await _db.query(
      DatabaseConstants.tableGrammarItems,
      where: 'id = ? OR grammar_id = ? OR code = ?',
      whereArgs: [id, id, id],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    final item = GrammarItem.fromMap(rows.first);

    // If relational examples exist, enrich with them
    final relationalExamples = await getExamplesForGrammar(item.id);
    if (relationalExamples.isNotEmpty) {
      return GrammarItem(
        id: item.id,
        hskLevel: item.hskLevel,
        code: item.code,
        title: item.title,
        structure: item.structure,
        meaningVi: item.meaningVi,
        usageConditionsVi: item.usageConditionsVi,
        sentencePositionVi: item.sentencePositionVi,
        explanationVi: item.explanationVi,
        source: item.source,
        grammarId: item.grammarId,
        topicCategory: item.topicCategory,
        topicNameVi: item.topicNameVi,
        categoryChinese: item.categoryChinese,
        categoryEnglish: item.categoryEnglish,
        originalLevel: item.originalLevel,
        hskLevelMapped: item.hskLevelMapped,
        mappingBasis: item.mappingBasis,
        isReferenceOnly: item.isReferenceOnly,
        verificationStatus: item.verificationStatus,
        license: item.license,
        attribution: item.attribution,
        wikiLink: item.wikiLink,
        tags: item.tags,
        relatedVocabIds: item.relatedVocabIds,
        relatedGrammarIds: item.relatedGrammarIds,
        prerequisiteGrammarIds: item.prerequisiteGrammarIds,
        examples: relationalExamples,
        contrastiveExamples: item.contrastiveExamples,
        exercises: item.exercises,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      );
    }

    return item;
  }

  @override
  Future<List<GrammarExample>> getExamplesForGrammar(String grammarId) async {
    try {
      final rows = await _db.query(
        DatabaseConstants.tableGrammarExamples,
        where: 'grammar_id = ?',
        whereArgs: [grammarId],
        orderBy: 'order_index ASC',
      );
      return rows.map((r) => GrammarExample.fromMap(r)).toList();
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<GrammarProgress?> getProgress(String grammarId) async {
    final rows = await _db.query(
      DatabaseConstants.tableGrammarProgress,
      where: 'grammar_id = ?',
      whereArgs: [grammarId],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return GrammarProgress.fromMap(rows.first);
  }

  @override
  Future<Map<String, GrammarProgress>> getAllProgressMap() async {
    final rows = await _db.query(DatabaseConstants.tableGrammarProgress);
    final map = <String, GrammarProgress>{};
    for (final r in rows) {
      final progress = GrammarProgress.fromMap(r);
      map[progress.grammarId] = progress;
    }
    return map;
  }

  @override
  Future<void> recordStudySession({
    required String grammarId,
    required double score,
    required int durationSeconds,
    required int exercisesCount,
  }) async {
    if (exercisesCount <= 0) return;

    final item = await getGrammarItemById(grammarId);
    if (item == null) return;

    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final clampedScore = score.clamp(0.0, 1.0);
    final newStatus = clampedScore >= 0.8
        ? GrammarProgressStatus.mastered
        : GrammarProgressStatus.learning;

    final existingProgress = await getProgress(grammarId);
    final totalExercises = (existingProgress?.exercisesCompleted ?? 0) + exercisesCount;

    Future<void> executeWithDb(dynamic executor) async {
      await executor.insert(
        DatabaseConstants.tableGrammarProgress,
        {
          'id': existingProgress?.id ?? 'gp_${grammarId}_${DateTime.now().millisecondsSinceEpoch}',
          'grammar_id': grammarId,
          'hsk_level': item.hskLevel,
          'status': newStatus.name,
          'mastery_score': clampedScore,
          'exercises_completed': totalExercises,
          'last_studied_at': nowUtc,
          'created_at': existingProgress?.createdAt.toUtc().toIso8601String() ?? nowUtc,
          'updated_at': nowUtc,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      final evidenceId = 'ev_grm_${DateTime.now().microsecondsSinceEpoch}';
      if (_db is Database) {
        await _evidenceDao.appendEvidence(
          {
            'id': evidenceId,
            'content_id': grammarId,
            'content_type': 'grammar',
            'source': 'grammar_practice',
            'score': clampedScore,
            'duration_ms': durationSeconds * 1000,
            'metadata_json': json.encode({
              'grammar_title': item.title,
              'hsk_level': item.hskLevel,
              'exercises_evaluated': exercisesCount,
            }),
            'created_at': nowUtc,
          },
          txn: executor is Transaction ? executor : null,
        );

        final activityId = 'act_grm_${DateTime.now().microsecondsSinceEpoch}';
        await _activityDao.logActivity(
          {
            'id': activityId,
            'activity_type': 'grammar',
            'duration_seconds': durationSeconds,
            'items_count': exercisesCount,
            'activity_date': nowUtc.substring(0, 10),
            'created_at': nowUtc,
          },
          txn: executor is Transaction ? executor : null,
        );
      }
    }

    final db = _db;
    if (db is Database) {
      await db.transaction((txn) async {
        await executeWithDb(txn);
      });
    } else {
      await executeWithDb(_db);
    }
  }

  @override
  Future<void> importGrammarDataset(List<Map<String, dynamic>> rawItems) async {
    final nowUtc = DateTime.now().toUtc().toIso8601String();

    Future<void> performImport(dynamic executor) async {
      for (final raw in rawItems) {
        final item = GrammarItem.fromMap(raw);
        await executor.insert(
          DatabaseConstants.tableGrammarItems,
          item.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Also normalize examples into tableGrammarExamples
        if (item.examples.isNotEmpty) {
          int order = 0;
          for (final ex in item.examples) {
            await executor.insert(
              DatabaseConstants.tableGrammarExamples,
              {
                'grammar_id': item.id,
                'chinese': ex.hanzi,
                'chinese_segmented': ex.chineseSegmented,
                'pinyin': ex.pinyin,
                'translation_en': ex.translationEn,
                'translation_vi': ex.translationVi,
                'sound_ref': ex.audioUri,
                'source': ex.source ?? item.source,
                'order_index': order++,
                'created_at': nowUtc,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
        }
      }
    }

    final db = _db;
    if (db is Database) {
      await db.transaction((txn) async {
        await performImport(txn);
      });
    } else {
      await performImport(_db);
    }
  }
}
