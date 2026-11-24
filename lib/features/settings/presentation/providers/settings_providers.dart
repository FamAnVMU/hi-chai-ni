import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/dao/app_settings_dao.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/permission_helper.dart';
import '../../data/services/data_management_service.dart';
import '../../domain/models/app_settings.dart';

final appSettingsDaoProvider = Provider<AppSettingsDao>((ref) {
  final db = ref.watch(appDatabaseProvider).database;
  return AppSettingsDao(db);
});

final dataManagementServiceProvider = Provider<DataManagementService>((ref) {
  final appDb = ref.watch(appDatabaseProvider);
  return DataManagementService(appDb.database, appDb.path ?? '');
});

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    ref.watch(databaseGenerationProvider);
    Future.microtask(_loadSettingsAsync);
    return const AppSettings();
  }

  Future<AppSettingsDao> _resolveDao({AppSettingsDao? daoOverride}) async {
    if (daoOverride != null) return daoOverride;
    AppSettingsDao? existingDao;
    try {
      existingDao = ref.read(appSettingsDaoProvider);
    } on StateError {
      existingDao = null;
    }
    if (existingDao != null) return existingDao;

    final db = await ref.read(appDatabaseProvider).ensureOpen();
    if (ref.mounted) {
      ref.invalidate(appSettingsDaoProvider);
    }
    return AppSettingsDao(db);
  }

  /// Synchronously or asynchronously re-syncs state from the database.
  Future<void> reloadSettings({AppSettingsDao? daoOverride}) async {
    await _loadSettingsAsync(daoOverride: daoOverride);
  }

  Future<void> _loadSettingsAsync({AppSettingsDao? daoOverride}) async {
    if (!ref.mounted) return;
    try {
      final dao = await _resolveDao(daoOverride: daoOverride);
      if (!ref.mounted) return;
      final map = await dao.getAllSettings();
      if (!ref.mounted || map.isEmpty) return;

      ThemeMode themeMode = ThemeMode.light;
      if (map['theme_mode'] == 'dark') themeMode = ThemeMode.dark;
      if (map['theme_mode'] == 'system') themeMode = ThemeMode.system;
      if (map['theme_mode'] == 'light') themeMode = ThemeMode.light;

      final fontScale = double.tryParse(map['font_scale'] ?? '') ?? 1.0;
      final showPinyin = map['show_pinyin'] != 'false';
      final showRuby = map['show_ruby'] != 'false';
      final pinyinToneColors = map['pinyin_tone_colors'] != 'false';
      final speechRate = double.tryParse(map['speech_rate'] ?? '') ?? 1.0;
      final autoPlay = map['auto_play_audio'] != 'false';
      final haptic = map['haptic_feedback'] != 'false';
      final lang = map['ui_language'] ?? 'vi';

      state = AppSettings(
        themeMode: themeMode,
        fontScale: fontScale,
        showPinyinByDefault: showPinyin,
        showRubyAnnotation: showRuby,
        pinyinToneColors: pinyinToneColors,
        uiLanguage: lang,
        speechRate: speechRate,
        autoPlayAudio: autoPlay,
        hapticFeedback: haptic,
      );

      ref.read(themeModeProvider.notifier).setThemeMode(themeMode);
    } catch (e, st) {
      debugPrint('[AppSettingsNotifier] Failed to load settings: $e\n$st');
    }
  }

  Future<void> _persistSetting(String key, String value) async {
    try {
      final dao = await _resolveDao();
      await dao.setSetting(key, value);
    } catch (e, st) {
      debugPrint('[AppSettingsNotifier] Failed to persist "$key": $e\n$st');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    ref.read(themeModeProvider.notifier).setThemeMode(mode);
    await _persistSetting('theme_mode', mode.name);
  }

  Future<void> setFontScale(double scale) async {
    state = state.copyWith(fontScale: scale);
    await _persistSetting('font_scale', scale.toString());
  }

  Future<void> toggleShowPinyin(bool value) async {
    state = state.copyWith(showPinyinByDefault: value);
    await _persistSetting('show_pinyin', value.toString());
  }

  Future<void> toggleShowRuby(bool value) async {
    state = state.copyWith(showRubyAnnotation: value);
    await _persistSetting('show_ruby', value.toString());
  }

  Future<void> togglePinyinToneColors(bool value) async {
    state = state.copyWith(pinyinToneColors: value);
    await _persistSetting('pinyin_tone_colors', value.toString());
  }

  Future<void> setSpeechRate(double rate) async {
    state = state.copyWith(speechRate: rate);
    await _persistSetting('speech_rate', rate.toString());
  }

  Future<void> toggleAutoPlayAudio(bool value) async {
    state = state.copyWith(autoPlayAudio: value);
    await _persistSetting('auto_play_audio', value.toString());
  }

  Future<void> toggleHapticFeedback(bool value) async {
    state = state.copyWith(hapticFeedback: value);
    await _persistSetting('haptic_feedback', value.toString());
  }

  Future<void> setUiLanguage(String lang) async {
    state = state.copyWith(uiLanguage: lang);
    await _persistSetting('ui_language', lang);
  }
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

final fontScaleProvider = Provider<double>((ref) {
  return ref.watch(appSettingsProvider).fontScale;
});

final storageBreakdownProvider = FutureProvider.autoDispose<StorageBreakdown>((ref) async {
  final service = ref.watch(dataManagementServiceProvider);
  return await service.getStorageBreakdown();
});

final backupListProvider = FutureProvider.autoDispose<List<File>>((ref) async {
  final service = ref.watch(dataManagementServiceProvider);
  return await service.listBackups();
});

final backupFileInfosProvider = FutureProvider.autoDispose<List<BackupFileInfo>>((ref) async {
  final service = ref.watch(dataManagementServiceProvider);
  return await service.listBackupInfos();
});

final microphoneStatusProvider = FutureProvider.autoDispose<PermissionStatus>((ref) async {
  return await PermissionHelper.checkMicrophoneStatus();
});
