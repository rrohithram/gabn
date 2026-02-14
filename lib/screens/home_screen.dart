import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/tts_service.dart';
import '../services/haptic_service.dart';
import '../services/location_service.dart';
import '../services/sensor_service.dart';
import '../services/navigation_service.dart';
import '../services/gemini_service.dart';
import '../services/vision_service.dart';
import '../services/voice_command_service.dart';
import '../services/sos_service.dart';
import '../services/settings_service.dart';
import 'package:gaze/l10n/app_localizations.dart';
import '../services/ocr_service.dart';
import '../services/gesture_service.dart';
import '../services/battery_service.dart';
import '../services/saved_locations_service.dart';
import 'settings_screen.dart';
import 'tutorial_screen.dart';
import 'voice_command_dialog.dart';
import 'map_screen.dart'; // Add MapScreen import
import 'sos_overlay.dart';
import 'dart:io';
import 'dart:async';

/// Main home screen with accessibility-first design
/// Live camera with obstacle detection, navigation, and SOS features
class HomeScreen extends StatefulWidget {
  final String? mapsApiKey;
  final String? geminiApiKey;

  const HomeScreen({
    super.key,
    this.mapsApiKey,
    this.geminiApiKey,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Services
  final TtsService _tts = TtsService();
  final HapticService _haptic = HapticService();
  final LocationService _location = LocationService();
  final SensorService _sensor = SensorService();
  final NavigationService _navigation = NavigationService();
  final GeminiService _gemini = GeminiService();
  final VisionService _vision = VisionService();
  final VoiceCommandService _voice = VoiceCommandService();
  final SosService _sos = SosService();
  final SettingsService _settings = SettingsService();
  final OcrService _ocr = OcrService();
  final GestureService _gesture = GestureService();
  final BatteryService _battery = BatteryService();
  final SavedLocationsService _savedLocations = SavedLocationsService();

  // State
  bool _isInitialized = false;
  bool _isNavigating = false;
  bool _isMockMode = false;
  String _statusText = ''; // Will be initialized in didChangeDependencies
  String _currentInstruction = '';
  String _sceneDescription = '';
  bool _orientationWarningShown = false;
  final TextEditingController _destinationController = TextEditingController();
  Timer? _autoCloseTimer;

  // Camera
  CameraController? _cameraController;
  
  // Photo capture
  bool _isCapturingPhoto = false;
  String? _lastCapturedPhotoPath;
  
  // Triple tap detection for voice commands
  DateTime? _lastTapTime;
  int _tapCount = 0;
  static const Duration _tripleTapWindow = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _destinationController.dispose();
    _disposeServices();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _vision.stopDetection();
    } else if (state == AppLifecycleState.resumed) {
      // Resume detection when app returns to foreground
      _vision.startDetection();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_statusText.isEmpty) {
      _statusText = AppLocalizations.of(context)!.initializing;
    }
  }

  /// Initialize all services
  Future<void> _initializeApp() async {
    try {
      await _requestPermissions();

      // Initialize core services
      await _tts.initialize();
      await _haptic.initialize();
      await _location.initialize();
      await _sensor.initialize();

      // Initialize API services
      if (widget.mapsApiKey != null && widget.mapsApiKey!.isNotEmpty) {
        _navigation.initialize(widget.mapsApiKey!);
      }
      if (widget.geminiApiKey != null && widget.geminiApiKey!.isNotEmpty) {
        _gemini.initialize(widget.geminiApiKey!);
      }

      // Setup sensor callbacks for fall detection and SOS
      _sensor.onFallDetected = _handleFallDetected;
      _sensor.onVigorousShakeDetected = _handleShakeSOS;
      _sensor.onOrientationWarning = _handleOrientationWarning;

      // Initialize vision service with callbacks
      _vision.onCameraReady = (controller) {
        if (mounted) {
          setState(() {
            _cameraController = controller;
          });
          _ocr.setCameraController(controller);
          // Start detection when camera is ready
          _vision.startDetection();
        }
      };
      _vision.onObstacleDetected = _handleObstacleDetected;
      
      // Try to initialize camera (don't block if it fails)
      final visionInitialized = await _vision.initialize();
      if (!visionInitialized) {
        if (mounted) {
          setState(() => _statusText = AppLocalizations.of(context)!.cameraInitFailed);
        }
        await _tts.speak(AppLocalizations.of(context)!.cameraInitFailed);
      } else {
        // Start detection if already initialized
        if (_vision.isInitialized && _vision.cameraController != null) {
          await _vision.startDetection();
        }
      }

      // Initialize voice commands
      await _voice.initialize();
      _setupVoiceCommands();

      // Initialize settings
      await _settings.initialize();
      
      // Keep camera enabled at start; user can toggle off and that state is saved for next launch.
      // Do not disable camera here so obstacle detection works immediately.

      // Initialize OCR
      await _ocr.initialize();

      // Initialize gesture service
      await _gesture.initialize();
      _gesture.onVolumeDoublePress = _handleVolumeDoublePress;
      _gesture.onVolumeTriplePress = _handleVolumeTriplePress;

      // Initialize saved locations
      await _savedLocations.initialize();

      // Initialize SOS service
      _sos.initialize(
        contacts: [
          EmergencyContact(name: 'Emergency', phoneNumber: '112'),
        ],
      );

      setState(() {
        _isInitialized = true;
        _statusText = AppLocalizations.of(context)!.readyCameraActive;
      });

      await _tts.speak(AppLocalizations.of(context)!.appReadySpeak);
      await _haptic.vibrate();

      // Start obstacle detection immediately (camera already started in onCameraReady / above)
      await _vision.startDetection();

    } catch (e) {
      setState(() => _statusText = 'Error: $e');
      _tts.speak(AppLocalizations.of(context)!.errorStartingApp);
    }
  }

  void _setupVoiceCommands() {
    // Core navigation
    _voice.onStartNavigation = _startNavigation;
    _voice.onStopNavigation = _stopNavigation;
    _voice.onNextStep = _nextStep;
    _voice.onSOS = _triggerSOS;
    _voice.onHelp = () => _tts.speak(_voice.getAvailableCommands());
    _voice.onRepeat = () {
      if (_currentInstruction.isNotEmpty) {
        _tts.speak(_currentInstruction);
      } else {
        _tts.speak(_vision.getCurrentSceneDescription());
      }
    };
    
    // Time and battery
    _voice.onTime = () {
      _haptic.buttonPress();
      final now = DateTime.now();
      String suffix = now.hour >= 12 ? "PM" : "AM";
      int hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      String minute = now.minute.toString().padLeft(2, '0');
      _tts.speak("It is $hour:$minute $suffix");
    };
    _voice.onBattery = () async {
      _haptic.buttonPress();
      final batteryLevel = await _battery.getBatteryLevelString();
      _tts.speak("Battery level is $batteryLevel.");
    };
    
    // Location
    _voice.onLocation = () async {
      _haptic.buttonPress();
      _tts.speak("Checking location...");
      try {
        final loc = await _location.getCurrentLocation();
        if (loc != null) {
          _tts.speak("You are at latitude ${loc.latitude.toStringAsFixed(2)} and longitude ${loc.longitude.toStringAsFixed(2)}.");
        } else {
          _tts.speak("Unable to get current location.");
        }
      } catch (e) {
        _tts.speak("Location error.");
      }
    };
    
    // Scene description
    _voice.onDescribeScene = () {
      _haptic.buttonPress();
      _describeScene();
    };
    
    // Obstacle reading
    _voice.onReadObstacles = () {
      _haptic.buttonPress();
      String desc = _vision.getCurrentSceneDescription();
      _tts.speak(desc);
    };

    // Text reading and other commands
    _voice.onUnrecognizedCommand = (command) {
      if (command.contains('read text') || (command.contains('read') && command.contains('text'))) {
        _readTextFromCamera();
      } else if (command.contains('capture') || command.contains('photo') || command.contains('picture')) {
        _capturePhotoAndDescribe();
      } else if (command.contains('settings')) {
        _openSettings();
      } else if (command.contains('tutorial') || command.contains('help me') || command.contains('how to')) {
        _openTutorial();
      } else if (command.contains('navigate to') || command.contains('go to')) {
        _handleNavigateToCommand(command);
      } else if (command.contains('save location') || command.contains('save this location') || command.contains('save my location')) {
        _saveCurrentLocation();
      } else if (command.contains('battery') || command.contains('battery level')) {
        _voice.onBattery?.call();
      }
    };
    
    // Camera toggle
    _voice.onToggleCamera = () async {
      await _toggleCamera();
    };
    _voice.onCameraEnable = () async {
      await _setCameraState(true);
    };
    _voice.onCameraDisable = () async {
      await _setCameraState(false);
    };

    // Flashlight
    _voice.onFlashlightOn = () async {
      await _vision.setFlashlight(true);
      _tts.speak("Flashlight on");
    };
    _voice.onFlashlightOff = () async {
      await _vision.setFlashlight(false);
      _tts.speak("Flashlight off");
    };
    
    // Speed control
    _voice.onSpeedUp = () async {
      _haptic.successFeedback();
      await _tts.setSpeechRate(0.7);
      _tts.speak("Speech speed increased.");
    };
    _voice.onSlowDown = () async {
      _haptic.successFeedback();
      await _tts.setSpeechRate(0.35);
      _tts.speak("Speech speed decreased.");
    };
    
    // Pause/Resume (mute/unmute auto-describe)
    _voice.onPause = () {
      _haptic.buttonPress();
      if (_isAutoDescribing) {
        _isAutoDescribing = false;
        _tts.speak(AppLocalizations.of(context)!.autoDescriptionPaused);
      } else {
        _tts.speak("Already paused.");
      }
    };
    _voice.onResume = () {
      _haptic.buttonPress();
      if (!_isAutoDescribing) {
        _isAutoDescribing = true;
        _tts.speak(AppLocalizations.of(context)!.autoDescriptionResumed);
      } else {
        _tts.speak("Already active.");
      }
    };
    
    // Nearby places (placeholder)
    _voice.onNearbyPlaces = () {
      _haptic.buttonPress();
      _tts.speak("Finding nearby places... Feature coming soon.");
    };
    
    // Status
    _voice.onStatus = () {
      _haptic.buttonPress();
      String cameraStatus = _vision.isCameraEnabled ? "Camera is on" : "Camera is off";
      String navStatus = _isNavigating ? "Navigation is active" : "Navigation is not active";
      String autoStatus = _isAutoDescribing ? "Auto describe is on" : "Auto describe is off";
      _tts.speak("$cameraStatus. $navStatus. $autoStatus.");
    };
  }

  Future<void> _requestPermissions() async {
    final permissions = [
      Permission.camera,
      Permission.location,
      Permission.microphone,
      Permission.phone,
      Permission.sms,
    ];

    for (var permission in permissions) {
      await permission.request();
    }
  }

  /// Handle fall detected - trigger SOS countdown
  void _handleFallDetected() async {
    if (_sos.isSosActive) return;

    await _haptic.fallDetected();
    
    setState(() => _statusText = '⚠️ FALL DETECTED - Shake or Say Cancel');

    // Delegate to SOS service
    await _sos.startSosSequence(context: 'Fall detected');
  }

  /// Handle vigorous shake - immediate SOS
  /// Handle vigorous shake - immediate SOS
  void _handleShakeSOS() async {
    if (_sos.isSosActive) return;

    await _haptic.sosConfirmation();
    // Immediate trigger for vigorous shake? Or sequence?
    // User said "shake or tap SOS" should cancel, but vigorous shake usually TRIGGERS.
    // If vigorous shake, maybe start sequence too? Or fullSOS immediately?
    // Usually safety apps do countdown even for shake.
    await _sos.startSosSequence(context: 'Vigorous shaking');
    
    setState(() => _statusText = '⚠️ SOS TRIGGERED via Shake');
  }

  /// Handle orientation warning
  void _handleOrientationWarning(String warning) async {
    if (!_orientationWarningShown) {
      _orientationWarningShown = true;
      await _tts.speak(warning);
      
      // Reset after cooldown
      Future.delayed(const Duration(seconds: 10), () {
        _orientationWarningShown = false;
      });
    }
  }

  // Auto-describe state (enabled by default as per user request)
  bool _isAutoDescribing = true;
  DateTime? _lastAutoDescriptionTime;
  static const Duration _autoDescribeInterval = Duration(seconds: 5);

  /// Handle obstacle detection with position
  void _handleObstacleDetected(List<DetectionResult> detections, String description) async {
    // Cancel previous auto-close timer
    _autoCloseTimer?.cancel();
    
    // Auto-close description after 5 seconds
    _autoCloseTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _sceneDescription = '';
        });
      }
    });

    setState(() {
      _sceneDescription = description;
      // Truncate status text to prevent overflow
      _statusText = description.length > 50 ? description.substring(0, 50) + '...' : description;
    });

    if (description.contains('Path clear') || description.contains('No obstacles')) {
      // Use translation if possible, or fallback
      // For now, these are generated by vision_service, so they might stay in English unless vision_service is also localized
    }

    if (detections.isEmpty) {
      // Path clear - just update status, don't speak unless auto-describe is on
      if (_isAutoDescribing && !_isNavigating) {
        await _tts.speak(description);
      }
      return;
    }

    // Check for blocking obstacles (always warn)
    bool isBlocked = detections.any((d) => d.position == "center" && d.isClose);

    if (isBlocked) {
      await _haptic.obstacleWarning();
      await _tts.stop(); // Interrupt navigation/other speech for safety
      await _tts.speak("Warning! $description"); 
    } else if (_isAutoDescribing && !_isNavigating) {
      // Auto-describe mode: speak update if enough time passed AND we are not navigating
      // This prevents ambient descriptions from talking over navigation instructions
      if (_lastAutoDescriptionTime == null ||
          DateTime.now().difference(_lastAutoDescriptionTime!) > _autoDescribeInterval) {
        
        _lastAutoDescriptionTime = DateTime.now();
        await _tts.speakQueued(description);
      }
    } else {
      // Normal mode: just haptic for non-blocking
      await _haptic.turnNotification();
    }
  }

  void _toggleAutoDescribe() {
    setState(() {
      _isAutoDescribing = !_isAutoDescribing;
    });
    _tts.speak(_isAutoDescribing ? AppLocalizations.of(context)!.autoDescriptionEnabled : AppLocalizations.of(context)!.autoDescriptionDisabled);
  }

  /// Cancel fall detection SOS
  void _cancelFallSOS() {
    setState(() => _statusText = 'SOS cancelled. Camera active.');
    _tts.speak('SOS cancelled.');
  }

  /// Request scene description on demand
  void _describeScene() {
    String description = _vision.getCurrentSceneDescription();
    _tts.speak(description);
    setState(() => _sceneDescription = description);
  }

  /// Toggle camera on/off
  Future<void> _toggleCamera() async {
    bool newStatus = !_vision.isCameraEnabled;
    await _haptic.cameraModeChange(enabled: newStatus);
    await _vision.toggleCamera();
    
    // Save to settings
    await _settings.setCameraEnabled(newStatus);
    
    setState(() {
      if (_vision.isCameraEnabled) {
        _statusText = AppLocalizations.of(context)!.cameraScanning;
      } else {
        _statusText = AppLocalizations.of(context)!.cameraDisabled;
        _sceneDescription = '';
      }
    });
    
    _tts.speak(_vision.isCameraEnabled ? AppLocalizations.of(context)!.cameraEnabled : AppLocalizations.of(context)!.cameraDisabled);
  }

  /// Explicitly set camera state
  Future<void> _setCameraState(bool enable) async {
    if (_vision.isCameraEnabled == enable) {
      await _tts.speak(enable ? 'Camera is already on' : 'Camera is already off');
      return;
    }
    
    await _haptic.cameraModeChange(enabled: enable);
    if (enable) {
      await _vision.enableCamera();
    } else {
      await _vision.disableCamera();
    }
    
    // Save to settings
    await _settings.setCameraEnabled(enable);
    
    setState(() {
      if (_vision.isCameraEnabled) {
        _statusText = 'Camera enabled. Scanning for obstacles.';
      } else {
        _statusText = 'Camera disabled.';
        _sceneDescription = '';
      }
    });

    await _tts.speak(enable ? 'Camera enabled' : 'Camera disabled');
  }

  /// Start navigation
  Future<void> _startNavigation() async {
    if (!_isInitialized) {
      await _tts.speak('Please wait, app is initializing.');
      return;
    }

    setState(() {
      _isNavigating = true;
      _statusText = AppLocalizations.of(context)!.navigationStarted;
    });

    await _haptic.turnNotification();
    await _tts.speak(AppLocalizations.of(context)!.navigationStarted);

    final position = await _location.getCurrentLocation();
    if (position == null) {
      await _tts.speak('Could not get location. Please check GPS.');
      setState(() {
        _isNavigating = false;
        _statusText = 'Location error';
      });
      return;
    }

    String destination = _destinationController.text.trim();
    if (destination.isEmpty) {
      destination = 'nearest coffee shop';
    }

    final result = await _navigation.getDirections(
      originLat: position.latitude,
      originLng: position.longitude,
      destination: destination,
    );

    if (!result.success) {
      await _tts.speak('Could not find internal directions. Opening Google Maps.');
      
      bool launched = await _navigation.launchGoogleMaps(destination);
      if (!launched) {
        await _tts.speak('Could not open Google Maps.');
        setState(() {
          _isNavigating = false;
          _statusText = 'Navigation failed';
        });
      } else {
        setState(() {
          _isNavigating = false;
          _statusText = 'Opened Google Maps';
        });
      }
      return;
    }

    await _tts.speak(
      'Route found. ${result.totalDistance}. ${result.totalDuration}.',
    );

    _location.onPositionUpdate = _handlePositionUpdate;
    await _location.startTracking();

    _announceCurrentStep();
    setState(() => _statusText = 'Navigating to $destination');
  }

  void _handlePositionUpdate(position) {
    // Check proximity to waypoints
  }

  Future<void> _announceCurrentStep() async {
    String instruction = _navigation.getCurrentVoiceInstruction();
    
    if (_gemini.isReady && !_isMockMode) {
      instruction = await _gemini.refineInstruction(instruction);
    }

    setState(() => _currentInstruction = instruction);
    await _tts.speak(instruction);

    if (_navigation.isCurrentStepATurn()) {
      bool? isLeft = _navigation.isLeftTurn();
      if (isLeft != null) {
        await _haptic.directionFeedback(isLeft: isLeft);
      }
    }
  }

  Future<void> _nextStep() async {
    if (!_isNavigating) return;

    bool hasNext = _navigation.nextStep();
    if (hasNext) {
      await _announceCurrentStep();
    } else {
      await _haptic.navigationComplete();
      await _tts.speak(AppLocalizations.of(context)!.youHaveArrived);
      _stopNavigation();
    }
  }

  void _stopNavigation() async {
    _isNavigating = false;
    await _location.stopTracking();
    _navigation.stopNavigation();

    setState(() {
      _statusText = AppLocalizations.of(context)!.navigationStoppedCameraActive;
      _currentInstruction = '';
    });

    await _tts.speak(AppLocalizations.of(context)!.navigationStopped);
  }

  /// Manual SOS trigger
  Future<void> _triggerSOS() async {
    await _haptic.sosConfirmation();
    await _tts.speak('SOS activated.');

    setState(() => _statusText = '🆘 SOS ACTIVATED');

    final result = await _sos.triggerSOS(
      additionalContext: _currentInstruction.isNotEmpty 
          ? _currentInstruction 
          : _sceneDescription,
      detectedObstacles: _vision.currentDetections.map((d) => d.label).toList(),
    );

    if (result.success) {
      await _tts.speak(result.emergencySummary ?? 'Emergency help requested.');
      if (mounted) _showSOSDialog(result);
    } else {
      await _tts.speak('Error with SOS. Please try calling manually.');
    }
  }

  /// Automatic SOS (from fall or shake)
  Future<void> _triggerAutoSOS(String reason) async {
    await _haptic.sosConfirmation();
    
    final result = await _sos.triggerSOS(
      additionalContext: '$reason. ${_sceneDescription}',
      fallDetected: reason.contains('Fall'),
      shouldCall: true,
      shouldText: true,
    );

    if (result.success) {
      await _tts.speak(
        'Automatic SOS sent. $reason. ${result.emergencySummary ?? "Help requested."}'
      );
      if (mounted) _showSOSDialog(result);
    }
  }

  void _showSOSDialog(SosResult result) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (context) => _SOSDialogContent(
        result: result,
        onClose: () {
          Navigator.pop(context);
          _cancelFallSOS();
        },
      ),
    );
  }

  void _showContactsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Emergency Contacts'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_sos.contacts.isEmpty)
              const Text('No contacts. Add someone who can help.')
            else
              ..._sos.contacts.map((c) => ListTile(
                leading: const Icon(Icons.person),
                title: Text(c.name),
                subtitle: Text(c.phoneNumber),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    _sos.removeContact(c.phoneNumber);
                    Navigator.pop(context);
                    _showContactsDialog();
                  },
                ),
              )),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _addContactDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add Contact'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  void _addContactDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Emergency Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Phone'),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && phoneController.text.isNotEmpty) {
                _sos.addContact(EmergencyContact(
                  name: nameController.text,
                  phoneNumber: phoneController.text,
                ));
                Navigator.pop(context);
                _tts.speak('Contact added');
              }
            },
            child: const Text('ADD'),
          ),
        ],
      ),
    );
  }

  void _toggleMockMode() {
    setState(() {
      _isMockMode = !_isMockMode;
      _navigation.useMock = _isMockMode;
      _gemini.useMock = _isMockMode;
      _vision.useMock = _isMockMode;
    });
    _tts.speak(_isMockMode ? 'Demo mode on' : 'Demo mode off');
  }

  /// Open settings screen
  void _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  /// Open tutorial screen
  void _openTutorial() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TutorialScreen()),
    );
  }

  /// Handle navigate to command (e.g., "navigate to home")
  Future<void> _handleNavigateToCommand(String command) async {
    // Extract location name from command
    String locationName = '';
    if (command.contains('navigate to')) {
      locationName = command.split('navigate to').last.trim();
    } else if (command.contains('go to')) {
      locationName = command.split('go to').last.trim();
    }

    if (locationName.isEmpty) {
      await _tts.speak('Please specify a location name.');
      return;
    }

    // Check saved locations
    final savedLocation = _savedLocations.getLocationByName(locationName);
    if (savedLocation != null) {
      // Navigate to saved location
      _destinationController.text = '${savedLocation.latitude},${savedLocation.longitude}';
      await _tts.speak('Navigating to $locationName.');
      await _startNavigation();
    } else {
      // Try as regular destination
      _destinationController.text = locationName;
      await _tts.speak('Navigating to $locationName.');
      await _startNavigation();
    }
  }

  /// Save current location with a name
  Future<void> _saveCurrentLocation() async {
    final position = await _location.getCurrentLocation();
    if (position == null) {
      await _tts.speak('Could not get current location.');
      return;
    }

    // Show dialog to name the location
    final nameController = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          'Save Location',
          style: TextStyle(color: Colors.white, fontSize: _settings.textSize),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          style: TextStyle(color: Colors.white, fontSize: _settings.textSize),
          decoration: InputDecoration(
            hintText: 'Enter location name (e.g., Home)',
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white12,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, nameController.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final location = SavedLocation(
        name: result,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      final saved = await _savedLocations.saveLocation(location);
      if (saved) {
        await _tts.speak('Location saved as ${location.name}.');
      } else {
        await _tts.speak('Failed to save location. Name may already exist.');
      }
    }
  }

  /// Show voice command input dialog
  void _showVoiceCommandDialog() {
    showDialog(
      context: context,
      builder: (context) => const VoiceCommandDialog(),
    );
  }

  /// Handle volume button double press (photo capture)
  void _handleVolumeDoublePress() {
    _haptic.buttonPress();
    _capturePhotoAndDescribe();
  }

  /// Handle volume button triple press (voice command)
  void _handleVolumeTriplePress() async {
    _haptic.buttonPress();
    await _tts.speak('Listening for command');
    await _voice.startListening();
  }

  /// Handle triple tap on screen (voice command)
  void _handleTripleTap() {
    final now = DateTime.now();
    
    if (_lastTapTime == null || now.difference(_lastTapTime!) > _tripleTapWindow) {
      _tapCount = 1;
      _lastTapTime = now;
    } else {
      _tapCount++;
      if (_tapCount >= 3) {
        _handleVolumeTriplePress();
        _tapCount = 0;
        _lastTapTime = null;
        return;
      }
    }
    
    // Reset counter after window
    Future.delayed(_tripleTapWindow, () {
      if (_tapCount < 3) {
        _tapCount = 0;
      }
    });
  }


  /// Capture photo and describe with Gemini
  Future<void> _capturePhotoAndDescribe() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      await _tts.speak('Camera not ready');
      return;
    }

    if (_isCapturingPhoto) return;
    _isCapturingPhoto = true;

    try {
      await _tts.speak('Capturing photo');
      await _haptic.cameraModeChange(enabled: true);

      final image = await _cameraController!.takePicture();
      _lastCapturedPhotoPath = image.path;

      setState(() {
        _statusText = 'Processing photo...';
      });

      // Read text from image if available
      String ocrText = '';
      try {
        ocrText = await _ocr.recognizeTextFromFile(image.path);
        if (ocrText.isNotEmpty && ocrText != 'No text detected') {
          await _tts.speak('Text detected: $ocrText');
        }
      } catch (e) {
        debugPrint('OCR error: $e');
      }

      // Get Gemini description
      if (_gemini.isReady && widget.geminiApiKey != null) {
        await _tts.speak('Analyzing scene with AI');
        final description = await _gemini.describeImage(image.path);
        await _tts.speak(description);
        setState(() {
          _sceneDescription = description;
          _statusText = 'Photo analyzed';
        });
      } else {
        await _tts.speak('Photo captured. Gemini AI not available for description.');
      }
    } catch (e) {
      debugPrint('Photo capture error: $e');
      await _tts.speak('Error capturing photo');
    } finally {
      _isCapturingPhoto = false;
    }
  }

  /// Read text from current camera view
  Future<void> _readTextFromCamera() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      await _tts.speak('Camera not ready');
      return;
    }

    try {
      await _tts.speak('Reading text from camera');
      
      // Capture a frame
      final image = await _cameraController!.takePicture();
      
      // Process with OCR
      final text = await _ocr.recognizeTextFromFile(image.path);
      
      if (text.isNotEmpty && text != 'No text detected') {
        await _tts.speak('Text found: $text');
        setState(() {
          _statusText = 'Text: $text';
        });
      } else {
        await _tts.speak('No text detected in view');
      }
      
      // Clean up temporary file
      try {
        final file = File(image.path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error deleting temp file: $e');
      }
    } catch (e) {
      debugPrint('Text reading error: $e');
      await _tts.speak('Error reading text');
    }
  }

  Future<void> _disposeServices() async {
    await _tts.dispose();
    await _sensor.dispose();
    await _location.dispose();
    await _vision.dispose();
    await _ocr.dispose();
    await _gesture.dispose();
    _voice.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // FULL SCREEN Camera preview with contrast filter
            if (_vision.isCameraEnabled && _cameraController != null && _cameraController!.value.isInitialized)
              Positioned.fill(
                child: ColorFiltered(
                  colorFilter: ColorFilter.matrix([
                    _settings.contrast, 0, 0, 0, (1 - _settings.contrast) * 0.5 * 255,
                    0, _settings.contrast, 0, 0, (1 - _settings.contrast) * 0.5 * 255,
                    0, 0, _settings.contrast, 0, (1 - _settings.contrast) * 0.5 * 255,
                    0, 0, 0, 1, 0,
                  ]),
                  child: CameraPreview(_cameraController!),
                ),
              )
            else
              Positioned.fill(
                child: Container(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _vision.isCameraEnabled ? Icons.camera_alt : Icons.videocam_off,
                          size: 80,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _vision.isCameraEnabled ? 'Initializing camera...' : 'Camera disabled',
                          style: const TextStyle(color: Colors.white54, fontSize: 18),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Full screen gesture area for voice commands (triple tap anywhere on screen)
            // This is behind other widgets but captures taps in empty areas
            Positioned.fill(
              child: GestureDetector(
                onTap: _handleTripleTap,
                behavior: HitTestBehavior.translucent,
                child: Container(color: Colors.transparent),
              ),
            ),

            // Fall detection cancel tap zone (accessible via gesture/voice)
            if (_statusText.contains('FALL DETECTED'))
              Positioned.fill(
                child: GestureDetector(
                  onTap: _cancelFallSOS,
                  onLongPress: _cancelFallSOS, // Long press also cancels
                  behavior: HitTestBehavior.opaque,
                  child: Container(color: Colors.red.withOpacity(0.3)),
                ),
              ),

            // Overlay content
            Column(
              children: [
                // Status bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: Colors.black.withOpacity(0.5 + (_settings.contrast - 1.0).clamp(0.0, 0.4)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _statusText,
                        style: TextStyle(
                          color: _settings.contrast > 1.2 ? Colors.yellow : Colors.white,
                          fontSize: _settings.textSize,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_sceneDescription.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 60),
                          child: SingleChildScrollView(
                            child: Text(
                              _sceneDescription,
                              style: TextStyle(
                                color: _settings.contrast > 1.2 ? Colors.white : Colors.white70,
                                fontSize: _settings.textSize * 0.8,
                                fontWeight: _settings.contrast > 1.2 ? FontWeight.w500 : FontWeight.normal,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      if (_voice.isListening) ...[
                        const SizedBox(height: 4),
                        const Text(
                          '🎤 Listening...',
                          style: TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),

                const Spacer(),

                // Bottom controls
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.black.withOpacity(0.5 + (_settings.contrast - 1.0).clamp(0.0, 0.4)),
                  child: Column(
                    children: [
                      // Destination input (collapsed when not navigating)
                      if (!_isNavigating)
                        TextField(
                          controller: _destinationController,
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                          decoration: InputDecoration(
                            hintText: 'Destination (optional)',
                            hintStyle: const TextStyle(color: Colors.white54),
                            filled: true,
                            fillColor: Colors.white24,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                        ),

                      if (!_isNavigating) const SizedBox(height: 12),

                      // Main action buttons row
                      Row(
                        children: [
                          // Start/Stop Navigation
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 80 * _settings.buttonSize,
                              child: ElevatedButton.icon(
                                onPressed: _isNavigating ? _stopNavigation : _startNavigation,
                                icon: Icon(_isNavigating ? Icons.stop : Icons.navigation, size: 32),
                                label: Text(
                                  _isNavigating ? 'STOP' : 'START',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isNavigating ? Colors.orange : Colors.green,
                                  foregroundColor: Colors.white,
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // SOS Button
                          Expanded(
                            child: SizedBox(
                              height: 80 * _settings.buttonSize,
                              child: ElevatedButton(
                                onPressed: _triggerSOS,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  elevation: 8,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.warning, size: 28),
                                    Text('SOS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Secondary buttons row
                      Row(
                        children: [
                          // Camera toggle
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _toggleCamera,
                              icon: Icon(
                                _vision.isCameraEnabled ? Icons.videocam : Icons.videocam_off,
                                color: _vision.isCameraEnabled ? Colors.blueAccent : Colors.white
                              ),
                              label: Text(
                                _vision.isCameraEnabled ? 'CAM ON' : 'CAM OFF',
                                style: TextStyle(
                                  color: _vision.isCameraEnabled ? Colors.blueAccent : Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                )
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.black45,
                                side: BorderSide(
                                  color: _vision.isCameraEnabled ? Colors.blueAccent : Colors.white54,
                                  width: 2,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Auto Describe toggle
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _toggleAutoDescribe,
                              icon: Icon(
                                _isAutoDescribing ? Icons.visibility : Icons.visibility_off,
                                color: _isAutoDescribing ? Colors.greenAccent : Colors.white
                              ),
                              label: Text(
                                _isAutoDescribing ? 'AUTO ON' : 'AUTO OFF',
                                style: TextStyle(
                                  color: _isAutoDescribing ? Colors.greenAccent : Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                )
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.black45,
                                side: BorderSide(
                                  color: _isAutoDescribing ? Colors.greenAccent : Colors.white54,
                                  width: 2,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Third buttons row
                      Row(
                        children: [
                          // Next step (during navigation)
                          if (_isNavigating)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _nextStep,
                                icon: const Icon(Icons.arrow_forward, color: Colors.white),
                                label: const Text('NEXT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  backgroundColor: Colors.black45,
                                  side: const BorderSide(color: Colors.white54, width: 2),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          if (_isNavigating) const SizedBox(width: 8),
                          // Contacts button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showContactsDialog,
                              icon: const Icon(Icons.contacts, color: Colors.white),
                              label: const Text('CONTACTS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.black45,
                                side: const BorderSide(color: Colors.white54, width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Map button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const MapScreen()));
                              },
                              icon: const Icon(Icons.map, color: Colors.cyanAccent),
                              label: const Text('MAP', style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.black45,
                                side: const BorderSide(color: Colors.cyanAccent, width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Fourth buttons row - Photo capture and Settings
                      Row(
                        children: [
                          // Photo capture button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isCapturingPhoto ? null : _capturePhotoAndDescribe,
                              icon: Icon(
                                Icons.camera_alt,
                                color: _isCapturingPhoto ? Colors.grey : Colors.blueAccent,
                              ),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _isCapturingPhoto ? 'CAPTURING...' : 'PHOTO',
                                  style: TextStyle(
                                    color: _isCapturingPhoto ? Colors.grey : Colors.blueAccent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.black45,
                                side: BorderSide(
                                  color: _isCapturingPhoto ? Colors.grey : Colors.blueAccent,
                                  width: 2,
                                ),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Read text button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _readTextFromCamera,
                              icon: const Icon(Icons.text_fields, color: Colors.purpleAccent),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: const Text(
                                  'READ TEXT',
                                  style: TextStyle(color: Colors.purpleAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.black45,
                                side: const BorderSide(color: Colors.purpleAccent, width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Voice command button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _showVoiceCommandDialog,
                              icon: const Icon(Icons.mic, color: Colors.orange),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: const Text(
                                  'VOICE',
                                  style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.black45,
                                side: const BorderSide(color: Colors.orange, width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Settings button
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _openSettings,
                              icon: const Icon(Icons.settings, color: Colors.white),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: const Text(
                                  'SETTINGS',
                                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.black45,
                                side: const BorderSide(color: Colors.white54, width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Tutorial and Demo mode row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            onPressed: _openTutorial,
                            icon: const Icon(Icons.school, color: Colors.blueAccent, size: 20),
                            label: const Text(
                              'TUTORIAL',
                              style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _toggleMockMode,
                            icon: Icon(
                              _isMockMode ? Icons.check_box : Icons.check_box_outline_blank,
                              color: Colors.white54,
                              size: 20,
                            ),
                            label: Text(
                              'Demo ${_isMockMode ? "ON" : "OFF"}',
                              style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SosOverlay(),
          ],
        ),
      ),
    );
  }
}

/// Enhanced SOS Dialog with animations and better UX
class _SOSDialogContent extends StatefulWidget {
  final SosResult result;
  final VoidCallback onClose;

  const _SOSDialogContent({
    required this.result,
    required this.onClose,
  });

  @override
  State<_SOSDialogContent> createState() => _SOSDialogContentState();
}

class _SOSDialogContentState extends State<_SOSDialogContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;
  final SosService _sos = SosService();

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locationUrl = widget.result.locationData?['googleMapsUrl'] as String?;
    final latitude = widget.result.locationData?['latitude'] as double?;
    final longitude = widget.result.locationData?['longitude'] as double?;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.red[900]!,
              Colors.red[800]!,
              Colors.red[900]!,
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.red.withOpacity(0.5),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with animated icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  ScaleTransition(
                    scale: _pulseAnimation,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 48,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'SOS EMERGENCY',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.result.success
                        ? 'Help has been requested'
                        : 'Emergency alert failed',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emergency Summary
                    if (widget.result.emergencySummary != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.white,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                widget.result.emergencySummary!,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Status Section
                    _buildStatusSection(),

                    // Location Section
                    if (locationUrl != null || (latitude != null && longitude != null)) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: Colors.white,
                                  size: 24,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Location',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (locationUrl != null)
                              SelectableText(
                                locationUrl,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              )
                            else if (latitude != null && longitude != null)
                              SelectableText(
                                'Coordinates: ${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Action Buttons
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),

            // Footer with close button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.2),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: widget.onClose,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    ),
                  ),
                  child: const Text(
                    'CLOSE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    final List<Widget> statusItems = [];

    // Call status
    if (widget.result.callMade == true) {
      statusItems.add(_buildStatusItem(
        icon: Icons.phone,
        label: 'Emergency Call',
        status: 'Made',
        color: Colors.green,
      ));
    } else if (widget.result.callMade == false) {
      statusItems.add(_buildStatusItem(
        icon: Icons.phone_disabled,
        label: 'Emergency Call',
        status: 'Not made',
        color: Colors.orange,
      ));
    }

    // SMS status
    if (widget.result.smsResults != null && widget.result.smsResults!.isNotEmpty) {
      for (var smsResult in widget.result.smsResults!) {
        final parts = smsResult.split(':');
        if (parts.length >= 2) {
          final contactName = parts[0].trim();
          final status = parts[1].trim();
          statusItems.add(_buildStatusItem(
            icon: Icons.message,
            label: 'SMS to $contactName',
            status: status,
            color: status == 'Sent' ? Colors.green : Colors.red,
          ));
        }
      }
    }

    if (statusItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Colors.white,
                size: 24,
              ),
              SizedBox(width: 8),
              Text(
                'Status',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...statusItems,
        ],
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String status,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color, width: 1),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Call button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await _sos.makeEmergencyCall();
            },
            icon: const Icon(Icons.phone, color: Colors.white, size: 24),
            label: const Text(
              'CALL 112',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
            ),
          ),
        ),
        const SizedBox(height: 12),
        // SMS button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              if (_sos.contacts.isNotEmpty) {
                await _sos.sendSMS(
                  _sos.contacts.first.phoneNumber,
                  widget.result.smsMessage ?? 'Emergency!',
                );
              }
            },
            icon: const Icon(Icons.message, color: Colors.white, size: 24),
            label: const Text(
              'SEND SMS',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
            ),
          ),
        ),
      ],
    );
  }
}
