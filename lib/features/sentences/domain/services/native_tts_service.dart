import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract class NativeTtsService {
  Future<bool> initialize();
  Future<bool> isLanguageAvailable();
  Future<void> speak(String text, {double speed = 1.0});
  Future<void> pause();
  Future<void> stop();
  Stream<bool> get isSpeakingStream;
  bool get isSpeaking;
  void dispose();
}

/// Native OS Text-to-Speech service using Android TextToSpeech / iOS AVSpeechSynthesizer
class DefaultNativeTtsService implements NativeTtsService {
  final FlutterTts _flutterTts;
  bool _isSpeaking = false;
  bool _isInitialized = false;
  final _speakingController = StreamController<bool>.broadcast();

  DefaultNativeTtsService({FlutterTts? flutterTts})
      : _flutterTts = flutterTts ?? FlutterTts();

  @override
  Stream<bool> get isSpeakingStream => _speakingController.stream;

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      await _flutterTts.setLanguage('zh-CN');
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setSpeechRate(0.5); // Default normal speed on Android/iOS

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        _speakingController.add(true);
      });

      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        _speakingController.add(false);
      });

      _flutterTts.setErrorHandler((msg) {
        _isSpeaking = false;
        _speakingController.add(false);
        debugPrint('[NativeTtsService] TTS error: $msg');
      });

      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('[NativeTtsService] Initialization error: $e');
      return false;
    }
  }

  @override
  Future<bool> isLanguageAvailable() async {
    try {
      await initialize();
      final available = await _flutterTts.isLanguageAvailable('zh-CN');
      return available == 1 || available == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> speak(String text, {double speed = 1.0}) async {
    await initialize();
    try {
      // Map speed (0.5x .. 1.5x) to FlutterTts rate (default 0.5 is normal speed)
      final rate = (0.5 * speed).clamp(0.25, 1.0);
      await _flutterTts.setSpeechRate(rate);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('[NativeTtsService] Speak error: $e');
    }
  }

  @override
  Future<void> pause() async {
    try {
      await _flutterTts.pause();
    } catch (_) {}
  }

  @override
  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
      _speakingController.add(false);
    } catch (_) {}
  }

  @override
  void dispose() {
    stop();
    _speakingController.close();
  }
}
