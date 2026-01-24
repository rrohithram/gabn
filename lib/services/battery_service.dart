import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';

/// Battery service for getting battery level
class BatteryService {
  static final BatteryService _instance = BatteryService._internal();
  factory BatteryService() => _instance;
  BatteryService._internal();

  final Battery _battery = Battery();
  int? _lastBatteryLevel;

  /// Get current battery level (0-100)
  Future<int> getBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      _lastBatteryLevel = level;
      return level;
    } catch (e) {
      debugPrint('Error getting battery level: $e');
      return _lastBatteryLevel ?? 0;
    }
  }

  /// Get battery state
  Future<BatteryState> getBatteryState() async {
    try {
      return await _battery.batteryState;
    } catch (e) {
      debugPrint('Error getting battery state: $e');
      return BatteryState.unknown;
    }
  }

  /// Get battery level as formatted string
  Future<String> getBatteryLevelString() async {
    final level = await getBatteryLevel();
    final state = await getBatteryState();
    
    String stateText = '';
    if (state == BatteryState.charging) {
      stateText = ' and charging';
    } else if (state == BatteryState.full) {
      stateText = ' and fully charged';
    }
    
    return '$level percent$stateText';
  }
}

