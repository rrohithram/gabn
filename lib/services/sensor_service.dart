import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter/foundation.dart';

/// Sensor service for accelerometer, gyroscope, and compass data
/// Used for fall detection, orientation checking, and automatic SOS
class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  bool _isInitialized = false;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<MagnetometerEvent>? _magnetometerSubscription;

  // Latest sensor values
  AccelerometerEvent? _lastAccelerometer;
  MagnetometerEvent? _lastMagnetometer;

  // Fall detection state machine
  static const double _impactThreshold = 30.0; // High impact threshold
  static const double _shakeThreshold = 25.0; // Vigorous shake threshold
  static const double _freeFallThreshold = 2.5; // Near zero gravity
  DateTime? _lastFallAlert;
  static const Duration _fallCooldown = Duration(seconds: 10);
  
  // Shake detection for emergency
  int _shakeCount = 0;
  DateTime? _lastShakeTime;
  static const int _shakesToTriggerSOS = 5; // 5 shakes in 3 seconds
  static const Duration _shakeWindow = Duration(seconds: 3);
  
  // Free fall detection
  bool _inFreeFall = false;
  DateTime? _freeFallStart;
  
  // Orientation state with debouncing
  bool _lastOrientationCorrect = true;
  DateTime? _lastOrientationWarning;
  static const Duration _orientationWarningCooldown = Duration(seconds: 5);

  // Callbacks
  void Function()? onFallDetected;
  void Function()? onVigorousShakeDetected; // Triggers SOS
  void Function(bool isCorrect)? onOrientationChanged;
  void Function(String warning)? onOrientationWarning;

  /// Initialize sensor streams
  Future<void> initialize() async {
    if (_isInitialized) return;

    _accelerometerSubscription = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 50), // 20Hz for better fall detection
    ).listen(_handleAccelerometer);

    _magnetometerSubscription = magnetometerEventStream(
      samplingPeriod: const Duration(milliseconds: 200),
    ).listen(_handleMagnetometer);

    _isInitialized = true;
    debugPrint('Sensor service initialized');
  }

  void _handleAccelerometer(AccelerometerEvent event) {
    _lastAccelerometer = event;
    _checkForFall(event);
    _checkForShake(event);
    _checkPhoneOrientation(event);
  }

  void _handleMagnetometer(MagnetometerEvent event) {
    _lastMagnetometer = event;
  }

  /// Enhanced fall detection with free-fall + impact pattern
  void _checkForFall(AccelerometerEvent event) {
    double magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    // Detect free fall phase (near zero gravity)
    if (magnitude < _freeFallThreshold) {
      if (!_inFreeFall) {
        _inFreeFall = true;
        _freeFallStart = DateTime.now();
        debugPrint('Free fall detected');
      }
    } else if (_inFreeFall) {
      // Check for impact after free fall
      Duration fallDuration = DateTime.now().difference(_freeFallStart!);
      
      if (magnitude > _impactThreshold && fallDuration.inMilliseconds > 100) {
        // Free fall followed by impact = likely fall
        _triggerFallAlert();
      }
      _inFreeFall = false;
      _freeFallStart = null;
    }

    // Also detect sudden high impact without free fall
    if (magnitude > _impactThreshold * 1.5) {
      _triggerFallAlert();
    }
  }

  /// Detect vigorous shaking for emergency SOS
  void _checkForShake(AccelerometerEvent event) {
    double magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    if (magnitude > _shakeThreshold) {
      DateTime now = DateTime.now();
      
      // Reset count if outside window
      if (_lastShakeTime != null && 
          now.difference(_lastShakeTime!) > _shakeWindow) {
        _shakeCount = 0;
      }
      
      _lastShakeTime = now;
      _shakeCount++;
      
      debugPrint('Shake detected: $_shakeCount/$_shakesToTriggerSOS');
      
      if (_shakeCount >= _shakesToTriggerSOS) {
        _shakeCount = 0;
        onVigorousShakeDetected?.call();
        debugPrint('Vigorous shake SOS triggered!');
      }
    }
  }

  void _triggerFallAlert() {
    if (_lastFallAlert != null &&
        DateTime.now().difference(_lastFallAlert!) < _fallCooldown) {
      return;
    }
    
    _lastFallAlert = DateTime.now();
    onFallDetected?.call();
    debugPrint('Fall alert triggered!');
  }

  /// Check phone orientation with debounced warnings
  void _checkPhoneOrientation(AccelerometerEvent event) {
    // Phone should be roughly vertical with screen facing forward
    // Y-axis: high positive when held upright
    // Z-axis: near zero when screen perpendicular to ground
    // X-axis: near zero when not tilted sideways
    
    bool isVertical = event.y > 5.0 && event.y < 12.0;
    bool isScreenForward = event.z.abs() < 6.0;
    bool isNotTilted = event.x.abs() < 4.0;
    bool isCorrect = isVertical && isScreenForward && isNotTilted;

    // Notify on state change
    if (isCorrect != _lastOrientationCorrect) {
      _lastOrientationCorrect = isCorrect;
      onOrientationChanged?.call(isCorrect);
      
      // Generate specific warning if not correct (with cooldown)
      if (!isCorrect) {
        DateTime now = DateTime.now();
        if (_lastOrientationWarning == null ||
            now.difference(_lastOrientationWarning!) > _orientationWarningCooldown) {
          _lastOrientationWarning = now;
          String warning = _getOrientationWarning(event);
          onOrientationWarning?.call(warning);
        }
      }
    }
  }

  /// Get specific orientation warning message
  String _getOrientationWarning(AccelerometerEvent event) {
    if (event.y < 3.0) {
      if (event.z > 6.0) {
        return "Phone is face up. Please hold it upright in front of you.";
      } else if (event.z < -6.0) {
        return "Phone is face down. Please hold it upright with the screen facing you.";
      } else {
        return "Please hold the phone more upright.";
      }
    }
    
    if (event.x > 4.0) {
      return "Phone is tilted right. Please straighten it.";
    } else if (event.x < -4.0) {
      return "Phone is tilted left. Please straighten it.";
    }
    
    if (event.z > 6.0) {
      return "Phone is pointing too far up. Lower it slightly.";
    } else if (event.z < -6.0) {
      return "Phone is pointing too far down. Raise it slightly.";
    }
    
    return "Please hold the phone upright, facing forward.";
  }

  /// Get current compass heading in degrees (0-360)
  double? getCompassHeading() {
    if (_lastMagnetometer == null || _lastAccelerometer == null) return null;

    double heading = atan2(
      _lastMagnetometer!.y,
      _lastMagnetometer!.x,
    ) * (180 / pi);

    if (heading < 0) heading += 360;
    return heading;
  }

  /// Get direction name from heading
  String getDirectionName(double heading) {
    if (heading >= 337.5 || heading < 22.5) return 'North';
    if (heading >= 22.5 && heading < 67.5) return 'Northeast';
    if (heading >= 67.5 && heading < 112.5) return 'East';
    if (heading >= 112.5 && heading < 157.5) return 'Southeast';
    if (heading >= 157.5 && heading < 202.5) return 'South';
    if (heading >= 202.5 && heading < 247.5) return 'Southwest';
    if (heading >= 247.5 && heading < 292.5) return 'West';
    return 'Northwest';
  }

  /// Get clock direction (e.g., "12 o'clock" for straight ahead)
  String getClockDirection(double heading, double targetBearing) {
    double diff = targetBearing - heading;
    if (diff < 0) diff += 360;
    if (diff >= 360) diff -= 360;
    
    int hour = (((diff / 30) + 12) % 12).toInt();
    if (hour == 0) hour = 12;
    return "$hour o'clock";
  }

  /// Check if phone is currently held correctly
  bool isPhoneOrientationCorrect() {
    return _lastOrientationCorrect;
  }

  AccelerometerEvent? get currentAccelerometer => _lastAccelerometer;
  MagnetometerEvent? get currentMagnetometer => _lastMagnetometer;

  Future<void> dispose() async {
    await _accelerometerSubscription?.cancel();
    await _magnetometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _magnetometerSubscription = null;
    _isInitialized = false;
  }
}
