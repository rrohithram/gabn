import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Navigation service using Google Maps Directions API
/// Converts route steps into voice-friendly instructions
class NavigationService {
  static final NavigationService _instance = NavigationService._internal();
  factory NavigationService() => _instance;
  NavigationService._internal();

  String? _apiKey;
  List<NavigationStep> _steps = [];
  int _currentStepIndex = 0;
  bool _isNavigating = false;
  List<LatLng> _polylinePoints = [];
  LatLng? _destinationLatLng;

  // Mock mode for testing without API
  bool useMock = false;

  /// Initialize with API key
  void initialize(String apiKey) {
    _apiKey = apiKey;
  }

  /// Get directions from origin to destination
  Future<NavigationResult> getDirections({
    required double originLat,
    required double originLng,
    required String destination,
    String mode = 'walking', // walking, driving, bicycling, transit
  }) async {
    if (useMock) {
      return _getMockDirections(originLat: originLat, originLng: originLng);
    }

    if (_apiKey == null || _apiKey!.isEmpty) {
      return NavigationResult(
        success: false,
        error: 'Google Maps API key not configured',
      );
    }

    try {
      final origin = '$originLat,$originLng';
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$origin'
        '&destination=${Uri.encodeComponent(destination)}'
        '&mode=$mode'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        return NavigationResult(
          success: false,
          error: 'API request failed: ${response.statusCode}',
        );
      }

      final data = jsonDecode(response.body);

      if (data['status'] != 'OK') {
        return NavigationResult(
          success: false,
          error: 'Directions not found: ${data['status']}',
        );
      }

      // Parse route steps
      _steps = [];
      final legs = data['routes'][0]['legs'] as List;
      for (var leg in legs) {
        final steps = leg['steps'] as List;
        for (var step in steps) {
          _steps.add(NavigationStep(
            instruction: _cleanHtmlTags(step['html_instructions']),
            distance: step['distance']['text'],
            distanceMeters: step['distance']['value'],
            duration: step['duration']['text'],
            maneuver: step['maneuver'] ?? '',
            startLat: step['start_location']['lat'],
            startLng: step['start_location']['lng'],
            endLat: step['end_location']['lat'],
            endLng: step['end_location']['lng'],
          ));
        }
      }

      _currentStepIndex = 0;
      _isNavigating = true;

      // Extract polyline
      if (data['routes'].isNotEmpty) {
        final overviewPolyline = data['routes'][0]['overview_polyline']['points'];
        _polylinePoints = _decodePolyline(overviewPolyline);
        
        final endLocation = data['routes'][0]['legs'][0]['end_location'];
        _destinationLatLng = LatLng(endLocation['lat'], endLocation['lng']);
      }

      return NavigationResult(
        success: true,
        steps: _steps,
        polylinePoints: _polylinePoints,
        destinationLatLng: _destinationLatLng,
        totalDistance: data['routes'][0]['legs'][0]['distance']['text'],
        totalDuration: data['routes'][0]['legs'][0]['duration']['text'],
      );
    } catch (e) {
      return NavigationResult(
        success: false,
        error: 'Error getting directions: $e',
      );
    }
  }

  /// Get mock directions for testing
  NavigationResult _getMockDirections({
    required double originLat,
    required double originLng,
  }) {
    _steps = [
      NavigationStep(
        instruction: 'Head north on Main Street',
        distance: '50 m',
        distanceMeters: 50,
        duration: '1 min',
        maneuver: 'straight',
        startLat: 0,
        startLng: 0,
        endLat: 0,
        endLng: 0,
      ),
      NavigationStep(
        instruction: 'Turn right onto Oak Avenue',
        distance: '100 m',
        distanceMeters: 100,
        duration: '2 min',
        maneuver: 'turn-right',
        startLat: 0,
        startLng: 0,
        endLat: 0,
        endLng: 0,
      ),
      NavigationStep(
        instruction: 'Continue straight for 200 meters',
        distance: '200 m',
        distanceMeters: 200,
        duration: '3 min',
        maneuver: 'straight',
        startLat: 0,
        startLng: 0,
        endLat: 0,
        endLng: 0,
      ),
      NavigationStep(
        instruction: 'Turn left onto Elm Street',
        distance: '75 m',
        distanceMeters: 75,
        duration: '1 min',
        maneuver: 'turn-left',
        startLat: 0,
        startLng: 0,
        endLat: 0,
        endLng: 0,
      ),
      NavigationStep(
        instruction: 'Your destination is on the right',
        distance: '10 m',
        distanceMeters: 10,
        duration: '1 min',
        maneuver: 'arrive',
        startLat: 0,
        startLng: 0,
        endLat: 0,
        endLng: 0,
      ),
    ];

    _currentStepIndex = 0;
    _isNavigating = true;

    // Sample polyline points for mock mode
    _polylinePoints = [
      LatLng(originLat, originLng),
      LatLng(originLat + 0.001, originLng + 0.001),
      LatLng(originLat + 0.002, originLng + 0.002),
    ];
    _destinationLatLng = _polylinePoints.last;

    return NavigationResult(
      success: true,
      steps: _steps,
      polylinePoints: _polylinePoints,
      destinationLatLng: _destinationLatLng,
      totalDistance: '435 m',
      totalDuration: '8 min',
    );
  }

  /// Get current navigation step
  NavigationStep? getCurrentStep() {
    if (_steps.isEmpty || _currentStepIndex >= _steps.length) return null;
    return _steps[_currentStepIndex];
  }

  /// Get voice-friendly instruction for current step
  String getCurrentVoiceInstruction() {
    final step = getCurrentStep();
    if (step == null) return 'Navigation complete';

    String instruction = step.instruction;
    
    // Add distance context
    if (step.distanceMeters > 0) {
      if (step.distanceMeters < 50) {
        instruction = 'In ${step.distanceMeters} meters, $instruction';
      } else {
        instruction = 'In about ${step.distance}, $instruction';
      }
    }

    return instruction;
  }

  /// Move to next step
  bool nextStep() {
    if (_currentStepIndex < _steps.length - 1) {
      _currentStepIndex++;
      return true;
    }
    _isNavigating = false;
    return false;
  }

  /// Check if current step involves a turn
  bool isCurrentStepATurn() {
    final step = getCurrentStep();
    if (step == null) return false;
    return step.maneuver.contains('turn') || 
           step.maneuver.contains('left') || 
           step.maneuver.contains('right');
  }

  /// Get turn direction for haptic feedback
  bool? isLeftTurn() {
    final step = getCurrentStep();
    if (step == null) return null;
    if (step.maneuver.contains('left')) return true;
    if (step.maneuver.contains('right')) return false;
    return null;
  }

  /// Stop navigation
  void stopNavigation() {
    _steps = [];
    _currentStepIndex = 0;
    _isNavigating = false;
  }

  /// Launch native Google Maps for external navigation
  Future<bool> launchGoogleMaps(String destination) async {
    final Uri url = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${Uri.encodeComponent(destination)}&travelmode=walking');
    
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Clean HTML tags from instructions
  String _cleanHtmlTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&');
  }

  // Getters
  bool get isNavigating => _isNavigating;
  int get currentStepIndex => _currentStepIndex;
  int get totalSteps => _steps.length;
  List<NavigationStep> get steps => _steps;
  List<LatLng> get polylinePoints => _polylinePoints;
  LatLng? get destinationLatLng => _destinationLatLng;

  /// Decode encoded polyline string from Google Maps API
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }
}

/// Represents a single navigation step
class NavigationStep {
  final String instruction;
  final String distance;
  final int distanceMeters;
  final String duration;
  final String maneuver;
  final double startLat;
  final double startLng;
  final double endLat;
  final double endLng;

  NavigationStep({
    required this.instruction,
    required this.distance,
    required this.distanceMeters,
    required this.duration,
    required this.maneuver,
    required this.startLat,
    required this.startLng,
    required this.endLat,
    required this.endLng,
  });
}

/// Result of a directions request
class NavigationResult {
  final bool success;
  final String? error;
  final List<NavigationStep>? steps;
  final List<LatLng>? polylinePoints;
  final LatLng? destinationLatLng;
  final String? totalDistance;
  final String? totalDuration;

  NavigationResult({
    required this.success,
    this.error,
    this.steps,
    this.polylinePoints,
    this.destinationLatLng,
    this.totalDistance,
    this.totalDuration,
  });
}
