import 'dart:convert';
import 'dart:math' as math;
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/dao/dao_utils.dart';
import '../../../core/database/database_constants.dart';
import '../../curriculum/data/placement_unlock_handler.dart';
import '../../curriculum/domain/models/content_pack_models.dart';

class ContentPackManagerException implements Exception {
  final String message;
  final String packId;
  const ContentPackManagerException(this.message, {this.packId = ''});

  @override
  String toString() => 'ContentPackManagerException($packId): $message';
}

Map<String, dynamic> _parseContentPackJson(String jsonString) {
  return json.decode(jsonString) as Map<String, dynamic>;
}

class ContentPackManager {
  final DatabaseExecutor _db;
  static const String currentAppVersion = '1.0.13';
  static const int currentSupportedSchemaVersion = 2;

  const ContentPackManager(this._db);

  static Future<void> _safeUpsert(
    DatabaseExecutor executor,
    String table,
    Map<String, dynamic> values, {
    String primaryKey = 'id',
  }) async {
    final pkVal = values[primaryKey];
    if (pkVal != null) {
      final existing = await executor.query(
        table,
        columns: [primaryKey],
        where: '$primaryKey = ?',
        whereArgs: [pkVal],
        limit: 1,
      );
      if (existing.isNotEmpty) {
        await executor.update(
          table,
          values,
          where: '$primaryKey = ?',
          whereArgs: [pkVal],
        );
        return;
      }
    }
    await executor.insert(table, values, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  static String computeChecksum(String rawJson) {
    try {
      final decoded = json.decode(rawJson);
      if (decoded is Map<String, dynamic>) {
        final manifest = decoded['manifest'];
        if (manifest is Map<String, dynamic> && manifest.containsKey('sha256') && (manifest['sha256'] as String).isNotEmpty) {
          final normalizedManifest = Map<String, dynamic>.from(manifest);
          normalizedManifest['sha256'] = '';
          final copy = Map<String, dynamic>.from(decoded);
          copy['manifest'] = normalizedManifest;
          return sha256.convert(utf8.encode(json.encode(copy))).toString();
        }
      }
    } catch (_) {}
    return sha256.convert(utf8.encode(rawJson)).toString();
  }

  /// Compares two semver strings (e.g., '1.0.6' vs '1.0.0').
  /// Returns true if appVersion >= minRequiredVersion.
  static bool isAppVersionSatisfied(String minRequiredVersion, String appVersion) {
    try {
      final minParts = minRequiredVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final appParts = appVersion.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      while (minParts.length < 3) {
        minParts.add(0);
      }
      while (appParts.length < 3) {
        appParts.add(0);
      }

      for (int i = 0; i < 3; i++) {
        if (appParts[i] > minParts[i]) return true;
        if (appParts[i] < minParts[i]) return false;
      }
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Validates schema version, minimum app version, checksum, and dependency requirements.
  Future<void> validateManifest(
    ContentPackManifest manifest, {
    String? rawJson,
    DatabaseExecutor? executor,
  }) async {
    final exec = executor ?? _db;

    if (manifest.packId.trim().isEmpty) {
      throw const ContentPackManagerException('Manifest thiếu định danh pack_id hợp lệ.');
    }

    // 1. Schema version check
    if (manifest.schemaVersion > currentSupportedSchemaVersion) {
      throw ContentPackManagerException(
        'Phiên bản schema gói học liệu (${manifest.schemaVersion}) vượt quá phiên bản app hỗ trợ ($currentSupportedSchemaVersion). Vui lòng cập nhật ứng dụng.',
        packId: manifest.packId,
      );
    }

    // 2. Minimum app version check
    if (!isAppVersionSatisfied(manifest.minimumAppVersion, currentAppVersion)) {
      throw ContentPackManagerException(
        'Gói học liệu yêu cầu phiên bản ứng dụng tối thiểu ${manifest.minimumAppVersion}, hiện tại là $currentAppVersion. Vui lòng cập nhật app.',
        packId: manifest.packId,
      );
    }

    if (rawJson != null && manifest.sha256.isNotEmpty) {
      final actualSha = computeChecksum(rawJson);
      if (actualSha.toLowerCase() != manifest.sha256.toLowerCase()) {
        throw ContentPackManagerException(
          'Mã băm SHA-256 không hợp lệ (kỳ vọng: ${manifest.sha256}, thực tế: $actualSha). Dữ liệu có thể bị hư hỏng.',
          packId: manifest.packId,
        );
      }
    }

    // 4. Dependency checks
    if (manifest.dependencies.isNotEmpty) {
      final placeholders = List.filled(manifest.dependencies.length, '?').join(',');
      final installedDeps = await exec.query(
        DatabaseConstants.tableContentPacks,
        columns: ['id', 'status'],
        where: 'id IN ($placeholders) AND status IN (\'installed\', \'bundled\')',
        whereArgs: manifest.dependencies,
      );

      final installedIds = installedDeps.map((r) => r['id'] as String).toSet();
      final missingDeps = manifest.dependencies.where((dep) => !installedIds.contains(dep)).toList();

      if (missingDeps.isNotEmpty) {
        throw ContentPackManagerException(
          'Thiếu các gói phụ thuộc bắt buộc: ${missingDeps.join(', ')}. Vui lòng cài đặt trước.',
          packId: manifest.packId,
        );
      }
    }
  }

  /// Installs or upgrades a content pack with atomic transaction staging.
  /// Guarantees:
  /// - Automatic rollback upon validation/parsing error with 0 corrupted state.
  /// - Full normalization into vocabularies, senses, grammar_items, and knowledge_registry.
  /// - Relational mapping into lesson_knowledge_items.
  /// - Complete preservation of all user progress (curriculum_mastery, srs_items, learner_evidence, etc.).
  Future<ContentPackInstallResult> installOrUpdatePack(
    String rawJson, {
    bool isBundled = false,
  }) async {
    try {
      final Map<String, dynamic> decoded;
      if (rawJson.length > 256 * 1024) {
        decoded = await compute(_parseContentPackJson, rawJson);
      } else {
        decoded = json.decode(rawJson) as Map<String, dynamic>;
      }
      final manifestMap = decoded['manifest'] as Map<String, dynamic>? ?? {};
      final manifest = ContentPackManifest.fromJson(manifestMap);

      int totalLessons = 0;
      int totalContentItems = 0;
      int totalKnowledgeItems = 0;
      bool skippedAlreadyInstalled = false;

      final curriculumMap = decoded['curriculum'] as Map<String, dynamic>?;
      final contentItemsList = decoded['content_items'] as List<dynamic>? ?? [];
      final exitExamMap = decoded['exit_exam'] as Map<String, dynamic>?;
      final idMappingsList = decoded['id_mappings'] as List<dynamic>? ?? [];

      Future<void> executeInTransaction(DatabaseExecutor txn) async {
        await validateManifest(manifest, rawJson: rawJson, executor: txn);

        final contentItemIds = contentItemsList
            .map((item) => (item as Map<String, dynamic>)['content_id'] as String?)
            .whereType<String>()
            .toSet();

        if (curriculumMap != null) {
          final units = curriculumMap['units'] as List<dynamic>? ?? [];
          for (final u in units) {
            final uMap = u as Map<String, dynamic>;
            final lessons = uMap['lessons'] as List<dynamic>? ?? [];
            for (final l in lessons) {
              final lMap = l as Map<String, dynamic>;
              final segments = lMap['segments'] as List<dynamic>? ?? [];
              for (final s in segments) {
                final sMap = s as Map<String, dynamic>;
                final refId = sMap['content_ref_id'] as String?;
                if (refId != null && refId.isNotEmpty && !contentItemIds.contains(refId)) {
                  throw ContentPackManagerException(
                    'Lỗi toàn vẹn tham chiếu gói học liệu: Segment "${sMap['id']}" tham chiếu content_ref_id "$refId" không tồn tại trong content_items.',
                    packId: manifest.packId,
                  );
                }
              }
            }
          }
        }

        final nowUtc = DateTime.now().toUtc().toIso8601String();

        // 1. Check if pack is already installed
        final existingPack = await txn.query(
          DatabaseConstants.tableContentPacks,
          where: 'id = ?',
          whereArgs: [manifest.packId],
          limit: 1,
        );
        final isUpgrade = existingPack.isNotEmpty;

        // Early Idempotency Check: if pack with same version is already installed/bundled
        // and curriculum records exist in DB, skip re-importing.
        if (isUpgrade &&
            existingPack.first['version'] == manifest.version &&
            (existingPack.first['status'] == 'installed' || existingPack.first['status'] == 'bundled')) {
          final targetCurr = curriculumMap?['id'] as String? ?? 'curr_${manifest.packId}';
          final countRes = await txn.rawQuery(
            'SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tableCurriculums} WHERE id = ?',
            [targetCurr],
          );
          final cnt = Sqflite.firstIntValue(countRes) ?? 0;
          if (cnt > 0) {
            final lessonsRes = await txn.rawQuery(
              'SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tableCurriculumLessons} WHERE unit_id IN (SELECT id FROM ${DatabaseConstants.tableCurriculumUnits} WHERE curriculum_id = ?)',
              [targetCurr],
            );
            totalLessons = Sqflite.firstIntValue(lessonsRes) ?? 0;
            final contentRes = await txn.rawQuery(
              'SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tableContentItems} WHERE curriculum_id = ?',
              [targetCurr],
            );
            totalContentItems = Sqflite.firstIntValue(contentRes) ?? 0;
            skippedAlreadyInstalled = true;
            debugPrint('[ContentPackManager] Pack "${manifest.packId}" v${manifest.version} already installed ($totalLessons lessons, $totalContentItems items). Skipping re-import.');
            return;
          }
        }

        // 2. Upsert Content Pack metadata
        final packStatus = isBundled ? 'bundled' : 'installed';
        await _safeUpsert(
          txn,
          DatabaseConstants.tableContentPacks,
          manifest.toMap(status: packStatus, installedAt: isUpgrade ? (existingPack.first['installed_at'] as String?) : nowUtc),
        );

        // 3. Process Content ID Mappings (for schema migrations/renames)
        for (final mapping in idMappingsList) {
          if (mapping is! Map<String, dynamic>) continue;
          final oldId = mapping['old_id'] as String? ?? '';
          final newId = mapping['new_id'] as String? ?? '';
          final type = mapping['mapping_type'] as String? ?? 'replaced_by';
          if (oldId.isNotEmpty && newId.isNotEmpty) {
            await _safeUpsert(
              txn,
              DatabaseConstants.tableContentIdMappings,
              {
                'id': 'map_${oldId}_$newId',
                'old_id': oldId,
                'new_id': newId,
                'mapping_type': type,
                'package_id': manifest.packId,
                'notes': mapping['notes'] as String?,
                'created_at': nowUtc,
              },
            );
          }
        }

        // 4. Upsert Curriculum Syllabus
        String? curriculumId;
        final refToLessons = <String, List<String>>{};

        if (curriculumMap != null) {
          curriculumId = curriculumMap['id'] as String? ?? 'curr_${manifest.packId}';
          final unitsList = curriculumMap['units'] as List<dynamic>? ?? [];

          for (final u in unitsList) {
            final lessons = (u as Map<String, dynamic>)['lessons'] as List<dynamic>? ?? [];
            totalLessons += lessons.length;
          }

          await _safeUpsert(
            txn,
            DatabaseConstants.tableCurriculums,
            {
              'id': curriculumId,
              'pack_id': manifest.packId,
              'code': curriculumMap['code'] as String? ?? 'HSK_${manifest.hskLevel}',
              'standard_name': curriculumMap['standard_name'] as String? ?? 'HSK Level ${manifest.hskLevel}',
              'hsk_level': manifest.hskLevel,
              'total_units': unitsList.length,
              'total_lessons': totalLessons,
              'created_at': nowUtc,
            },
          );

          // Units & Lessons & Segments (preloaded & batched for PERF-05)
          final allUnitIds = <String>[];
          final allLessonIds = <String>[];
          final allSegmentIds = <String>[];
          for (final u in unitsList) {
            final uMap = u as Map<String, dynamic>;
            allUnitIds.add(uMap['id'] as String);
            for (final l in (uMap['lessons'] as List<dynamic>? ?? [])) {
              final lMap = l as Map<String, dynamic>;
              allLessonIds.add(lMap['id'] as String);
              for (final s in (lMap['segments'] as List<dynamic>? ?? [])) {
                allSegmentIds.add((s as Map<String, dynamic>)['id'] as String);
              }
            }
          }

          final existingUnits = await _queryExistingMap(
            txn,
            DatabaseConstants.tableCurriculumUnits,
            ['id', 'is_locked'],
            'id',
            allUnitIds,
          );
          final existingLessons = await _queryExistingMap(
            txn,
            DatabaseConstants.tableCurriculumLessons,
            ['id', 'status', 'is_locked', 'completed_at', 'credited_reason'],
            'id',
            allLessonIds,
          );
          final existingSegments = await _queryExistingIds(
            txn,
            DatabaseConstants.tableLessonSegments,
            'id',
            allSegmentIds,
          );

          final syllabusBatch = txn.batch();
          for (final u in unitsList) {
            final uMap = u as Map<String, dynamic>;
            final unitId = uMap['id'] as String;
            final existingUnit = existingUnits[unitId];
            int isLocked = (uMap['is_locked'] == false || uMap['is_locked'] == 0) ? 0 : 1;
            if (existingUnit != null) {
              isLocked = (existingUnit['is_locked'] as num?)?.toInt() ?? isLocked;
            }
            final unitValues = {
              'id': unitId,
              'curriculum_id': curriculumId,
              'order_index': (uMap['order_index'] as num?)?.toInt() ?? 1,
              'title_vi': uMap['title_vi'] as String? ?? '',
              'title_zh': uMap['title_zh'] as String? ?? '',
              'description_vi': uMap['description_vi'] as String?,
              'icon_name': uMap['icon_name'] as String?,
              'is_locked': isLocked,
              'created_at': nowUtc,
            };
            if (existingUnit != null) {
              syllabusBatch.update(
                DatabaseConstants.tableCurriculumUnits,
                unitValues,
                where: 'id = ?',
                whereArgs: [unitId],
              );
            } else {
              existingUnits[unitId] = unitValues;
              syllabusBatch.insert(
                DatabaseConstants.tableCurriculumUnits,
                unitValues,
                conflictAlgorithm: ConflictAlgorithm.ignore,
              );
            }

            final lessonsList = uMap['lessons'] as List<dynamic>? ?? [];
            for (final l in lessonsList) {
              final lMap = l as Map<String, dynamic>;
              final lessonId = lMap['id'] as String;
              final prereqs = lMap['prerequisites'] as List<dynamic>? ?? [];
              final existingLesson = existingLessons[lessonId];

              String lessonStatus = lMap['status'] as String? ?? 'not_started';
              int lessonLocked = (lMap['is_locked'] == false || lMap['is_locked'] == 0) ? 0 : 1;
              String? completedAt;
              String? creditedReason;
              if (existingLesson != null) {
                lessonStatus = existingLesson['status'] as String? ?? lessonStatus;
                lessonLocked = (existingLesson['is_locked'] as num?)?.toInt() ?? lessonLocked;
                completedAt = existingLesson['completed_at'] as String?;
                creditedReason = existingLesson['credited_reason'] as String?;
              }

              final lessonValues = {
                'id': lessonId,
                'unit_id': unitId,
                'order_index': (lMap['order_index'] as num?)?.toInt() ?? 1,
                'title_vi': lMap['title_vi'] as String? ?? '',
                'title_zh': lMap['title_zh'] as String? ?? '',
                'pinyin': lMap['pinyin'] as String? ?? '',
                'estimated_minutes': (lMap['estimated_minutes'] as num?)?.toInt() ?? 15,
                'is_locked': lessonLocked,
                'unlock_score_threshold': (lMap['unlock_score_threshold'] as num?)?.toDouble() ?? 0.8,
                'prerequisites_json': json.encode(prereqs),
                'status': lessonStatus,
                'completed_at': completedAt,
                'credited_reason': creditedReason,
                'created_at': nowUtc,
              };
              if (existingLesson != null) {
                syllabusBatch.update(
                  DatabaseConstants.tableCurriculumLessons,
                  lessonValues,
                  where: 'id = ?',
                  whereArgs: [lessonId],
                );
              } else {
                existingLessons[lessonId] = lessonValues;
                syllabusBatch.insert(
                  DatabaseConstants.tableCurriculumLessons,
                  lessonValues,
                  conflictAlgorithm: ConflictAlgorithm.ignore,
                );
              }

              final segmentsList = lMap['segments'] as List<dynamic>? ?? [];
              for (final s in segmentsList) {
                final sMap = s as Map<String, dynamic>;
                final segId = sMap['id'] as String;
                final refId = (sMap['content_ref_id'] as String?)?.trim();

                if (refId != null && refId.isNotEmpty) {
                  refToLessons.putIfAbsent(refId, () => []).add(lessonId);
                }

                final segValues = {
                  'id': segId,
                  'lesson_id': lessonId,
                  'step_order': (sMap['step_order'] as num?)?.toInt() ?? 1,
                  'segment_type': sMap['segment_type'] as String? ?? 'vocabulary',
                  'title': sMap['title'] as String? ?? '',
                  'content_ref_id': refId,
                  'created_at': nowUtc,
                };
                if (existingSegments.contains(segId)) {
                  syllabusBatch.update(
                    DatabaseConstants.tableLessonSegments,
                    segValues,
                    where: 'id = ?',
                    whereArgs: [segId],
                  );
                } else {
                  existingSegments.add(segId);
                  syllabusBatch.insert(
                    DatabaseConstants.tableLessonSegments,
                    segValues,
                    conflictAlgorithm: ConflictAlgorithm.ignore,
                  );
                }
              }
            }
          }
          await syllabusBatch.commit(noResult: true);
        }

        final targetCurrId = curriculumId ?? 'curr_${manifest.packId}';

        // 5. Normalized Content Items & Knowledge Registry Ingestion (preloaded & batched)
        final parsedItems = <({
          String contentId,
          String curriculumId,
          int hskLevel,
          String knowledgeType,
          String title,
          String rawContentJson,
          String objectivesJson,
          String? sourceReference,
          String auditStatus,
          String contentVersion,
          String metadataJson,
          Map<String, dynamic> parsedContent,
          List<String> linkedLessons,
        })>[];

        final contentRowIds = <String>[];
        final allSimplified = <String>[];
        final allVocabKnowIds = <String>[];
        final allCandidateSenseIds = <String>[];
        final allGramIds = <String>[];
        final allGramCodes = <String>[];
        final allGramKnowIds = <String>[];
        final allLinkedLessonIds = <String>{};

        for (final item in contentItemsList) {
          if (item is! Map<String, dynamic>) continue;
          final contentId = (item['content_id'] as String).trim();
          final knowledgeType = item['knowledge_type'] as String? ?? 'vocabulary';
          final hskLevel = (item['hsk_level'] as num?)?.toInt() ?? manifest.hskLevel;
          final objs = item['objectives'] as List<dynamic>? ?? [];
          final linkedLessons = (refToLessons[contentId] ?? const <String>[]).toSet().toList();
          allLinkedLessonIds.addAll(linkedLessons);

          final rawContentJson = item['content_json'] is String
              ? item['content_json'] as String
              : json.encode(item['content_json'] ?? {});

          Map<String, dynamic> parsedContent = {};
          try {
            parsedContent = item['content_json'] is Map<String, dynamic>
                ? item['content_json'] as Map<String, dynamic>
                : json.decode(rawContentJson) as Map<String, dynamic>;
          } catch (e, stack) {
            debugPrint('[ContentPackManager] Lỗi phân tích content_json cho item $contentId: $e\n$stack');
          }

          contentRowIds.add('ci_$contentId');
          if (knowledgeType == 'vocabulary' && parsedContent['words'] is List) {
            for (final w in parsedContent['words'] as List<dynamic>) {
              if (w is! Map<String, dynamic>) continue;
              final simplified = w['simplified'] as String? ?? '';
              if (simplified.isEmpty) continue;
              allSimplified.add(simplified);
              allVocabKnowIds.add('KNOW_VOCAB_$simplified');
              allCandidateSenseIds.add('sense_${simplified}_1');
            }
          } else if (knowledgeType == 'grammar' && parsedContent['points'] is List) {
            int order = 1;
            for (final p in parsedContent['points'] as List<dynamic>) {
              if (p is! Map<String, dynamic>) continue;
              allGramCodes.add('GRAM_${contentId}_$order');
              allGramIds.add('gram_${contentId}_$order');
              allGramKnowIds.add('KNOW_GRAMMAR_${contentId}_$order');
              order++;
            }
          }

          parsedItems.add((
            contentId: contentId,
            curriculumId: item['curriculum_id'] as String? ?? targetCurrId,
            hskLevel: hskLevel,
            knowledgeType: knowledgeType,
            title: item['title'] as String? ?? '',
            rawContentJson: rawContentJson,
            objectivesJson: json.encode(objs),
            sourceReference: item['source_reference'] as String?,
            auditStatus: item['audit_status'] as String? ?? 'verified',
            contentVersion: item['content_version'] as String? ?? manifest.version,
            metadataJson: json.encode(item['metadata'] ?? {}),
            parsedContent: parsedContent,
            linkedLessons: linkedLessons,
          ));
        }

        final existingContentIds = await _queryExistingIds(
          txn,
          DatabaseConstants.tableContentItems,
          'id',
          contentRowIds,
        );
        final (:vocabById, :vocabBySimplified) = await _preloadVocabularies(txn, allSimplified);

        final probeVocabIds = <String>{
          ...vocabById.keys,
          ...allSimplified.map((s) => 'vocab_$s'),
        }.toList();
        final (:existingSenseIds, :senseIdByVocabId) = await _preloadVocabularySenses(
          txn,
          probeVocabIds,
          allCandidateSenseIds,
        );

        final (:vocabKnowById, :vocabKnowByCanonical) = await _preloadKnowledge(
          txn,
          entityType: 'vocabulary',
          ids: allVocabKnowIds,
          canonicalIds: allSimplified,
        );
        final existingGramIds = await _queryExistingIds(
          txn,
          DatabaseConstants.tableGrammarItems,
          'id',
          allGramIds,
        );
        final (vocabKnowById: gramKnowById, vocabKnowByCanonical: gramKnowByCanonical) =
            await _preloadKnowledge(
          txn,
          entityType: 'grammar',
          ids: allGramKnowIds,
          canonicalIds: allGramCodes,
        );
        final existingLinkIds = await _queryExistingIds(
          txn,
          DatabaseConstants.tableLessonKnowledgeItems,
          'id',
          allLinkedLessonIds.toList(),
          filterColumn: 'lesson_id',
        );

        final dataBatch = txn.batch();

        for (final entry in parsedItems) {
          final ciRowId = 'ci_${entry.contentId}';
          final ciValues = {
            'id': ciRowId,
            'content_id': entry.contentId,
            'curriculum_id': entry.curriculumId,
            'hsk_level': entry.hskLevel,
            'knowledge_type': entry.knowledgeType,
            'title': entry.title,
            'content_json': entry.rawContentJson,
            'objectives_json': entry.objectivesJson,
            'source_reference': entry.sourceReference,
            'audit_status': entry.auditStatus,
            'content_version': entry.contentVersion,
            'metadata_json': entry.metadataJson,
            'created_at': nowUtc,
            'updated_at': nowUtc,
          };
          if (existingContentIds.contains(ciRowId)) {
            dataBatch.update(
              DatabaseConstants.tableContentItems,
              ciValues,
              where: 'id = ?',
              whereArgs: [ciRowId],
            );
          } else {
            existingContentIds.add(ciRowId);
            dataBatch.insert(
              DatabaseConstants.tableContentItems,
              ciValues,
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
          }
          totalContentItems++;

          if (entry.knowledgeType == 'vocabulary' && entry.parsedContent['words'] is List) {
            final words = entry.parsedContent['words'] as List<dynamic>;
            int order = 1;
            for (final w in words) {
              if (w is! Map<String, dynamic>) continue;
              final simplified = w['simplified'] as String? ?? '';
              if (simplified.isEmpty) continue;
              final pinyin = w['pinyin'] as String? ?? '';
              final meaningVi = w['meaning_vi'] as String? ?? '';
              final pos = w['part_of_speech'] as String? ?? '';
              final example = w['example_sentence'] as String? ?? '';
              final audioUri = w['audio_uri'] as String? ?? '';

              // AUD-010: Prefer canonical VOC_* row over creating a duplicate vocab_<simplified>.
              final existingVocab = vocabBySimplified[simplified] ?? vocabById['vocab_$simplified'];
              final vocabId = existingVocab != null
                  ? existingVocab['id'] as String
                  : 'vocab_$simplified';
              final existingLevel = existingVocab != null
                  ? ((existingVocab['hsk_level'] as num?)?.toInt() ?? entry.hskLevel)
                  : entry.hskLevel;
              // Level-drift guard: preserve lower-level owner metadata when higher-level pack re-lists the word.
              final ownedByLowerLevel = existingVocab != null && existingLevel < entry.hskLevel;

              if (ownedByLowerLevel) {
                // Keep canonical lower-level vocabulary & sense untouched.
              } else if (existingVocab != null) {
                dataBatch.update(
                  DatabaseConstants.tableVocabularies,
                  {
                    'simplified': simplified,
                    'traditional': simplified,
                    'pinyin': pinyin,
                    'hsk_level': entry.hskLevel,
                    'audio_uri': audioUri,
                    'updated_at': nowUtc,
                  },
                  where: 'id = ?',
                  whereArgs: [vocabId],
                );
                existingVocab['hsk_level'] = entry.hskLevel;
              } else {
                final newVocab = <String, dynamic>{
                  'id': vocabId,
                  'simplified': simplified,
                  'traditional': simplified,
                  'pinyin': pinyin,
                  'hsk_level': entry.hskLevel,
                  'audio_uri': audioUri,
                  'created_at': nowUtc,
                  'updated_at': nowUtc,
                };
                vocabBySimplified[simplified] = newVocab;
                vocabById[vocabId] = newVocab;
                dataBatch.insert(
                  DatabaseConstants.tableVocabularies,
                  newVocab,
                  conflictAlgorithm: ConflictAlgorithm.ignore,
                );
              }

              // 2. Insert/update sense on the canonical vocabulary_id
              final defaultSenseId =
                  vocabId == 'vocab_$simplified' ? 'sense_${simplified}_1' : 'sense_${vocabId}_1';
              final targetSenseId = senseIdByVocabId[vocabId] ?? defaultSenseId;
              final senseExists = existingSenseIds.contains(targetSenseId);
              if (ownedByLowerLevel) {
                // Preserve lower-level sense.
              } else if (senseExists) {
                dataBatch.update(
                  DatabaseConstants.tableVocabularySenses,
                  {
                    'part_of_speech': pos,
                    'meaning_vi': meaningVi,
                    'example_cn': example,
                    'updated_at': nowUtc,
                  },
                  where: 'id = ?',
                  whereArgs: [targetSenseId],
                );
              } else {
                existingSenseIds.add(targetSenseId);
                senseIdByVocabId.putIfAbsent(vocabId, () => targetSenseId);
                dataBatch.insert(
                  DatabaseConstants.tableVocabularySenses,
                  {
                    'id': targetSenseId,
                    'vocabulary_id': vocabId,
                    'part_of_speech': pos,
                    'meaning_vi': meaningVi,
                    'example_cn': example,
                    'example_pinyin': '',
                    'example_vi': '',
                    'created_at': nowUtc,
                    'updated_at': nowUtc,
                  },
                  conflictAlgorithm: ConflictAlgorithm.ignore,
                );
              }

              // 3. Register in Knowledge Registry
              final knowId = 'KNOW_VOCAB_$simplified';
              final matchedKnowId = vocabKnowById[knowId] ?? vocabKnowByCanonical[simplified];
              final activeKnowId = matchedKnowId ?? knowId;
              if (matchedKnowId != null) {
                if (!ownedByLowerLevel) {
                  dataBatch.update(
                    DatabaseConstants.tableKnowledgeRegistry,
                    {
                      'title': simplified,
                      'metadata_json': json.encode({'pinyin': pinyin, 'meaning_vi': meaningVi}),
                      'updated_at': nowUtc,
                    },
                    where: 'id = ?',
                    whereArgs: [activeKnowId],
                  );
                }
              } else {
                vocabKnowById[knowId] = knowId;
                vocabKnowByCanonical[simplified] = knowId;
                dataBatch.insert(
                  DatabaseConstants.tableKnowledgeRegistry,
                  {
                    'id': knowId,
                    'entity_type': 'vocabulary',
                    'canonical_id': simplified,
                    'hsk_level': entry.hskLevel,
                    'title': simplified,
                    'is_deprecated': 0,
                    'replaced_by_id': null,
                    'package_id': targetCurrId,
                    'metadata_json': json.encode({'pinyin': pinyin, 'meaning_vi': meaningVi}),
                    'created_at': nowUtc,
                    'updated_at': nowUtc,
                  },
                  conflictAlgorithm: ConflictAlgorithm.ignore,
                );
                totalKnowledgeItems++;
              }

              // 4. Link to lessons
              for (final lessonId in entry.linkedLessons) {
                final linkId = 'lki_${lessonId}_$activeKnowId';
                if (existingLinkIds.contains(linkId)) {
                  dataBatch.update(
                    DatabaseConstants.tableLessonKnowledgeItems,
                    {
                      'role': 'instruction',
                      'sequence_order': order,
                      'is_mandatory': 1,
                    },
                    where: 'id = ?',
                    whereArgs: [linkId],
                  );
                } else {
                  existingLinkIds.add(linkId);
                  dataBatch.insert(
                    DatabaseConstants.tableLessonKnowledgeItems,
                    {
                      'id': linkId,
                      'lesson_id': lessonId,
                      'knowledge_item_id': activeKnowId,
                      'role': 'instruction',
                      'sequence_order': order,
                      'is_mandatory': 1,
                      'created_at': nowUtc,
                    },
                    conflictAlgorithm: ConflictAlgorithm.ignore,
                  );
                }
              }
              order++;
            }
          } else if (entry.knowledgeType == 'grammar' && entry.parsedContent['points'] is List) {
            final points = entry.parsedContent['points'] as List<dynamic>;
            int order = 1;
            for (final p in points) {
              if (p is! Map<String, dynamic>) continue;
              final title = p['title'] as String? ?? 'Điểm ngữ pháp $order';
              final structure = p['structure'] as String? ?? '';
              final explanation = p['explanation'] as String? ?? '';
              final posEx = p['positive_example'] as String? ?? '';
              final conEx = p['contrastive_example'] as String? ?? '';

              final gramCode = 'GRAM_${entry.contentId}_$order';
              final gramId = 'gram_${entry.contentId}_$order';
              final knowId = 'KNOW_GRAMMAR_${entry.contentId}_$order';

              // 1. Insert/update grammar without cascade delete
              final gramValues = {
                'id': gramId,
                'hsk_level': entry.hskLevel,
                'code': gramCode,
                'pattern': structure,
                'title_vi': title,
                'explanation_vi': explanation,
                'examples_json': json.encode(posEx.isNotEmpty ? [posEx] : []),
                'title': title,
                'structure': structure,
                'meaning_vi': explanation,
                'contrastive_examples_json': json.encode(conEx.isNotEmpty ? [conEx] : []),
                'updated_at': nowUtc,
              };
              if (existingGramIds.contains(gramId)) {
                dataBatch.update(
                  DatabaseConstants.tableGrammarItems,
                  gramValues,
                  where: 'id = ?',
                  whereArgs: [gramId],
                );
              } else {
                existingGramIds.add(gramId);
                dataBatch.insert(
                  DatabaseConstants.tableGrammarItems,
                  {
                    ...gramValues,
                    'created_at': nowUtc,
                  },
                  conflictAlgorithm: ConflictAlgorithm.ignore,
                );
              }

              // 2. Register in Knowledge Registry
              final matchedGramKnowId = gramKnowById[knowId] ?? gramKnowByCanonical[gramCode];
              final activeGramId = matchedGramKnowId ?? knowId;
              if (matchedGramKnowId != null) {
                dataBatch.update(
                  DatabaseConstants.tableKnowledgeRegistry,
                  {
                    'title': title,
                    'metadata_json': json.encode({'structure': structure, 'explanation': explanation}),
                    'updated_at': nowUtc,
                  },
                  where: 'id = ?',
                  whereArgs: [activeGramId],
                );
              } else {
                gramKnowById[knowId] = knowId;
                gramKnowByCanonical[gramCode] = knowId;
                dataBatch.insert(
                  DatabaseConstants.tableKnowledgeRegistry,
                  {
                    'id': knowId,
                    'entity_type': 'grammar',
                    'canonical_id': gramCode,
                    'hsk_level': entry.hskLevel,
                    'title': title,
                    'is_deprecated': 0,
                    'replaced_by_id': null,
                    'package_id': targetCurrId,
                    'metadata_json': json.encode({'structure': structure, 'explanation': explanation}),
                    'created_at': nowUtc,
                    'updated_at': nowUtc,
                  },
                  conflictAlgorithm: ConflictAlgorithm.ignore,
                );
                totalKnowledgeItems++;
              }

              // 3. Link to lessons
              for (final lessonId in entry.linkedLessons) {
                final linkId = 'lki_${lessonId}_$activeGramId';
                if (existingLinkIds.contains(linkId)) {
                  dataBatch.update(
                    DatabaseConstants.tableLessonKnowledgeItems,
                    {
                      'role': 'instruction',
                      'sequence_order': order,
                      'is_mandatory': 1,
                    },
                    where: 'id = ?',
                    whereArgs: [linkId],
                  );
                } else {
                  existingLinkIds.add(linkId);
                  dataBatch.insert(
                    DatabaseConstants.tableLessonKnowledgeItems,
                    {
                      'id': linkId,
                      'lesson_id': lessonId,
                      'knowledge_item_id': activeGramId,
                      'role': 'instruction',
                      'sequence_order': order,
                      'is_mandatory': 1,
                      'created_at': nowUtc,
                    },
                    conflictAlgorithm: ConflictAlgorithm.ignore,
                  );
                }
              }
              order++;
            }
          }
        }
        await dataBatch.commit(noResult: true);

        // 6. Level Exit Exam
        if (exitExamMap != null) {
          await _safeUpsert(
            txn,
            DatabaseConstants.tableLevelExitExams,
            {
              'id': exitExamMap['id'] as String? ?? 'exit_exam_${manifest.hskLevel}',
              'curriculum_id': exitExamMap['curriculum_id'] as String? ?? targetCurrId,
              'hsk_level': (exitExamMap['hsk_level'] as num?)?.toInt() ?? manifest.hskLevel,
              'title': exitExamMap['title'] as String? ?? 'Đề thi tốt nghiệp HSK ${manifest.hskLevel}',
              'passing_score': (exitExamMap['passing_score'] as num?)?.toInt() ?? 120,
              'duration_minutes': (exitExamMap['duration_minutes'] as num?)?.toInt() ?? 35,
              'exam_data_json': exitExamMap['exam_data_json'] is String
                  ? exitExamMap['exam_data_json']
                  : json.encode(exitExamMap['exam_data_json'] ?? {}),
              'created_at': nowUtc,
            },
          );
        }
      }

      final db = _db;
      if (db is Database) {
        await db.transaction((txn) async {
          await executeInTransaction(txn);
        });
      } else {
        await executeInTransaction(_db);
      }

      if (!skippedAlreadyInstalled) {
        await _applyLatePlacementUnlock(manifest.hskLevel);
      }

      return ContentPackInstallResult.success(
        packId: manifest.packId,
        lessonsCount: totalLessons,
        contentItemsCount: totalContentItems,
        knowledgeCount: totalKnowledgeItems,
      );
    } catch (e, stackTrace) {
      debugPrint('[ContentPackManager] Operation failed: $e\n$stackTrace');
      return ContentPackInstallResult.failure(
        packId: 'unknown',
        message: e is ContentPackManagerException ? e.message : 'Lỗi cài đặt gói học liệu: $e',
      );
    }
  }

  /// Uninstalls a content pack cleanly.
  /// - Verifies no active dependents rely on this pack unless [force] is true.
  /// - Removes curriculum syllabus hierarchy.
  /// - SAFEGUARD: Never deletes shared knowledge items (vocabularies, grammar, knowledge_registry)
  ///   or user learner progress (curriculum_mastery, srs_items, learner_evidence).
  Future<bool> uninstallPack(String packId, {bool force = false}) async {
    // 1. Check for dependent packs
    if (!force) {
      final allPacks = await _db.query(
        DatabaseConstants.tableContentPacks,
        columns: ['id', 'title', 'dependencies_json'],
        where: 'id != ? AND status IN (\'installed\', \'bundled\')',
        whereArgs: [packId],
      );

      final dependentPacks = <String>[];
      for (final p in allPacks) {
        final depsJson = p['dependencies_json'] as String? ?? '[]';
        try {
          final deps = (json.decode(depsJson) as List<dynamic>).map((e) => e.toString()).toList();
          if (deps.contains(packId)) {
            dependentPacks.add(p['title'] as String? ?? p['id'] as String);
          }
        } catch (e, stack) {
          debugPrint('[ContentPackManager] Lỗi phân tích dependencies_json cho pack ${p['id']}: $e\n$stack');
        }
      }

      if (dependentPacks.isNotEmpty) {
        throw ContentPackManagerException(
          'Không thể gỡ bỏ vì các gói sau đang phụ thuộc vào gói này: ${dependentPacks.join(', ')}.',
          packId: packId,
        );
      }
    }

    Future<void> runUninstall(DatabaseExecutor txn) async {
      // Find curriculums
      final currRows = await txn.query(
        DatabaseConstants.tableCurriculums,
        columns: ['id'],
        where: 'pack_id = ?',
        whereArgs: [packId],
      );

      for (final cRow in currRows) {
        final currId = cRow['id'] as String;

        // Find units
        final unitRows = await txn.query(
          DatabaseConstants.tableCurriculumUnits,
          columns: ['id'],
          where: 'curriculum_id = ?',
          whereArgs: [currId],
        );
        final unitIds = unitRows.map((u) => u['id'] as String).toList();

        if (unitIds.isNotEmpty) {
          final unitPlaceholders = List.filled(unitIds.length, '?').join(',');
          final lessonRows = await txn.query(
            DatabaseConstants.tableCurriculumLessons,
            columns: ['id'],
            where: 'unit_id IN ($unitPlaceholders)',
            whereArgs: unitIds,
          );
          final lessonIds = lessonRows.map((l) => l['id'] as String).toList();

          if (lessonIds.isNotEmpty) {
            final lessonPlaceholders = List.filled(lessonIds.length, '?').join(',');
            // Delete lesson segments
            await txn.delete(
              DatabaseConstants.tableLessonSegments,
              where: 'lesson_id IN ($lessonPlaceholders)',
              whereArgs: lessonIds,
            );
            // Delete lesson knowledge links
            await txn.delete(
              DatabaseConstants.tableLessonKnowledgeItems,
              where: 'lesson_id IN ($lessonPlaceholders)',
              whereArgs: lessonIds,
            );
            // Delete lessons
            await txn.delete(
              DatabaseConstants.tableCurriculumLessons,
              where: 'id IN ($lessonPlaceholders)',
              whereArgs: lessonIds,
            );
          }

          // Delete units
          await txn.delete(
            DatabaseConstants.tableCurriculumUnits,
            where: 'id IN ($unitPlaceholders)',
            whereArgs: unitIds,
          );
        }

        // Delete exit exam
        await txn.delete(
          DatabaseConstants.tableLevelExitExams,
          where: 'curriculum_id = ?',
          whereArgs: [currId],
        );

        // Delete content items for curriculum
        await txn.delete(
          DatabaseConstants.tableContentItems,
          where: 'curriculum_id = ?',
          whereArgs: [currId],
        );

        // Delete curriculum
        await txn.delete(
          DatabaseConstants.tableCurriculums,
          where: 'id = ?',
          whereArgs: [currId],
        );
      }

      // Update pack status to not_installed
      await txn.update(
        DatabaseConstants.tableContentPacks,
        {
          'status': 'not_installed',
          'installed_at': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [packId],
      );
    }

    final db = _db;
    if (db is Database) {
      await db.transaction((txn) async {
        await runUninstall(txn);
      });
    } else {
      await runUninstall(_db);
    }

    return true;
  }

  /// Verifies structural and relational integrity of an installed content pack.
  Future<bool> verifyIntegrity(String packId) async {
    final pack = await _db.query(
      DatabaseConstants.tableContentPacks,
      where: 'id = ? AND status IN (\'installed\', \'bundled\')',
      whereArgs: [packId],
      limit: 1,
    );
    if (pack.isEmpty) return false;

    final currRows = await _db.query(
      DatabaseConstants.tableCurriculums,
      where: 'pack_id = ?',
      whereArgs: [packId],
    );
    if (currRows.isEmpty) return false;

    // Check that knowledge items linked to lessons actually exist in knowledge_registry
    final danglingLinks = await _db.rawQuery('''
      SELECT lki.id 
      FROM ${DatabaseConstants.tableLessonKnowledgeItems} lki
      LEFT JOIN ${DatabaseConstants.tableKnowledgeRegistry} kr ON lki.knowledge_item_id = kr.id
      WHERE kr.id IS NULL
    ''');

    return danglingLinks.isEmpty;
  }

  Future<Set<String>> _queryExistingIds(
    DatabaseExecutor executor,
    String table,
    String selectColumn,
    List<String> keys, {
    String? filterColumn,
  }) async {
    final result = <String>{};
    if (keys.isEmpty) return result;
    final col = filterColumn ?? selectColumn;
    for (final chunk in DaoUtils.chunkList(keys.toSet().toList())) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await executor.query(
        table,
        columns: [selectColumn],
        where: '$col IN ($placeholders)',
        whereArgs: chunk,
      );
      for (final row in rows) {
        final v = row[selectColumn] as String?;
        if (v != null) result.add(v);
      }
    }
    return result;
  }

  Future<Map<String, Map<String, dynamic>>> _queryExistingMap(
    DatabaseExecutor executor,
    String table,
    List<String> columns,
    String keyColumn,
    List<String> keys,
  ) async {
    final result = <String, Map<String, dynamic>>{};
    if (keys.isEmpty) return result;
    for (final chunk in DaoUtils.chunkList(keys.toSet().toList())) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await executor.query(
        table,
        columns: columns,
        where: '$keyColumn IN ($placeholders)',
        whereArgs: chunk,
      );
      for (final row in rows) {
        final k = row[keyColumn] as String?;
        if (k != null) {
          result[k] = Map<String, dynamic>.from(row);
        }
      }
    }
    return result;
  }

  Future<({Map<String, Map<String, dynamic>> vocabById, Map<String, Map<String, dynamic>> vocabBySimplified})>
      _preloadVocabularies(DatabaseExecutor executor, List<String> simplifiedList) async {
    final vocabById = <String, Map<String, dynamic>>{};
    final vocabBySimplified = <String, Map<String, dynamic>>{};
    final unique = simplifiedList.toSet().toList();
    if (unique.isEmpty) {
      return (vocabById: vocabById, vocabBySimplified: vocabBySimplified);
    }

    for (final chunk in DaoUtils.chunkList(unique)) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await executor.rawQuery('''
        SELECT id, simplified, hsk_level
        FROM ${DatabaseConstants.tableVocabularies}
        WHERE simplified IN ($placeholders)
        ORDER BY CASE WHEN SUBSTR(id, 1, 4) = 'VOC_' THEN 0 ELSE 1 END, id ASC
      ''', chunk);
      for (final raw in rows) {
        final row = Map<String, dynamic>.from(raw);
        final id = row['id'] as String;
        final simp = row['simplified'] as String? ?? '';
        vocabById[id] = row;
        if (simp.isNotEmpty) {
          vocabBySimplified.putIfAbsent(simp, () => row);
        }
      }
    }
    return (vocabById: vocabById, vocabBySimplified: vocabBySimplified);
  }

  Future<({Set<String> existingSenseIds, Map<String, String> senseIdByVocabId})> _preloadVocabularySenses(
    DatabaseExecutor executor,
    List<String> vocabIds,
    List<String> senseIds,
  ) async {
    final existingSenseIds = <String>{};
    final senseIdByVocabId = <String, String>{};
    for (final chunk in DaoUtils.chunkList(vocabIds.toSet().toList())) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await executor.query(
        DatabaseConstants.tableVocabularySenses,
        columns: ['id', 'vocabulary_id'],
        where: 'vocabulary_id IN ($placeholders)',
        whereArgs: chunk,
        orderBy: 'order_index ASC, id ASC',
      );
      for (final row in rows) {
        final id = row['id'] as String;
        final vid = row['vocabulary_id'] as String?;
        existingSenseIds.add(id);
        if (vid != null) {
          senseIdByVocabId.putIfAbsent(vid, () => id);
        }
      }
    }
    for (final chunk in DaoUtils.chunkList(senseIds.toSet().toList())) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await executor.query(
        DatabaseConstants.tableVocabularySenses,
        columns: ['id', 'vocabulary_id'],
        where: 'id IN ($placeholders)',
        whereArgs: chunk,
      );
      for (final row in rows) {
        final id = row['id'] as String;
        final vid = row['vocabulary_id'] as String?;
        existingSenseIds.add(id);
        if (vid != null) {
          senseIdByVocabId.putIfAbsent(vid, () => id);
        }
      }
    }
    return (existingSenseIds: existingSenseIds, senseIdByVocabId: senseIdByVocabId);
  }

  Future<({Map<String, String> vocabKnowById, Map<String, String> vocabKnowByCanonical})> _preloadKnowledge(
    DatabaseExecutor executor, {
    required String entityType,
    required List<String> ids,
    required List<String> canonicalIds,
  }) async {
    final byId = <String, String>{};
    final byCanonical = <String, String>{};
    for (final chunk in DaoUtils.chunkList(ids.toSet().toList())) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await executor.query(
        DatabaseConstants.tableKnowledgeRegistry,
        columns: ['id', 'canonical_id'],
        where: 'id IN ($placeholders)',
        whereArgs: chunk,
      );
      for (final row in rows) {
        final id = row['id'] as String;
        final can = row['canonical_id'] as String? ?? '';
        byId[id] = id;
        if (can.isNotEmpty) byCanonical.putIfAbsent(can, () => id);
      }
    }
    for (final chunk in DaoUtils.chunkList(canonicalIds.toSet().toList(), chunkSize: 400)) {
      final placeholders = List.filled(chunk.length, '?').join(',');
      final rows = await executor.query(
        DatabaseConstants.tableKnowledgeRegistry,
        columns: ['id', 'canonical_id'],
        where: 'entity_type = ? AND canonical_id IN ($placeholders)',
        whereArgs: [entityType, ...chunk],
      );
      for (final row in rows) {
        final id = row['id'] as String;
        final can = row['canonical_id'] as String? ?? '';
        byId[id] = id;
        if (can.isNotEmpty) byCanonical.putIfAbsent(can, () => id);
      }
    }
    return (vocabKnowById: byId, vocabKnowByCanonical: byCanonical);
  }

  /// AUD-023: Re-applies placement / exit-exam level unlocks when higher-level packs
  /// (HSK 3-6) are downloaded after placement testing or level advancement.
  Future<void> _applyLatePlacementUnlock(int installedHskLevel) async {
    int maxRecommendedLevel = 0;
    bool hasCompletedPlacement = false;

    try {
      final profileRows = await _db.rawQuery(
        'SELECT MAX(current_hsk_level) AS max_lvl FROM ${DatabaseConstants.tableUserProfiles}',
      );
      final profileLvl = (profileRows.firstOrNull?['max_lvl'] as num?)?.toInt() ?? 0;
      maxRecommendedLevel = math.max(maxRecommendedLevel, profileLvl);
    } catch (_) {}

    try {
      final sessionRows = await _db.query(
        DatabaseConstants.tablePlacementTestSessions,
        columns: ['recommended_level'],
        where: "status = 'completed' AND recommended_level IS NOT NULL",
        orderBy: 'completed_at DESC, updated_at DESC',
        limit: 1,
      );
      if (sessionRows.isNotEmpty) {
        hasCompletedPlacement = true;
        final placementLvl = (sessionRows.first['recommended_level'] as num?)?.toInt() ?? 0;
        maxRecommendedLevel = math.max(maxRecommendedLevel, placementLvl);
      }
    } catch (_) {}

    if (maxRecommendedLevel > 0 &&
        installedHskLevel <= maxRecommendedLevel &&
        (hasCompletedPlacement || maxRecommendedLevel > 1)) {
      await PlacementUnlockHandler(_db).unlockForRecommendedLevel(maxRecommendedLevel);
    }
  }
}
