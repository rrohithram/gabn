import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Gesture service for handling hardware button gestures
class GestureService {
  static final GestureService _instance = GestureService._internal();
  factory GestureService() => _instance;
  GestureService._internal();

  MethodChannel? _channel;
  bool _isInitialized = false;
  
  // Volume button tracking
  DateTime? _lastVolumePress;
  static const Duration _doublePressWindow = Duration(milliseconds: 500);
  int _volumePressCount = 0;
  Timer? _volumePressTimer;

  // Callbacks
  VoidCallback? onVolumeDoublePress;
  VoidCallback? onVolumeLongPress;
  VoidCallback? onVolumeTriplePress;

  /// Initialize gesture service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        _channel = const MethodChannel('com.gabn2/gestures');
        
        // Set up method call handler
        _channel?.setMethodCallHandler(_handleMethodCall);
        
        // Start listening for volume button events
        await _channel?.invokeMethod('startVolumeButtonListener');
      }
      
      _isInitialized = true;
      debugPrint('Gesture service initialized');
    } catch (e) {
      debugPrint('Gesture service initialization error: $e');
      // Continue without gestures if not supported
    }
  }

  /// Handle method calls from native side
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'volumeButtonPressed':
        _handleVolumeButtonPress();
        break;
      default:
        debugPrint('Unknown method call: ${call.method}');
    }
  }

  /// Handle volume button press
  void _handleVolumeButtonPress() {
    final now = DateTime.now();
    
    if (_lastVolumePress == null || 
        now.difference(_lastVolumePress!) > _doublePressWindow) {
      // First press or too much time passed
      _volumePressCount = 1;
      _lastVolumePress = now;
      
      // Start timer to reset count
      _volumePressTimer?.cancel();
      _volumePressTimer = Timer(_doublePressWindow, () {
        _volumePressCount = 0;
      });
    } else {
      // Second press within window
      _volumePressCount++;
      _volumePressTimer?.cancel();
      
      if (_volumePressCount >= 3) {
        // Triple press detected (voice command)
        onVolumeTriplePress?.call();
        _volumePressCount = 0;
        _lastVolumePress = null;
      } else if (_volumePressCount >= 2) {
        // Double press detected (photo capture)
        onVolumeDoublePress?.call();
        _volumePressCount = 0;
        _lastVolumePress = null;
      }
    }
  }

  /// Manually trigger volume double press (for testing)
  void triggerVolumeDoublePress() {
    onVolumeDoublePress?.call();
  }

  Future<void> dispose() async {
    _volumePressTimer?.cancel();
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel?.invokeMethod('stopVolumeButtonListener');
      } catch (e) {
        debugPrint('Error stopping volume button listener: $e');
      }
    }
    _isInitialized = false;
  }
}

