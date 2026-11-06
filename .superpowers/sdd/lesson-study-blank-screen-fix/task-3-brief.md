# Task 3 Brief: Nâng Cấp Kiểm Tra Toàn Vẹn & Tự Nạp Lại Khi Nâng Cấp Ứng Dụng

**Files:**
- Modify: `lib/core/startup/app_startup_provider.dart`
- Modify: `lib/core/database/dao/curriculum_dao.dart`
- Test: `test/features/content_packs/pack_upgrade_integrity_test.dart`

**Exact Requirements:**
1. **Startup Pack Need Check (`app_startup_provider.dart`)**:
   In `_checkPackNeedsImport(Database db, MandatoryPackInfo pack)`:
   Currently it only queries `COUNT(*) FROM tableCurriculumLessons`.
   If a user upgraded from an earlier version that failed during segment extraction, `tableCurriculumLessons` has 15 rows, but `tableLessonSegments` has 0 rows.
   Add segment count check:
   ```dart
   final segmentsRes = await db.rawQuery('''
     SELECT COUNT(*) as cnt 
     FROM ${DatabaseConstants.tableLessonSegments} 
     WHERE lesson_id IN (
       SELECT l.id FROM ${DatabaseConstants.tableCurriculumLessons} l
       INNER JOIN ${DatabaseConstants.tableCurriculumUnits} u ON l.unit_id = u.id
       WHERE u.curriculum_id = ?
     )
   ''', [pack.curriculumId]);
   final segmentCount = Sqflite.firstIntValue(segmentsRes) ?? 0;
   if (segmentCount == 0) {
     return true; // Force re-importing bundled pack to repair missing segments
   }
   ```
   Also in `_verifyDataIntegrity`: ensure segments for bundled levels (HSK 1 and HSK 2) are verified alongside lesson counts (e.g. >= 90 segments for 15 lessons x 6 segments).
2. **Flexible Case-Insensitive Join (`curriculum_dao.dart`)**:
   In `getSegmentsByLessonId(String lessonId)`:
   ```sql
   SELECT ls.*, ci.content_json AS content_payload
   FROM ${DatabaseConstants.tableLessonSegments} ls
   LEFT JOIN ${DatabaseConstants.tableContentItems} ci ON UPPER(TRIM(ls.content_ref_id)) = UPPER(TRIM(ci.content_id))
   WHERE ls.lesson_id = ?
   ORDER BY ls.step_order ASC
   ```
3. **Automated Verification Test**:
   Create `test/features/content_packs/pack_upgrade_integrity_test.dart`:
   - Initialize an in-memory SQLite DB.
   - Insert dummy curriculum lessons for HSK 1 with 0 segments.
   - Run `_checkPackNeedsImport` -> asserts it returns `true`.
   - Verify `CurriculumDao.getSegmentsByLessonId` matches regardless of casing or whitespace around `content_ref_id`.
4. **Commit Message**:
   `fix(startup): ensure full segment and content item integrity check on app upgrade`
