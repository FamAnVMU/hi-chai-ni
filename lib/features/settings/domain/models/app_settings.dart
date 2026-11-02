import 'package:flutter/material.dart';

/// Font scale presets for Chinese character readability.
enum FontScaleOption {
  small(0.85, 'Nhỏ (85%)'),
  standard(1.0, 'Tiêu chuẩn (100%)'),
  large(1.15, 'Lớn (115%)'),
  extraLarge(1.3, 'Rất lớn (130%)');

  final double scale;
  final String labelVi;
  const FontScaleOption(this.scale, this.labelVi);

  static FontScaleOption fromScale(double scale) {
    if (scale <= 0.9) return FontScaleOption.small;
    if (scale <= 1.05) return FontScaleOption.standard;
    if (scale <= 1.2) return FontScaleOption.large;
    return FontScaleOption.extraLarge;
  }
}

/// Speech rate presets for audio pronunciation.
enum SpeechRateOption {
  slow(0.8, 'Chậm (0.8x)'),
  normal(1.0, 'Bình thường (1.0x)'),
  fast(1.2, 'Nhanh (1.2x)');

  final double rate;
  final String labelVi;
  const SpeechRateOption(this.rate, this.labelVi);

  static SpeechRateOption fromRate(double rate) {
    if (rate <= 0.85) return SpeechRateOption.slow;
    if (rate <= 1.1) return SpeechRateOption.normal;
    return SpeechRateOption.fast;
  }
}

/// Storage usage breakdown for SQLite & cache files.
class StorageBreakdown {
  final int dbSizeBytes;
  final int walSizeBytes;
  final int shmSizeBytes;
  final int audioCacheSizeBytes;
  final int totalSizeBytes;

  const StorageBreakdown({
    this.dbSizeBytes = 0,
    this.walSizeBytes = 0,
    this.shmSizeBytes = 0,
    this.audioCacheSizeBytes = 0,
    this.totalSizeBytes = 0,
  });

  String get formattedDbSize => _formatBytes(dbSizeBytes + walSizeBytes + shmSizeBytes);
  String get formattedCacheSize => _formatBytes(audioCacheSizeBytes);
  String get formattedTotalSize => _formatBytes(totalSizeBytes);

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

/// Consolidated App Settings Model.
class AppSettings {
  final ThemeMode themeMode;
  final double fontScale;
  final bool showPinyinByDefault;
  final bool showRubyAnnotation;
  final bool pinyinToneColors;
  final String uiLanguage;
  final double speechRate;
  final bool autoPlayAudio;
  final bool hapticFeedback;

  const AppSettings({
    this.themeMode = ThemeMode.dark,
    this.fontScale = 1.0,
    this.showPinyinByDefault = true,
    this.showRubyAnnotation = true,
    this.pinyinToneColors = true,
    this.uiLanguage = 'vi',
    this.speechRate = 1.0,
    this.autoPlayAudio = true,
    this.hapticFeedback = true,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? fontScale,
    bool? showPinyinByDefault,
    bool? showRubyAnnotation,
    bool? pinyinToneColors,
    String? uiLanguage,
    double? speechRate,
    bool? autoPlayAudio,
    bool? hapticFeedback,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      fontScale: fontScale ?? this.fontScale,
      showPinyinByDefault: showPinyinByDefault ?? this.showPinyinByDefault,
      showRubyAnnotation: showRubyAnnotation ?? this.showRubyAnnotation,
      pinyinToneColors: pinyinToneColors ?? this.pinyinToneColors,
      uiLanguage: uiLanguage ?? this.uiLanguage,
      speechRate: speechRate ?? this.speechRate,
      autoPlayAudio: autoPlayAudio ?? this.autoPlayAudio,
      hapticFeedback: hapticFeedback ?? this.hapticFeedback,
    );
  }
}
