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
    // Read cached values or defaults
    _loadSettingsAsync();
    return const AppSettings();
  }

  Future<void> _loadSettingsAsync() async {
    try {
      final dao = ref.read(appSettingsDaoProvider);
      final map = await dao.getAllSettings();
      if (map.isEmpty) return;

      ThemeMode themeMode = ThemeMode.dark;
      if (map['theme_mode'] == 'light') themeMode = ThemeMode.light;
      if (map['theme_mode'] == 'system') themeMode = ThemeMode.system;

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

      // Keep themeModeProvider in sync
      ref.read(themeModeProvider.notifier).setThemeMode(themeMode);
    } catch (_) {}
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    ref.read(themeModeProvider.notifier).setThemeMode(mode);
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.setSetting('theme_mode', mode.name);
    } catch (_) {}
  }

  Future<void> setFontScale(double scale) async {
    state = state.copyWith(fontScale: scale);
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.setSetting('font_scale', scale.toString());
    } catch (_) {}
  }

  Future<void> toggleShowPinyin(bool value) async {
    state = state.copyWith(showPinyinByDefault: value);
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.setSetting('show_pinyin', value.toString());
    } catch (_) {}
  }

  Future<void> toggleShowRuby(bool value) async {
    state = state.copyWith(showRubyAnnotation: value);
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.setSetting('show_ruby', value.toString());
    } catch (_) {}
  }

  Future<void> togglePinyinToneColors(bool value) async {
    state = state.copyWith(pinyinToneColors: value);
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.setSetting('pinyin_tone_colors', value.toString());
    } catch (_) {}
  }

  Future<void> setSpeechRate(double rate) async {
    state = state.copyWith(speechRate: rate);
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.setSetting('speech_rate', rate.toString());
    } catch (_) {}
  }

  Future<void> toggleAutoPlayAudio(bool value) async {
    state = state.copyWith(autoPlayAudio: value);
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.setSetting('auto_play_audio', value.toString());
    } catch (_) {}
  }

  Future<void> toggleHapticFeedback(bool value) async {
    state = state.copyWith(hapticFeedback: value);
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.setSetting('haptic_feedback', value.toString());
    } catch (_) {}
  }

  Future<void> setUiLanguage(String lang) async {
    state = state.copyWith(uiLanguage: lang);
    try {
      final dao = ref.read(appSettingsDaoProvider);
      await dao.setSetting('ui_language', lang);
    } catch (_) {}
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

final microphoneStatusProvider = FutureProvider.autoDispose<PermissionStatus>((ref) async {
  return await PermissionHelper.checkMicrophoneStatus();
});
