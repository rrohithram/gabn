import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'location_service.dart';
import 'gemini_service.dart';
import 'tts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart' as native_picker;

/// SOS service for emergency situations
/// Handles emergency calls, SMS, and context generation
class SosService extends ChangeNotifier {
  static final SosService _instance = SosService._internal();
  factory SosService() => _instance;
  SosService._internal();

  /// Pick a contact from the phone storage
  Future<EmergencyContact?> pickContact() async {
    debugPrint("Picking contact...");
    try {
      // Use permission_handler for more explicit control
      var status = await Permission.contacts.request();
      debugPrint("Contact Permission Status: $status");
      
      if (status.isPermanentlyDenied) {
         openAppSettings();
         return null;
      }

      if (status.isGranted) {
        // Try FlutterContacts openExternalPick
        final contact = await FlutterContacts.openExternalPick();
        debugPrint("Picked Contact: ${contact?.displayName}");
        
        if (contact != null) {
          // Find a mobile number
          String? phone;
          if (contact.phones.isNotEmpty) {
            // Prefer mobile, then home, then first available
            phone = contact.phones.firstWhere(
              (p) => p.label == PhoneLabel.mobile,
              orElse: () => contact.phones.first
            ).number;
          }
          
          if (phone != null) {
            final ec = EmergencyContact(
              name: contact.displayName,
              phoneNumber: phone,
            );
            addContact(ec);
            return ec;
          } else {
             debugPrint("No phone number found for contact");
          }
        }
      }
    } catch (e) {
      debugPrint("Error picking contact: $e");
    }
    return null;
  }

  final LocationService _location = LocationService();
  final GeminiService _gemini = GeminiService();
  final TtsService _tts = TtsService();

  // Emergency contacts
  List<EmergencyContact> _emergencyContacts = [];
  
  // Default emergency number (can be customized per region)
  String _emergencyNumber = '112'; // EU emergency number, 911 for US

  bool _isSosActive = false;
  int _currentCountdown = 10;
  Timer? _sosTimer;
  Timer? _speakTimer;

  bool get isSosActive => _isSosActive;
  int get currentCountdown => _currentCountdown;

  /// Initialize SOS service with emergency contacts
  void initialize({
    List<EmergencyContact>? contacts,
    String? emergencyNumber,
  }) {
    if (contacts != null) {
      _emergencyContacts = contacts;
    }
    if (emergencyNumber != null) {
      _emergencyNumber = emergencyNumber;
    }
  }

  /// Start SOS Sequence (10 second countdown)
  Future<void> startSosSequence({
    String? context,
  }) async {
    if (_isSosActive) return; // Prevent stacking
    _isSosActive = true;

    _tts.speak("Emergency Sequence Activated. Calling in 10 seconds. To cancel, shake phone or say cancel.");
    
    // 10 second countdown with updates
    _currentCountdown = 10;
    notifyListeners();
    
    _sosTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _currentCountdown--;
      notifyListeners();
      
      if (_currentCountdown > 0) {
        if (_currentCountdown == 5) _tts.speak("5 seconds");
        if (_currentCountdown <= 3) _tts.speak("$_currentCountdown"); // Announce 3, 2, 1
      } else {
        timer.cancel();
        // Trigger actual SOS
        _triggerAutomatedSOS(context: context);
      }
    });
  }

  /// Cancel SOS Sequence
  void cancelSos() {
    if (!_isSosActive) return;
    _isSosActive = false;
    _currentCountdown = 10;
    _sosTimer?.cancel();
    _speakTimer?.cancel();
    _tts.speak("Emergency Sequence Cancelled.");
    notifyListeners();
  }

  Future<void> _triggerAutomatedSOS({String? context}) async {
     await fullSOS(additionalContext: context);
  }

  /// Add an emergency contact
  void addContact(EmergencyContact contact) {
    _emergencyContacts.add(contact);
    notifyListeners();
  }

  /// Remove an emergency contact
  void removeContact(String phoneNumber) {
    _emergencyContacts.removeWhere((c) => c.phoneNumber == phoneNumber);
    notifyListeners();
  }

  /// Get all emergency contacts
  List<EmergencyContact> get contacts => List.unmodifiable(_emergencyContacts);

  /// Trigger SOS - generates message and optionally calls/texts
  Future<SosResult> triggerSOS({
    String? additionalContext,
    bool? fallDetected,
    List<String>? detectedObstacles,
    bool shouldCall = false,
    bool shouldText = true,
  }) async {
    try {
      // Get current location
      final locationData = await _location.getLocationForSOS();

      // Generate emergency summary with Gemini
      String emergencySummary = await _gemini.generateEmergencySummary(
        location: locationData,
        lastInstruction: additionalContext,
        fallDetected: fallDetected,
        detectedObstacles: detectedObstacles,
      );

      // Build SMS message
      String smsMessage = _buildSmsMessage(emergencySummary, locationData);

      // Send SMS to all emergency contacts
      List<String> smsResults = [];
      if (shouldText && _emergencyContacts.isNotEmpty) {
        for (var contact in _emergencyContacts) {
          bool sent = await sendSMS(contact.phoneNumber, smsMessage);
          smsResults.add('${contact.name}: ${sent ? "Sent" : "Failed"}');
        }
      }

      // Make emergency call if requested
      bool callMade = false;
      if (shouldCall) {
        if (_emergencyContacts.isNotEmpty) {
           // Call first contact
           callMade = await makeEmergencyCall(phoneNumber: _emergencyContacts.first.phoneNumber);
        } else {
           // Call default emergency number
           callMade = await makeEmergencyCall();
        }

        if (callMade) {
           _startSpeakingLoop(emergencySummary);
        }
      }

      return SosResult(
        success: true,
        emergencySummary: emergencySummary,
        locationData: locationData,
        smsMessage: smsMessage,
        smsResults: smsResults,
        callMade: callMade,
      );
    } catch (e) {
      debugPrint('SOS error: $e');
      return SosResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Build SMS message with location
  String _buildSmsMessage(String summary, Map<String, dynamic> locationData) {
    StringBuffer message = StringBuffer();
    message.writeln('🆘 EMERGENCY ALERT');
    message.writeln();
    message.writeln(summary);
    message.writeln();
    
    if (locationData['googleMapsUrl'] != null) {
      message.writeln('📍 Location: ${locationData['googleMapsUrl']}');
    } else if (locationData['latitude'] != null) {
      message.writeln('📍 Coordinates: ${locationData['latitude']}, ${locationData['longitude']}');
    }
    
    message.writeln();
    message.writeln('This is an automated emergency message from the Accessibility Navigator app.');
    
    return message.toString();
  }

  /// Send SMS to a phone number
  Future<bool> sendSMS(String phoneNumber, String message) async {
    try {
      final Uri smsUri = Uri(
        scheme: 'sms',
        path: phoneNumber,
        queryParameters: {'body': message},
      );

      if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
        return true;
      } else {
        debugPrint('Cannot launch SMS for $phoneNumber');
        return false;
      }
    } catch (e) {
      debugPrint('SMS error: $e');
      return false;
    }
  }

  /// Make emergency call
  Future<bool> makeEmergencyCall({String? phoneNumber}) async {
    try {
      final number = phoneNumber ?? _emergencyNumber;
      final Uri callUri = Uri(
        scheme: 'tel',
        path: number,
      );

      // Request permission first
      var status = await Permission.phone.request();
      if (status.isGranted) {
         // Try direct call first (Android direct, iOS dialer)
         bool? res = await FlutterPhoneDirectCaller.callNumber(number);
         if (res == true) return true;
      }

      // Fallback to URL launcher
      if (await canLaunchUrl(callUri)) {
        await launchUrl(callUri, mode: LaunchMode.externalApplication);
        return true;
      } else {
        // Try absolute fallback
         try {
           await launchUrl(callUri, mode: LaunchMode.externalApplication);
           return true;
         } catch (e) {
           debugPrint('Fallback launch error: $e');
         }
        return false;
      }
    } catch (e) {
      debugPrint('Call error: $e');
      return false;
    }
  }

  /// Call first emergency contact
  Future<bool> callFirstContact() async {
    if (_emergencyContacts.isEmpty) {
      return makeEmergencyCall();
    }
    return makeEmergencyCall(phoneNumber: _emergencyContacts.first.phoneNumber);
  }

  /// Start speaking loop for call (tries to speak into microphone/speaker)
  void _startSpeakingLoop(String summary) {
    _speakTimer?.cancel();
    // Wait 10 seconds for call to likely connect and pickup
    Future.delayed(const Duration(seconds: 10), () {
        if (!_isSosActive) return; 
        
        debugPrint("Starting Emergency Voice Loop");
        const String msg = "Hello. This is an automated emergency call. "
                         "The user has fallen and cannot respond. "
                         "Please send help. Location details sent via SMS.";

        // Speak initially
        _tts.speak(msg);

        // Loop every 12 seconds
        _speakTimer = Timer.periodic(const Duration(seconds: 12), (_) {
             if (!_isSosActive) {
               _speakTimer?.cancel();
               return;
             }
             debugPrint("Speaking emergency message again");
             _tts.speak(msg);
        });
    });
  }

  /// Quick SOS - just sends SMS to all contacts
  Future<bool> quickSOS({String? additionalContext}) async {
    final result = await triggerSOS(
      additionalContext: additionalContext,
      shouldCall: false,
      shouldText: true,
    );
    return result.success;
  }

  /// Full SOS - sends SMS and makes call
  Future<bool> fullSOS({String? additionalContext}) async {
    final result = await triggerSOS(
      additionalContext: additionalContext,
      shouldCall: true,
      shouldText: true,
    );
    return result.success;
  }
}

/// Emergency contact model
class EmergencyContact {
  final String name;
  final String phoneNumber;
  final String? relationship;

  EmergencyContact({
    required this.name,
    required this.phoneNumber,
    this.relationship,
  });
}

/// Result of SOS trigger
class SosResult {
  final bool success;
  final String? error;
  final String? emergencySummary;
  final Map<String, dynamic>? locationData;
  final String? smsMessage;
  final List<String>? smsResults;
  final bool? callMade;

  SosResult({
    required this.success,
    this.error,
    this.emergencySummary,
    this.locationData,
    this.smsMessage,
    this.smsResults,
    this.callMade,
  });
}
