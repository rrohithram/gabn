import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Settings service for managing user preferences
class SettingsService extends ChangeNotifier {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  SharedPreferences? _prefs;

  // Default values
  static const double _defaultTextSize = 18.0;
  static const double _defaultButtonSize = 1.0;
  static const double _defaultContrast = 1.0;

  // Settings keys
  static const String _keyTextSize = 'text_size';
  static const String _keyButtonSize = 'button_size';
  static const String _keyContrast = 'contrast';
  static const String _keyCameraEnabled = 'camera_enabled';
  static const String _keyVibrationIntensity = 'vibration_intensity';
  static const String _keyCommandDelay = 'command_delay';
  static const String _keySpeechRate = 'speech_rate';

  // Current values
  double _textSize = _defaultTextSize;
  double _buttonSize = _defaultButtonSize;
  double _contrast = _defaultContrast;
  bool _cameraEnabled = true;
  double _vibrationIntensity = 0.5; // 0.0 (off) to 1.0 (max)
  int _commandDelay = 0; // 0 to 3000 ms
  double _speechRate = 0.5; // 0.0 to 1.0

  // Getters
  double get textSize => _textSize;
  double get buttonSize => _buttonSize;
  double get contrast => _contrast;
  bool get cameraEnabled => _cameraEnabled;
  double get vibrationIntensity => _vibrationIntensity;
  int get commandDelay => _commandDelay;
  double get speechRate => _speechRate;

  /// Initialize settings service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await loadSettings();
  }

  /// Load settings from storage
  Future<void> loadSettings() async {
    if (_prefs == null) await initialize();

    _textSize = _prefs?.getDouble(_keyTextSize) ?? _defaultTextSize;
    _buttonSize = _prefs?.getDouble(_keyButtonSize) ?? _defaultButtonSize;
    _contrast = _prefs?.getDouble(_keyContrast) ?? _defaultContrast;
    _cameraEnabled = _prefs?.getBool(_keyCameraEnabled) ?? true;
    _vibrationIntensity = _prefs?.getDouble(_keyVibrationIntensity) ?? 0.5;
    _commandDelay = _prefs?.getInt(_keyCommandDelay) ?? 0;
    _speechRate = _prefs?.getDouble(_keySpeechRate) ?? 0.5;

    notifyListeners();
  }

  /// Save text size (12.0 to 32.0)
  Future<void> setTextSize(double size) async {
    _textSize = size.clamp(12.0, 32.0);
    await _prefs?.setDouble(_keyTextSize, _textSize);
    notifyListeners();
  }

  /// Save button size multiplier (0.5 to 2.0)
  Future<void> setButtonSize(double multiplier) async {
    _buttonSize = multiplier.clamp(0.5, 2.0);
    await _prefs?.setDouble(_keyButtonSize, _buttonSize);
    notifyListeners();
  }

  /// Save contrast value (0.5 to 2.0)
  Future<void> setContrast(double contrast) async {
    _contrast = contrast.clamp(0.5, 2.0);
    await _prefs?.setDouble(_keyContrast, _contrast);
    notifyListeners();
  }
  
  /// Save camera state
  Future<void> setCameraEnabled(bool enabled) async {
    _cameraEnabled = enabled;
    await _prefs?.setBool(_keyCameraEnabled, enabled);
    notifyListeners();
  }

  /// Save vibration intensity (0.0 to 1.0)
  Future<void> setVibrationIntensity(double intensity) async {
    _vibrationIntensity = intensity.clamp(0.0, 1.0);
    await _prefs?.setDouble(_keyVibrationIntensity, _vibrationIntensity);
    notifyListeners();
  }

  /// Save command delay (0 to 3000 ms)
  Future<void> setCommandDelay(int delayMs) async {
    _commandDelay = delayMs.clamp(0, 3000);
    await _prefs?.setInt(_keyCommandDelay, _commandDelay);
    notifyListeners();
  }

  /// Save speech rate (0.0 to 1.0)
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.0, 1.0);
    await _prefs?.setDouble(_keySpeechRate, _speechRate);
    notifyListeners();
  }

  /// Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _textSize = _defaultTextSize;
    _buttonSize = _defaultButtonSize;
    _contrast = _defaultContrast;

    await _prefs?.remove(_keyTextSize);
    await _prefs?.remove(_keyButtonSize);
    await _prefs?.remove(_keyContrast);

    notifyListeners();
  }
}

