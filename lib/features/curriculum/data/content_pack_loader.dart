import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_constants.dart';
import '../domain/models/content_pack_models.dart';

class ContentPackLoader {
  final DatabaseExecutor _db;

  const ContentPackLoader(this._db);

  static String computeChecksum(String rawJson) {
    return sha256.convert(utf8.encode(rawJson)).toString();
  }

  Future<ContentPackInstallResult> loadPackFromJson(String rawJson) async {
    try {
      final decoded = json.decode(rawJson) as Map<String, dynamic>;
      final manifestMap = decoded['manifest'] as Map<String, dynamic>? ?? {};
      final manifest = ContentPackManifest.fromJson(manifestMap);

      if (manifest.packId.isEmpty) {
        return ContentPackInstallResult.failure(
          packId: 'unknown',
          message: 'Gói học liệu thiếu trường pack_id hợp lệ.',
        );
      }

      int totalLessons = 0;
      int totalContentItems = 0;

      // Extract Curriculum & Units & Lessons
      final curriculumMap = decoded['curriculum'] as Map<String, dynamic>?;
      final contentItemsList = decoded['content_items'] as List<dynamic>? ?? [];
      final exitExamMap = decoded['exit_exam'] as Map<String, dynamic>?;

      Future<void> runInserts(DatabaseExecutor executor) async {
        final nowUtc = DateTime.now().toUtc().toIso8601String();

        // 1. Insert Content Pack record
        await executor.insert(
          DatabaseConstants.tableContentPacks,
          manifest.toMap(status: 'bundled', installedAt: nowUtc),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // 2. Insert Curriculum
        if (curriculumMap != null) {
          final currId = curriculumMap['id'] as String? ?? 'curr_${manifest.packId}';
          final unitsList = curriculumMap['units'] as List<dynamic>? ?? [];

          // Count lessons
          for (final u in unitsList) {
            final lessons = (u as Map<String, dynamic>)['lessons'] as List<dynamic>? ?? [];
            totalLessons += lessons.length;
          }

          await executor.insert(
            DatabaseConstants.tableCurriculums,
            {
              'id': currId,
              'pack_id': manifest.packId,
              'code': curriculumMap['code'] as String? ?? 'HSK_${manifest.hskLevel}',
              'standard_name': curriculumMap['standard_name'] as String? ?? 'HSK Level ${manifest.hskLevel}',
              'hsk_level': manifest.hskLevel,
              'total_units': unitsList.length,
              'total_lessons': totalLessons,
              'created_at': nowUtc,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          // 3. Insert Units & Lessons & Segments
          for (final u in unitsList) {
            final uMap = u as Map<String, dynamic>;
            final unitId = uMap['id'] as String;
            await executor.insert(
              DatabaseConstants.tableCurriculumUnits,
              {
                'id': unitId,
                'curriculum_id': currId,
                'order_index': (uMap['order_index'] as num?)?.toInt() ?? 1,
                'title_vi': uMap['title_vi'] as String? ?? '',
                'title_zh': uMap['title_zh'] as String? ?? '',
                'description_vi': uMap['description_vi'] as String?,
                'icon_name': uMap['icon_name'] as String?,
                'is_locked': (uMap['is_locked'] == false || uMap['is_locked'] == 0) ? 0 : 1,
                'created_at': nowUtc,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            final lessonsList = uMap['lessons'] as List<dynamic>? ?? [];
            for (final l in lessonsList) {
              final lMap = l as Map<String, dynamic>;
              final lessonId = lMap['id'] as String;
              final prereqs = lMap['prerequisites'] as List<dynamic>? ?? [];

              await executor.insert(
                DatabaseConstants.tableCurriculumLessons,
                {
                  'id': lessonId,
                  'unit_id': unitId,
                  'order_index': (lMap['order_index'] as num?)?.toInt() ?? 1,
                  'title_vi': lMap['title_vi'] as String? ?? '',
                  'title_zh': lMap['title_zh'] as String? ?? '',
                  'pinyin': lMap['pinyin'] as String? ?? '',
                  'estimated_minutes': (lMap['estimated_minutes'] as num?)?.toInt() ?? 15,
                  'is_locked': (lMap['is_locked'] == false || lMap['is_locked'] == 0) ? 0 : 1,
                  'unlock_score_threshold': (lMap['unlock_score_threshold'] as num?)?.toDouble() ?? 0.8,
                  'prerequisites_json': json.encode(prereqs),
                  'status': lMap['status'] as String? ?? 'not_started',
                  'created_at': nowUtc,
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );

              final segmentsList = lMap['segments'] as List<dynamic>? ?? [];
              for (final s in segmentsList) {
                final sMap = s as Map<String, dynamic>;
                await executor.insert(
                  DatabaseConstants.tableLessonSegments,
                  {
                    'id': sMap['id'] as String,
                    'lesson_id': lessonId,
                    'step_order': (sMap['step_order'] as num?)?.toInt() ?? 1,
                    'segment_type': sMap['segment_type'] as String? ?? 'vocabulary',
                    'title': sMap['title'] as String? ?? '',
                    'content_ref_id': sMap['content_ref_id'] as String?,
                    'created_at': nowUtc,
                  },
                  conflictAlgorithm: ConflictAlgorithm.replace,
                );
              }
            }
          }
        }

        // 4. Insert Content Items (CMS Catalog)
        for (final item in contentItemsList) {
          final iMap = item as Map<String, dynamic>;
          final contentId = iMap['content_id'] as String;
          final objs = iMap['objectives'] as List<dynamic>? ?? [];

          await executor.insert(
            DatabaseConstants.tableContentItems,
            {
              'id': 'ci_$contentId',
              'content_id': contentId,
              'curriculum_id': iMap['curriculum_id'] as String? ?? 'curr_${manifest.packId}',
              'hsk_level': (iMap['hsk_level'] as num?)?.toInt() ?? manifest.hskLevel,
              'knowledge_type': iMap['knowledge_type'] as String? ?? 'vocabulary',
              'title': iMap['title'] as String? ?? '',
              'content_json': iMap['content_json'] is String
                  ? iMap['content_json']
                  : json.encode(iMap['content_json'] ?? {}),
              'objectives_json': json.encode(objs),
              'source_reference': iMap['source_reference'] as String?,
              'audit_status': iMap['audit_status'] as String? ?? 'verified',
              'content_version': iMap['content_version'] as String? ?? manifest.version,
              'metadata_json': json.encode(iMap['metadata'] ?? {}),
              'created_at': nowUtc,
              'updated_at': nowUtc,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          totalContentItems++;
        }

        // 5. Insert Exit Exam if present
        if (exitExamMap != null) {
          await executor.insert(
            DatabaseConstants.tableLevelExitExams,
            {
              'id': exitExamMap['id'] as String? ?? 'exit_exam_${manifest.hskLevel}',
              'curriculum_id': exitExamMap['curriculum_id'] as String? ?? 'curr_${manifest.packId}',
              'hsk_level': (exitExamMap['hsk_level'] as num?)?.toInt() ?? manifest.hskLevel,
              'title': exitExamMap['title'] as String? ?? 'Đề thi tốt nghiệp HSK ${manifest.hskLevel}',
              'passing_score': (exitExamMap['passing_score'] as num?)?.toInt() ?? 120,
              'duration_minutes': (exitExamMap['duration_minutes'] as num?)?.toInt() ?? 35,
              'exam_data_json': exitExamMap['exam_data_json'] is String
                  ? exitExamMap['exam_data_json']
                  : json.encode(exitExamMap['exam_data_json'] ?? {}),
              'created_at': nowUtc,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        }
      }

      if (_db is Database) {
        await (_db as Database).transaction((txn) async {
          await runInserts(txn);
        });
      } else {
        await runInserts(_db);
      }

      return ContentPackInstallResult.success(
        packId: manifest.packId,
        lessonsCount: totalLessons,
        contentItemsCount: totalContentItems,
      );
    } catch (e, stackTrace) {
      debugPrint('[ContentPackLoader] Installation failed: $e\n$stackTrace');
      return ContentPackInstallResult.failure(
        packId: 'unknown',
        message: 'Lỗi nạp gói học liệu: $e',
      );
    }
  }
}
