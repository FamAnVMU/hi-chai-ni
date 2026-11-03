import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hi_chinese/core/database/app_database.dart';
import 'package:hi_chinese/core/database/dao/app_settings_dao.dart';
import 'package:hi_chinese/core/database/database_constants.dart';
import 'package:hi_chinese/core/database/migrations/migration_engine.dart';
import 'package:hi_chinese/core/theme/theme.dart';
import 'package:hi_chinese/core/utils/permission_helper.dart';
import 'package:hi_chinese/features/profile/data/repositories/profile_repository.dart';
import 'package:hi_chinese/features/profile/domain/models/user_profile.dart';
import 'package:hi_chinese/features/profile/presentation/providers/profile_providers.dart';
import 'package:hi_chinese/features/profile/presentation/screens/profile_screen.dart';
import 'package:hi_chinese/features/profile/presentation/widgets/edit_goal_dialog.dart';
import 'package:hi_chinese/features/profile/presentation/widgets/edit_profile_sheet.dart';
import 'package:hi_chinese/features/profile/presentation/widgets/goal_history_sheet.dart';
import 'package:hi_chinese/features/roadmap/domain/models/roadmap_models.dart';
import 'package:hi_chinese/features/settings/data/services/data_management_service.dart';
import 'package:hi_chinese/features/settings/domain/models/app_settings.dart';
import 'package:hi_chinese/features/settings/presentation/providers/settings_providers.dart';
import 'package:hi_chinese/features/settings/presentation/widgets/data_management_sheet.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Database db;
  late Directory tempDir;
  late String dbPath;
  late ProfileRepository profileRepo;
  late AppSettingsDao settingsDao;
  late DataManagementService dataService;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('profile_settings_test_');
    dbPath = '${tempDir.path}/test_profile.db';
    db = await databaseFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: DatabaseConstants.currentDatabaseVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
          await db.rawQuery('PRAGMA journal_mode = WAL;');
        },
        onCreate: (db, ver) async {
          final engine = MigrationEngine();
          await engine.executeMigrations(db, 0, ver);
        },
      ),
    );

    profileRepo = DefaultProfileRepository(db);
    settingsDao = AppSettingsDao(db);
    dataService = DataManagementService(db, dbPath);
  });

  tearDown(() async {
    if (dataService.db.isOpen) {
      await dataService.db.close();
    }
    if (db.isOpen) {
      await db.close();
    }
    await AppDatabase.instance.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // ==================== 1. PROFILE REPOSITORY & GOAL HISTORY TESTS ====================
  group('ProfileRepository & Goal History Integration Tests', () {
    test('1. getProfile returns default profile when table is empty and persists it', () async {
      final profile = await profileRepo.getProfile();
      expect(profile.displayName, 'Người học HI Chinese');
      expect(profile.currentHskLevel, 1);
      expect(profile.targetHskLevel, 3);
      expect(profile.dailyMinutes, 30);
      expect(profile.purpose, LearnerPurpose.dailyCommunication);
      expect(profile.avatarStyle, 'panda');

      // Verify persisted row
      final rows = await db.query(DatabaseConstants.tableUserProfiles);
      expect(rows.length, 1);
    });

    test('2. saveProfile updates display name, avatar, and interests', () async {
      final initial = await profileRepo.getProfile();
      final updated = initial.copyWith(
        displayName: 'Minh Trí',
        avatarStyle: 'dragon',
        interests: ['food', 'travel', 'business'],
      );

      await profileRepo.saveProfile(updated);
      final fetched = await profileRepo.getProfile();

      expect(fetched.displayName, 'Minh Trí');
      expect(fetched.avatarStyle, 'dragon');
      expect(fetched.interests, containsAll(['food', 'travel', 'business']));
    });

    test('3. updateGoal adjusts target and logs meaningful GoalHistoryRecord', () async {
      await profileRepo.getProfile(); // Ensure seeded

      await profileRepo.updateGoal(
        targetHskLevel: 4,
        dailyMinutes: 45,
        purpose: LearnerPurpose.businessWork,
        reason: 'Chuẩn bị đi công tác Thượng Hải vào quý 3',
      );

      final profile = await profileRepo.getProfile();
      expect(profile.targetHskLevel, 4);
      expect(profile.dailyMinutes, 45);
      expect(profile.purpose, LearnerPurpose.businessWork);

      final history = await profileRepo.getGoalHistory();
      expect(history.length, 1);
      expect(history.first.previousTargetHsk, 3);
      expect(history.first.newTargetHsk, 4);
      expect(history.first.previousDailyMinutes, 30);
      expect(history.first.newDailyMinutes, 45);
      expect(history.first.previousPurpose, LearnerPurpose.dailyCommunication);
      expect(history.first.newPurpose, LearnerPurpose.businessWork);
      expect(history.first.reason, 'Chuẩn bị đi công tác Thượng Hải vào quý 3');

      // Add a second goal change
      await profileRepo.updateGoal(
        targetHskLevel: 5,
        dailyMinutes: 60,
        purpose: LearnerPurpose.hskExam,
        reason: 'Đã hoàn thành mục tiêu giao tiếp, chuyển sang thi chứng chỉ HSK 5',
      );

      final updatedHistory = await profileRepo.getGoalHistory();
      expect(updatedHistory.length, 2);
      expect(updatedHistory.first.newTargetHsk, 5); // Descending by date
      expect(updatedHistory.first.reason, contains('chứng chỉ HSK 5'));
    });
  });

  // ==================== 2. APP SETTINGS & DAO TESTS ====================
  group('AppSettingsDao & Provider Persistence Tests', () {
    test('1. AppSettingsDao can save and retrieve settings cleanly', () async {
      expect(await settingsDao.getSetting('theme_mode'), isNull);

      await settingsDao.setSetting('theme_mode', 'light');
      await settingsDao.setSetting('font_scale', '1.15');
      await settingsDao.setSetting('show_pinyin', 'false');

      expect(await settingsDao.getSetting('theme_mode'), 'light');
      expect(await settingsDao.getSetting('font_scale'), '1.15');
      expect(await settingsDao.getSetting('show_pinyin'), 'false');

      final all = await settingsDao.getAllSettings();
      expect(all.length, 3);
      expect(all['theme_mode'], 'light');
    });

    test('2. AppSettingsNotifier updates in-memory state and calls DAO', () async {
      final container = ProviderContainer(
        overrides: [
          appSettingsDaoProvider.overrideWithValue(settingsDao),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(appSettingsProvider.notifier);

      await notifier.setThemeMode(ThemeMode.light);
      expect(container.read(appSettingsProvider).themeMode, ThemeMode.light);
      expect(await settingsDao.getSetting('theme_mode'), 'light');

      await notifier.setFontScale(1.3);
      expect(container.read(appSettingsProvider).fontScale, 1.3);
      expect(await settingsDao.getSetting('font_scale'), '1.3');

      await notifier.toggleShowPinyin(false);
      expect(container.read(appSettingsProvider).showPinyinByDefault, false);

      await notifier.setSpeechRate(0.8);
      expect(container.read(appSettingsProvider).speechRate, 0.8);

      await notifier.setUiLanguage('en');
      expect(container.read(appSettingsProvider).uiLanguage, 'en');
    });
  });

  // ==================== 3. DATA MANAGEMENT & DESTRUCTIVE PROTECTION TESTS ====================
  group('DataManagementService & Destructive Protection Tests', () {
    test('1. checkIntegrity returns no errors on healthy database', () async {
      final issues = await dataService.checkIntegrity();
      expect(issues, isEmpty);
    });

    test('2. createBackup generates a valid .hibak file', () async {
      final backup = await dataService.createBackup();
      expect(await backup.exists(), isTrue);
      expect(backup.path.endsWith('.hibak'), isTrue);

      final backups = await dataService.listBackups();
      expect(backups.length, 1);
      expect(backups.first.path, backup.path);
    });

    test('3. exportUserDataJson returns formatted JSON containing tables', () async {
      await profileRepo.getProfile();
      final jsonStr = await dataService.exportUserDataJson();
      expect(jsonStr, contains('"app_name": "HI Chinese"'));
      expect(jsonStr, contains('user_profiles'));
      expect(jsonStr, contains('schema_version'));
    });

    test('4. clearAllUserData rejects incorrect confirmation code', () async {
      expect(
        () => dataService.clearAllUserData(confirmationCode: 'KHONG'),
        throwsA(isA<DestructiveActionException>()),
      );
    });

    test('5. clearAllUserData creates safety backup and clears user progress tables', () async {
      // Seed some user data
      await profileRepo.getProfile();
      await profileRepo.updateGoal(
        targetHskLevel: 4,
        dailyMinutes: 45,
        purpose: LearnerPurpose.hskExam,
        reason: 'Test reset',
      );

      final backupsBefore = await dataService.listBackups();
      final initialBackupCount = backupsBefore.length;

      // Execute destructive clear with correct confirmation code
      await dataService.clearAllUserData(confirmationCode: 'RESET');

      // 1. Pre-destruction safety snapshot must be generated
      final backupsAfter = await dataService.listBackups();
      expect(backupsAfter.length, initialBackupCount + 1);
      expect(backupsAfter.any((b) => b.path.contains('pre_destruction_safety_snapshot')), isTrue);

      // 2. Goal history must be cleared
      final history = await profileRepo.getGoalHistory();
      expect(history, isEmpty);

      // 3. Clean fresh default profile must be re-seeded
      final freshProfile = await profileRepo.getProfile();
      expect(freshProfile.targetHskLevel, 3);
      expect(freshProfile.displayName, 'Người học HI Chinese');
    });

    test('6. restoreBackup safely flushes WAL, closes connection, restores file, and reconnects', () async {
      // 1. Establish state and take a backup
      final initialProfile = await profileRepo.getProfile();
      await profileRepo.saveProfile(initialProfile.copyWith(displayName: 'Backup Pioneer'));
      final backupFile = await dataService.createBackup(customName: 'test_restore_target.hibak');
      expect(await backupFile.exists(), isTrue);

      // 2. Modify state after backup
      final currentProfile = await profileRepo.getProfile();
      await profileRepo.saveProfile(currentProfile.copyWith(displayName: 'Altered Pioneer'));
      final modifiedProfile = await profileRepo.getProfile();
      expect(modifiedProfile.displayName, 'Altered Pioneer');

      // 3. Restore from backup
      await dataService.restoreBackup(backupFile);

      // 4. Verify DB was reconnected and data reverted to backup state
      final restoredRepo = DefaultProfileRepository(dataService.db);
      final restoredProfile = await restoredRepo.getProfile();
      expect(restoredProfile.displayName, 'Backup Pioneer');
    });
  });

  // ==================== 4. AUDIO & MICROPHONE PERMISSION TESTS ====================
  group('Audio & Microphone Permission Tests', () {
    test('1. checkMicrophoneStatus reflects granted mock status', () async {
      PermissionHelper.mockPermissionStatus = PermissionStatus.granted;
      final status = await PermissionHelper.checkMicrophoneStatus();
      expect(status.isGranted, isTrue);
      PermissionHelper.mockPermissionStatus = null;
    });

    test('2. checkMicrophoneStatus reflects denied mock status', () async {
      PermissionHelper.mockPermissionStatus = PermissionStatus.denied;
      final status = await PermissionHelper.checkMicrophoneStatus();
      expect(status.isDenied, isTrue);
      PermissionHelper.mockPermissionStatus = null;
    });
  });

  // ==================== 5. WIDGET TESTS ====================
  group('ProfileScreen & Settings Widget Tests', () {
    late FakeProfileRepository fakeProfileRepo;

    setUp(() {
      fakeProfileRepo = FakeProfileRepository();
    });

    Widget buildTestableWidget() {
      return ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(fakeProfileRepo),
          appSettingsDaoProvider.overrideWithValue(settingsDao),
          dataManagementServiceProvider.overrideWithValue(dataService),
          microphoneStatusProvider.overrideWith((ref) => Future.value(PermissionStatus.granted)),
          storageBreakdownProvider.overrideWith((ref) => Future.value(const StorageBreakdown(dbSizeBytes: 10240, totalSizeBytes: 20480))),
          backupListProvider.overrideWith((ref) => Future.value([])),
        ],
        child: MaterialApp(
          theme: AppTheme.darkTheme,
          home: const ProfileScreen(),
        ),
      );
    }

    testWidgets('1. Renders Profile Header, Goal Summary, Theme Selector, and Action Tiles', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      expect(find.text('Cá Nhân & Cài Đặt'), findsOneWidget);
      expect(find.text('Người học HI Chinese'), findsOneWidget);
      expect(find.text('HSK 1'), findsOneWidget);
      expect(find.textContaining('Mục tiêu: HSK 3'), findsOneWidget);
      expect(find.text('Sửa hồ sơ'), findsOneWidget);
      expect(find.text('Đổi mục tiêu'), findsOneWidget);
      expect(find.text('Giao Diện & Tùy Chọn Đọc'), findsOneWidget);
      expect(find.text('Âm Thanh & Giọng Đọc'), findsOneWidget);
      expect(find.text('Cài đặt AI Tutor & Chẩn đoán kết nối'), findsOneWidget);
      expect(find.text('Quản lý Dữ liệu & Sao lưu'), findsOneWidget);
    });

    testWidgets('2. Tapping "Sửa hồ sơ" opens EditProfileSheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Tap Sửa hồ sơ
      await tester.tap(find.text('Sửa hồ sơ'));
      await tester.pumpAndSettle();

      expect(find.byType(EditProfileSheet), findsOneWidget);
      expect(find.text('Chỉnh Sửa Hồ Sơ Học Tập'), findsOneWidget);
      expect(find.text('Tên hiển thị (Tùy chọn)'), findsOneWidget);
    });

    testWidgets('3. Tapping "Đổi mục tiêu" opens EditGoalDialog and validates reason requirement', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      // Tap Đổi mục tiêu
      await tester.tap(find.text('Đổi mục tiêu'));
      await tester.pumpAndSettle();

      expect(find.byType(EditGoalDialog), findsOneWidget);
      expect(find.text('Điều Chỉnh Mục Tiêu Học Tập'), findsOneWidget);

      // Attempt to submit with empty reason -> validation error
      await tester.tap(find.text('Lưu Thay Đổi'));
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập lý do thay đổi mục tiêu để lưu lịch sử.'), findsOneWidget);
    });

    testWidgets('4. Tapping "Xem lịch sử mục tiêu" opens GoalHistorySheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Xem lịch sử mục tiêu'));
      await tester.pumpAndSettle();

      expect(find.byType(GoalHistorySheet), findsOneWidget);
      expect(find.text('Lịch Sử Thay Đổi Mục Tiêu'), findsOneWidget);
    });

    testWidgets('5. Tapping "Quản lý Dữ liệu & Sao lưu" opens DataManagementSheet', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quản lý Dữ liệu & Sao lưu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(DataManagementSheet), findsOneWidget);
      expect(find.text('Quản Lý Dữ Liệu & Bộ Nhớ'), findsOneWidget);
      expect(find.text('Vùng Nguy Hiểm (Danger Zone)'), findsOneWidget);
    });

    testWidgets('6. Destructive reset dialog enforces mandatory code confirmation', (tester) async {
      await tester.binding.setSurfaceSize(const Size(600, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildTestableWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Quản lý Dữ liệu & Sao lưu'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Ensure Destructive button is visible and tap
      final resetBtnFinder = find.text('Đặt Lại Dữ Liệu & Tiến Trình...');
      await tester.ensureVisible(resetBtnFinder);
      await tester.pumpAndSettle();
      await tester.tap(resetBtnFinder);
      await tester.pumpAndSettle();

      expect(find.text('VÙNG NGUY HIỂM: ĐẶT LẠI'), findsOneWidget);
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Xác nhận XÓA CỤC BỘ');
      expect(confirmBtn, findsOneWidget);

      // Confirm button is disabled initially
      final btnWidget = tester.widget<ElevatedButton>(confirmBtn);
      expect(btnWidget.onPressed, isNull);

      // Enter wrong code
      await tester.enterText(find.byType(TextField), 'SAI');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(confirmBtn).onPressed, isNull);

      // Enter valid code 'RESET'
      await tester.enterText(find.byType(TextField), 'RESET');
      await tester.pump();
      expect(tester.widget<ElevatedButton>(confirmBtn).onPressed, isNotNull);

      // Dismiss dialog safely
      await tester.tap(find.text('Hủy bỏ'));
      await tester.pumpAndSettle();
    });
  });
}

class FakeProfileRepository implements ProfileRepository {
  UserProfile profile = UserProfile.defaultProfile();
  List<GoalHistoryRecord> history = [];

  @override
  Future<UserProfile> getProfile() async => profile;

  @override
  Future<void> saveProfile(UserProfile p) async {
    profile = p;
  }

  @override
  Future<void> updateGoal({
    required int targetHskLevel,
    required int dailyMinutes,
    required LearnerPurpose purpose,
    required String reason,
  }) async {
    final record = GoalHistoryRecord(
      id: 'gh_1',
      previousTargetHsk: profile.targetHskLevel,
      newTargetHsk: targetHskLevel,
      previousDailyMinutes: profile.dailyMinutes,
      newDailyMinutes: dailyMinutes,
      previousPurpose: profile.purpose,
      newPurpose: purpose,
      reason: reason,
      changedAt: DateTime.now(),
    );
    history.insert(0, record);
    profile = profile.copyWith(
      targetHskLevel: targetHskLevel,
      dailyMinutes: dailyMinutes,
      purpose: purpose,
    );
  }

  @override
  Future<List<GoalHistoryRecord>> getGoalHistory() async => history;
}
