import 'package:flutter_tts/flutter_tts.dart';
import 'settings_service.dart';

/// Text-to-Speech service for accessibility announcements
class TtsService {
  static final TtsService _instance = TtsService._internal();
  factory TtsService() => _instance;
  TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;

  /// Initialize TTS engine with accessibility-optimized settings
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(SettingsService().speechRate); 
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);

    _tts.setStartHandler(() {
      _isSpeaking = true;
    });

    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });

    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      print('TTS Error: $msg');
    });

    _isInitialized = true;
  }

  /// Speak a message immediately, interrupting any current speech
  Future<void> speak(String message) async {
    if (!_isInitialized) await initialize();
    
    await _tts.stop();
    await _tts.speak(message);
  }

  /// Speak a message, waiting for current speech to finish
  Future<void> speakQueued(String message) async {
    if (!_isInitialized) await initialize();
    
    // Wait for current speech to finish
    while (_isSpeaking) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    await _tts.speak(message);
  }

  /// Stop any current speech
  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  /// Set speech rate (0.0 to 1.0, accessibility default is 0.5)
  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate.clamp(0.0, 1.0));
  }

  /// Set pitch (0.5 to 2.0, default is 1.0)
  Future<void> setPitch(double pitch) async {
    await _tts.setPitch(pitch.clamp(0.5, 2.0));
  }

  /// Check if TTS is currently speaking
  bool get isSpeaking => _isSpeaking;

  /// Dispose of TTS resources
  Future<void> dispose() async {
    await _tts.stop();
    _isInitialized = false;
  }
}
