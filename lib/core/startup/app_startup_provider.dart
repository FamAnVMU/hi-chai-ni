import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../../features/content_packs/data/content_pack_manager.dart';
import '../audio/audio_temp_cleaner.dart';
import '../../features/settings/presentation/providers/settings_providers.dart';
import '../database/app_database.dart';
import '../database/dao/app_settings_dao.dart';
import '../database/database_constants.dart';
import '../database/seed/seed_loader.dart';
import '../network/ai/security/ai_credential_storage.dart';
import '../theme/theme.dart';
import 'app_startup_state.dart';

export 'app_startup_state.dart';

/// Mandatory bundled content packs required for baseline offline learning.
class MandatoryPackInfo {
  final String packId;
  final String curriculumId;
  final String assetPath;
  final String title;

  const MandatoryPackInfo({
    required this.packId,
    required this.curriculumId,
    required this.assetPath,
    required this.title,
  });
}

/// Notifier managing the global 10-step initialization sequence for HI Chinese.
///
/// Execution Sequence:
/// 1. Initialize application environment.
/// 2. Open SQLite offline database.
/// 3. Verify and execute database schema migrations.
/// 4. Check seed dataset status in `seed_history`.
/// 5. Load canonical 5,000 HSK 1-6 seed data if missing (`hsk_seed_fixture_v2.json`).
/// 6. Check required mandatory Content Packs (`hsk1_pack_v1`, `hsk2_pack_v1`).
/// 7. Import missing or updated content packs idempotently without progress loss.
/// 8. Verify data integrity (curriculum units, lessons, content items).
/// 9. Initialize dependent learning services (default user profile).
/// 10. Transition app to `isReady = true`.
class AppStartupNotifier extends Notifier<AppStartupState> {
  static const String canonicalSeedAssetPath = 'assets/data/hsk_seed_fixture_v2.json';
  static const String canonicalSeedBundleName = 'hsk_seed_fixture_v2';
  static const int minimumExpectedVocabCount = 5000;

  static const List<MandatoryPackInfo> mandatoryPacks = [
    MandatoryPackInfo(
      packId: 'hsk1_pack_v1',
      curriculumId: 'curr_hsk1',
      assetPath: 'assets/data/content_packs/hsk1/hsk1_pack_v1.json',
      title: 'Giáo trình chuẩn HSK 1',
    ),
    MandatoryPackInfo(
      packId: 'hsk2_pack_v1',
      curriculumId: 'curr_hsk2',
      assetPath: 'assets/data/content_packs/hsk2/hsk2_pack_v1.json',
      title: 'Giáo trình chuẩn HSK 2',
    ),
  ];

  @override
  AppStartupState build() {
    // Automatically trigger initialization on startup
    Future.microtask(() => initialize());
    return const AppStartupState(
      isInitializing: true,
      isReady: false,
      statusMessage: 'Đang khởi động hệ thống HI Chinese...',
    );
  }

  Future<void> initialize({
    AssetBundle? bundle,
    Database? databaseOverride,
    AiCredentialStorage? credentialStorageOverride,
  }) async {
    state = state.copyWith(
      isInitializing: true,
      isReady: false,
      error: null,
      statusMessage: '1/10: Khởi tạo môi trường ứng dụng...',
    );

    try {
      final assetBundle = bundle ?? rootBundle;

      // Bước 1: Khởi tạo môi trường ứng dụng & dọn dẹp âm thanh tạm thời cũ (F-30)
      debugPrint('[AppStartup] 1/10: Khởi tạo môi trường ứng dụng...');
      try {
        await AudioTempCleaner.cleanupTempAudioFiles();
      } catch (e) {
        debugPrint('[AppStartup] AudioTempCleaner non-fatal warning: $e');
      }

      // Bước 2: Mở database
      state = state.copyWith(
        statusMessage: '2/10: Mở cơ sở dữ liệu SQLite offline...',
      );
      debugPrint('[AppStartup] 2/10: Mở cơ sở dữ liệu SQLite...');
      final Database db = databaseOverride ?? await AppDatabase.instance.open();

      // Bước 3: Kiểm tra và thực hiện migration
      state = state.copyWith(
        statusMessage: '3/10: Kiểm tra và đồng bộ cấu trúc cơ sở dữ liệu...',
      );
      debugPrint('[AppStartup] 3/10: Kiểm tra migrations...');
      final dbVersion = await db.getVersion();
      debugPrint('[AppStartup] Database Schema Version: $dbVersion');

      // Bước 4: Kiểm tra Seed đã được nạp hay chưa
      state = state.copyWith(
        statusMessage: '4/10: Kiểm tra dữ liệu từ điển hạt nhân HSK 1-6...',
      );
      debugPrint('[AppStartup] 4/10: Kiểm tra Seed Data...');
      final isSeedReady = await _checkSeedLoaded(db);

      // Bước 5: Nạp Seed cần thiết nếu chưa có (5,000 từ vựng canonical v2)
      if (!isSeedReady) {
        state = state.copyWith(
          statusMessage: '5/10: Nạp 5,000 từ vựng HSK 1-6 chuẩn vào SQLite...',
        );
        debugPrint('[AppStartup] 5/10: Nạp canonical seed từ $canonicalSeedAssetPath...');
        final seedLoader = SeedLoader(db);
        final seedResult = await seedLoader.seedFromAsset(
          canonicalSeedAssetPath,
          bundle: assetBundle,
          onProgress: (p) {
            state = state.copyWith(
              statusMessage: '5/10: [Từ điển] ${p.message}',
            );
          },
        );
        if (!seedResult.success) {
          throw StateError('Nạp dữ liệu từ điển thất bại: ${seedResult.errorMessage}');
        }
        debugPrint('[AppStartup] 5/10: Hoàn tất nạp Seed (${seedResult.message ?? "thành công"}).');
      } else {
        debugPrint('[AppStartup] 5/10: Dữ liệu từ điển đã sẵn sàng. Bỏ qua nạp lại.');
      }

      await SeedLoader(db).seedGradedReadingPassages(bundle: assetBundle);

      // Bước 6 & 7: Kiểm tra và nạp các Content Pack bắt buộc
      final packManager = ContentPackManager(db);

      for (int i = 0; i < mandatoryPacks.length; i++) {
        final pack = mandatoryPacks[i];
        state = state.copyWith(
          statusMessage: '6/10: Kiểm tra gói học liệu ${pack.title}...',
        );
        debugPrint('[AppStartup] 6/10: Kiểm tra gói ${pack.packId} (${pack.curriculumId})...');

        final needsImport = await _checkPackNeedsImport(db, pack);
        if (needsImport) {
          state = state.copyWith(
            statusMessage: '7/10: Cài đặt gói ${pack.title}...',
          );
          debugPrint('[AppStartup] 7/10: Cài đặt gói ${pack.packId} từ ${pack.assetPath}...');
          final rawJson = await assetBundle.loadString(pack.assetPath);
          final result = await packManager.installOrUpdatePack(rawJson, isBundled: true);
          if (!result.isSuccess) {
            throw StateError('Cài đặt gói ${pack.packId} thất bại: ${result.errorMessage}');
          }
          debugPrint('[AppStartup] 7/10: Cài đặt thành công ${pack.packId}: ${result.installedLessonsCount} bài học.');
        } else {
          debugPrint('[AppStartup] 7/10: Gói ${pack.packId} đã đầy đủ. Bỏ qua.');
        }
      }

      // Bước 8: Xác minh tính toàn vẹn dữ liệu sau khi import
      state = state.copyWith(
        statusMessage: '8/10: Xác minh tính toàn vẹn dữ liệu giáo trình...',
      );
      debugPrint('[AppStartup] 8/10: Xác minh dữ liệu giáo trình...');
      await _verifyDataIntegrity(db);

      // Bước 9: Khởi tạo các service phụ thuộc vào dữ liệu học tập
      state = state.copyWith(
        statusMessage: '9/10: Khởi tạo các dịch vụ học tập & cài đặt người dùng...',
      );
      debugPrint('[AppStartup] 9/10: Khởi tạo dịch vụ học tập phụ thuộc...');
      await _initializeDependentServices(
        db,
        credentialStorage: credentialStorageOverride,
      );

      // Bước 10: Chuyển ứng dụng sang trạng thái sẵn sàng
      state = state.copyWith(
        statusMessage: '10/10: Hoàn tất khởi động hệ thống',
      );
      debugPrint('[AppStartup] 10/10: Chuyển sang isReady = true.');

      // Brief yield for smooth UI animation
      await Future<void>.delayed(const Duration(milliseconds: 50));

      state = state.copyWith(
        isInitializing: false,
        isReady: true,
        error: null,
        statusMessage: 'Hệ thống sẵn sàng',
      );
    } catch (e, stackTrace) {
      debugPrint('[AppStartup] Initialization error: $e\n$stackTrace');
      state = state.copyWith(
        isInitializing: false,
        isReady: false,
        error: 'Khởi tạo dữ liệu thất bại: ${e.toString()}',
        statusMessage: 'Khởi tạo thất bại',
      );
    }
  }

  Future<bool> _checkSeedLoaded(Database db) async {
    final history = await db.query(
      DatabaseConstants.tableSeedHistory,
      where: 'bundle_name = ? AND status = ?',
      whereArgs: [canonicalSeedBundleName, 'completed'],
      limit: 1,
    );
    if (history.isEmpty) return false;

    final countRes = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tableVocabularies}',
    );
    final count = Sqflite.firstIntValue(countRes) ?? 0;
    return count >= minimumExpectedVocabCount;
  }

  Future<bool> _checkPackNeedsImport(Database db, MandatoryPackInfo pack) async {
    final packRow = await db.query(
      DatabaseConstants.tableContentPacks,
      where: 'id = ? AND status IN (?, ?)',
      whereArgs: [pack.packId, 'installed', 'bundled'],
      limit: 1,
    );
    if (packRow.isEmpty) return true;

    final lessonsRes = await db.rawQuery('''
      SELECT COUNT(*) as cnt 
      FROM ${DatabaseConstants.tableCurriculumLessons} 
      WHERE unit_id IN (
        SELECT id FROM ${DatabaseConstants.tableCurriculumUnits} WHERE curriculum_id = ?
      )
    ''', [pack.curriculumId]);
    final lessonCount = Sqflite.firstIntValue(lessonsRes) ?? 0;
    return lessonCount == 0;
  }

  Future<void> _verifyDataIntegrity(Database db) async {
    // 1. Verify curr_hsk1 exists and has lessons
    final hsk1LessonsRes = await db.rawQuery('''
      SELECT COUNT(*) as cnt 
      FROM ${DatabaseConstants.tableCurriculumLessons} 
      WHERE unit_id IN (
        SELECT id FROM ${DatabaseConstants.tableCurriculumUnits} WHERE curriculum_id = ?
      )
    ''', ['curr_hsk1']);
    final hsk1Count = Sqflite.firstIntValue(hsk1LessonsRes) ?? 0;
    if (hsk1Count == 0) {
      throw StateError('Xác minh dữ liệu thất bại: Không tìm thấy bài học cho curr_hsk1');
    }

    // 2. Verify curr_hsk2 exists and has lessons
    final hsk2LessonsRes = await db.rawQuery('''
      SELECT COUNT(*) as cnt 
      FROM ${DatabaseConstants.tableCurriculumLessons} 
      WHERE unit_id IN (
        SELECT id FROM ${DatabaseConstants.tableCurriculumUnits} WHERE curriculum_id = ?
      )
    ''', ['curr_hsk2']);
    final hsk2Count = Sqflite.firstIntValue(hsk2LessonsRes) ?? 0;
    if (hsk2Count == 0) {
      throw StateError('Xác minh dữ liệu thất bại: Không tìm thấy bài học cho curr_hsk2');
    }

    // 3. Verify content_items populated
    final itemsRes = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM ${DatabaseConstants.tableContentItems}',
    );
    final itemsCount = Sqflite.firstIntValue(itemsRes) ?? 0;
    if (itemsCount == 0) {
      throw StateError('Xác minh dữ liệu thất bại: Không tìm thấy mục học liệu trong content_items');
    }
  }

  Future<void> _initializeDependentServices(
    Database db, {
    AiCredentialStorage? credentialStorage,
  }) async {
    // 1. Run idempotent legacy credential migration from SQLite app_settings to FlutterSecureStorage
    try {
      final storage = credentialStorage ?? AiCredentialStorage();
      final migrationResult = await storage.migrateLegacyCredentials(db);
      if (migrationResult.migratedKeys.isNotEmpty) {
        debugPrint(
          '[AppStartup] Đã chuyển đổi thành công ${migrationResult.migratedKeys.length} '
          'khóa nhạy cảm sang bộ nhớ bảo mật an toàn.',
        );
      }
    } catch (e) {
      debugPrint('[AppStartup] Cảnh báo: Di chuyển bảo mật credential thất bại: $e');
    }

    // 2. Ensure default user profile exists for learning analytics and progress recording
    final profiles = await db.query(DatabaseConstants.tableUserProfiles, limit: 1);
    if (profiles.isEmpty) {
      final nowUtc = DateTime.now().toUtc().toIso8601String();
      await db.insert(
        DatabaseConstants.tableUserProfiles,
        {
          'id': 'user_default',
          'display_name': 'Học viên HI Chinese',
          'current_hsk_level': 1,
          'target_hsk_level': 1,
          'purpose': 'daily_communication',
          'timeframe': 'standard',
          'daily_minutes': 15,
          'start_date': nowUtc,
          'interests_json': '[]',
          'avatar_style': 'panda',
          'created_at': nowUtc,
          'updated_at': nowUtc,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    // 3. Preload and synchronize user preferences (Theme, Font Scale, Pinyin) into memory
    try {
      final settingsDao = AppSettingsDao(db);
      final map = await settingsDao.getAllSettings();
      if (map.isNotEmpty) {
        ThemeMode themeMode = ThemeMode.light;
        if (map['theme_mode'] == 'dark') themeMode = ThemeMode.dark;
        if (map['theme_mode'] == 'system') themeMode = ThemeMode.system;
        if (map['theme_mode'] == 'light') themeMode = ThemeMode.light;

        // Synchronize themeModeProvider to avoid visual flashing
        ref.read(themeModeProvider.notifier).setThemeMode(themeMode);

        // Synchronize AppSettings state
        await ref.read(appSettingsProvider.notifier).reloadSettings();
        debugPrint('[AppStartup] Đã đồng bộ cài đặt người dùng: ThemeMode=$themeMode');
      }
    } catch (e) {
      debugPrint('[AppStartup] Cảnh báo: Tải cài đặt người dùng ban đầu thất bại: $e');
    }
  }
}

final appStartupProvider = NotifierProvider<AppStartupNotifier, AppStartupState>(
  AppStartupNotifier.new,
);
