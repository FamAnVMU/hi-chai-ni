import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract class TtsService {
  Future<bool> isLanguageAvailable(String language);
  Future<List<String>> getAvailableVoices();
  Future<void> speak(
    String text, {
    String language = 'zh-CN',
    double rate = 0.5,
    double pitch = 1.0,
    double volume = 1.0,
    String? voiceName,
  });
  Future<void> stop();
  void dispose();
}

class DefaultTtsService implements TtsService {
  /// Global default user-configured speech rate multiplier (`0.8` / `1.0` / `1.2`),
  /// synced from [AppSettings.speechRate] whenever settings load or change.
  static double defaultSpeechRate = 1.0;

  /// Converts an app speech-rate multiplier (`0.8 / 1.0 / 1.2`) into the
  /// `flutter_tts` rate scale (`0.4 / 0.5 / 0.6`).
  static double toTtsRate(double speechRate) => (speechRate * 0.5).clamp(0.2, 1.0);

  final FlutterTts _flutterTts;

  DefaultTtsService({FlutterTts? flutterTts}) : _flutterTts = flutterTts ?? FlutterTts() {
    _initTts();
  }

  void _initTts() {
    try {
      _flutterTts.awaitSpeakCompletion(true).catchError((_) {});
      _flutterTts.setErrorHandler((msg) {
        debugPrint('[TtsService] Error: $msg');
      });
    } catch (e) {
      debugPrint('[TtsService] Init error: $e');
    }
  }

  @override
  Future<bool> isLanguageAvailable(String language) async {
    try {
      final res = await _flutterTts.isLanguageAvailable(language);
      return res == 1 || res == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<List<String>> getAvailableVoices() async {
    try {
      final voices = await _flutterTts.getVoices;
      if (voices is List) {
        return voices.map((v) => v.toString()).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> speak(
    String text, {
    String language = 'zh-CN',
    double rate = 0.5,
    double pitch = 1.0,
    double volume = 1.0,
    String? voiceName,
  }) async {
    try {
      await _flutterTts.stop();
      try {
        await _flutterTts.awaitSpeakCompletion(true);
      } catch (_) {}
      await _flutterTts.setLanguage(language);
      final effectiveRate = rate == 0.5 ? toTtsRate(defaultSpeechRate) : rate;
      await _flutterTts.setSpeechRate(effectiveRate);
      await _flutterTts.setPitch(pitch);
      await _flutterTts.setVolume(volume);

      if (voiceName != null && voiceName.isNotEmpty) {
        try {
          await _flutterTts.setVoice({'name': voiceName, 'locale': language});
        } catch (_) {}
      }

      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('[TtsService] Speak error: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    try {
      _flutterTts.stop().catchError((_) => 0);
    } catch (_) {}
  }
}
