import 'package:flutter/services.dart';
import 'settings_service.dart';

/// Haptic feedback service using Flutter's built-in HapticFeedback API
/// Provides distinct patterns for different alerts
class HapticService {
  static final HapticService _instance = HapticService._internal();
  factory HapticService() => _instance;
  HapticService._internal();

  bool _isInitialized = false;
  final SettingsService _settings = SettingsService();

  /// Initialize haptic service
  Future<void> initialize() async {
    _isInitialized = true;
    await _settings.initialize();
  }

  /// Simple vibration for general feedback
  Future<void> vibrate({int duration = 200}) async {
    if (_settings.vibrationIntensity <= 0) return;
    if (_settings.vibrationIntensity > 0.7) await HapticFeedback.heavyImpact();
    else if (_settings.vibrationIntensity < 0.3) await HapticFeedback.lightImpact();
    else await HapticFeedback.mediumImpact();
  }

  /// Short pulse for turn notifications
  Future<void> turnNotification() async {
    if (_settings.vibrationIntensity <= 0) return;
    await HapticFeedback.lightImpact();
  }

  /// Double vibration for obstacle warning
  Future<void> obstacleWarning() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    await HapticFeedback.heavyImpact();
  }

  /// Rapid pattern for fall detection alert
  Future<void> fallDetected() async {
    for (int i = 0; i < 5; i++) {
      await HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Long sustained vibration for SOS confirmation
  Future<void> sosConfirmation() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 200));
    await HapticFeedback.heavyImpact();
  }

  /// Direction-based haptic (left/right)
  Future<void> directionFeedback({required bool isLeft}) async {
    if (isLeft) {
      // Left: two pulses
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.lightImpact();
    } else {
      // Right: three pulses
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 100));
      await HapticFeedback.lightImpact();
    }
  }

  /// Navigation complete pattern
  Future<void> navigationComplete() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }

  /// Proximity warning - escalating pattern as obstacle gets closer
  Future<void> proximityWarning({int intensity = 1}) async {
    // Intensity 1-3: light to heavy
    for (int i = 0; i < intensity; i++) {
      if (intensity == 1) {
        await HapticFeedback.lightImpact();
      } else if (intensity == 2) {
        await HapticFeedback.mediumImpact();
      } else {
        await HapticFeedback.heavyImpact();
      }
      await Future.delayed(const Duration(milliseconds: 80));
    }
  }

  /// Success feedback - happy confirmation
  Future<void> successFeedback() async {
    await HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.mediumImpact();
  }

  /// Error feedback - two sharp pulses
  Future<void> errorFeedback() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    await HapticFeedback.heavyImpact();
  }

  /// Attention seeking pattern - get user's attention
  Future<void> attentionSeek() async {
    for (int i = 0; i < 3; i++) {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  /// Camera mode change feedback
  Future<void> cameraModeChange({required bool enabled}) async {
    if (enabled) {
      // Camera on: single medium pulse
      await HapticFeedback.mediumImpact();
    } else {
      // Camera off: double light pulse
      await HapticFeedback.lightImpact();
      await Future.delayed(const Duration(milliseconds: 80));
      await HapticFeedback.lightImpact();
    }
  }

  /// Menu selection feedback
  Future<void> menuSelection() async {
    await HapticFeedback.selectionClick();
  }

  /// Button press feedback
  Future<void> buttonPress() async {
    await HapticFeedback.lightImpact();
  }

  /// Cancel any ongoing vibration (no-op for built-in API)
  Future<void> cancel() async {
    // Built-in API doesn't support cancellation
  }

  /// Check if device has vibration capability (assume true)
  bool get hasVibrator => true;
}
