import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

/// Saved location model
class SavedLocation {
  final String name;
  final double latitude;
  final double longitude;
  final String? address;

  SavedLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
  };

  factory SavedLocation.fromJson(Map<String, dynamic> json) => SavedLocation(
    name: json['name'],
    latitude: json['latitude'],
    longitude: json['longitude'],
    address: json['address'],
  );
}

/// Service for managing saved locations
class SavedLocationsService extends ChangeNotifier {
  static final SavedLocationsService _instance = SavedLocationsService._internal();
  factory SavedLocationsService() => _instance;
  SavedLocationsService._internal();

  SharedPreferences? _prefs;
  List<SavedLocation> _locations = [];
  static const String _keyLocations = 'saved_locations';

  List<SavedLocation> get locations => List.unmodifiable(_locations);

  /// Initialize service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await loadLocations();
  }

  /// Load saved locations
  Future<void> loadLocations() async {
    if (_prefs == null) await initialize();

    final jsonString = _prefs?.getString(_keyLocations);
    if (jsonString != null) {
      try {
        final List<dynamic> jsonList = json.decode(jsonString);
        _locations = jsonList.map((json) => SavedLocation.fromJson(json)).toList();
        notifyListeners();
      } catch (e) {
        debugPrint('Error loading locations: $e');
        _locations = [];
      }
    }
  }

  /// Save a location
  Future<bool> saveLocation(SavedLocation location) async {
    if (_prefs == null) await initialize();

    // Check if name already exists
    if (_locations.any((l) => l.name.toLowerCase() == location.name.toLowerCase())) {
      return false; // Name already exists
    }

    _locations.add(location);
    return await _saveToStorage();
  }

  /// Delete a location
  Future<bool> deleteLocation(String name) async {
    _locations.removeWhere((l) => l.name.toLowerCase() == name.toLowerCase());
    return await _saveToStorage();
  }

  /// Get location by name (case-insensitive)
  SavedLocation? getLocationByName(String name) {
    try {
      return _locations.firstWhere(
        (l) => l.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Save to storage
  Future<bool> _saveToStorage() async {
    if (_prefs == null) await initialize();

    try {
      final jsonList = _locations.map((l) => l.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await _prefs?.setString(_keyLocations, jsonString);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving locations: $e');
      return false;
    }
  }
}

