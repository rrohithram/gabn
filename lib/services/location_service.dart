import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Location service for GPS tracking and SOS functionality
class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  bool _isInitialized = false;
  StreamSubscription<Position>? _positionSubscription;
  Position? _lastKnownPosition;

  // Callbacks
  void Function(Position)? onPositionUpdate;

  /// Initialize location service and request permissions
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled.');
      return false;
    }

    // Check and request permission
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permissions are denied.');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      print('Location permissions are permanently denied.');
      return false;
    }

    _isInitialized = true;
    return true;
  }

  /// Get current location once (for SOS or initial position)
  Future<Position?> getCurrentLocation() async {
    if (!_isInitialized) {
      bool success = await initialize();
      if (!success) return null;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _lastKnownPosition = position;
      return position;
    } catch (e) {
      print('Error getting location: $e');
      return _lastKnownPosition;
    }
  }

  /// Start continuous location tracking for navigation
  Future<void> startTracking({
    int distanceFilter = 5, // meters
  }) async {
    if (!_isInitialized) {
      bool success = await initialize();
      if (!success) return;
    }

    // Stop any existing subscription
    await stopTracking();

    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: distanceFilter,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      _lastKnownPosition = position;
      onPositionUpdate?.call(position);
    });
  }

  /// Stop location tracking
  Future<void> stopTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Get location for SOS - quick grab with fallback
  Future<Map<String, dynamic>> getLocationForSOS() async {
    Position? position = await getCurrentLocation();
    
    if (position != null) {
      return {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'timestamp': position.timestamp.toIso8601String(),
        'googleMapsUrl': 'https://www.google.com/maps?q=${position.latitude},${position.longitude}',
      };
    }

    // Fallback if location unavailable
    return {
      'error': 'Location unavailable',
      'lastKnown': _lastKnownPosition != null
          ? {
              'latitude': _lastKnownPosition!.latitude,
              'longitude': _lastKnownPosition!.longitude,
            }
          : null,
    };
  }

  /// Calculate distance between two points in meters
  double distanceBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Get bearing between two points
  double bearingBetween(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.bearingBetween(startLat, startLng, endLat, endLng);
  }

  /// Get last known position
  Position? get lastKnownPosition => _lastKnownPosition;

  /// Check if currently tracking
  bool get isTracking => _positionSubscription != null;

  /// Dispose of resources
  Future<void> dispose() async {
    await stopTracking();
    _isInitialized = false;
  }
}
