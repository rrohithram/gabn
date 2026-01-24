import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'settings_service.dart';

/// Voice Command Service with real speech recognition
class VoiceCommandService extends ChangeNotifier {
  static final VoiceCommandService _instance = VoiceCommandService._internal();
  factory VoiceCommandService() => _instance;
  VoiceCommandService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isAvailable = false;
  
  String _lastRecognizedWords = '';
  String get lastRecognizedWords => _lastRecognizedWords;
  bool get isListening => _isListening;
  bool get isAvailable => _isAvailable;

  // Core navigation callbacks
  VoidCallback? onStartNavigation;
  VoidCallback? onStopNavigation;
  VoidCallback? onNextStep;
  VoidCallback? onSOS;
  VoidCallback? onHelp;
  VoidCallback? onRepeat;
  VoidCallback? onTime;
  VoidCallback? onBattery;
  VoidCallback? onLocation;
  
  // New callbacks for enhanced functionality
  VoidCallback? onDescribeScene;
  VoidCallback? onToggleCamera;
  VoidCallback? onCameraEnable;
  VoidCallback? onCameraDisable;
  VoidCallback? onSpeedUp;
  VoidCallback? onSlowDown;
  VoidCallback? onPause;
  VoidCallback? onResume;
  VoidCallback? onNearbyPlaces;
  VoidCallback? onReadObstacles;
  VoidCallback? onStatus;
  
  // Flashlight commands
  VoidCallback? onFlashlightOn;
  VoidCallback? onFlashlightOff;
  
  void Function(String text)? onUnrecognizedCommand;

  Future<void> initialize() async {
    _isAvailable = await _speech.initialize(
      onError: (error) {
        debugPrint('Speech recognition error: $error');
        _isListening = false;
        notifyListeners();
      },
      onStatus: (status) {
        debugPrint('Speech recognition status: $status');
        if (status == 'done' || status == 'notListening') {
          _isListening = false;
          notifyListeners();
        }
      },
    );
    debugPrint('VoiceCommandService initialized. Available: $_isAvailable');
  }

  /// Start listening for voice commands (activated by gesture)
  Future<void> startListening() async {
    // Prevent re-entry if already initializing or listening
    if (_isListening) return;

    if (!_isAvailable) {
      // Don't re-attempt constantly if it failed recently? 
      // check if we are already initialized in the engine
      bool available = await _speech.initialize(
        onError: (error) {
          debugPrint('Speech recognition error: $error');
          _isListening = false;
          notifyListeners();
        },
        onStatus: (status) {
          debugPrint('Speech recognition status: $status');
          if (status == 'done' || status == 'notListening') {
            _isListening = false;
            notifyListeners();
          }
        },
      );
      _isAvailable = available;
      
      if (!_isAvailable) {
        debugPrint('Speech recognition not available');
        notifyListeners(); // Notify UI that it failed
        return;
      }
    }
    
    _isListening = true;
    notifyListeners();

    try {
      // Ensure we don't start if system says we are listening
      if (_speech.isListening) {
         await _speech.stop();
      }

      await _speech.listen(
        onResult: (result) {
          _lastRecognizedWords = result.recognizedWords;
          
          if (result.finalResult) {
            // Speech finished, process the command
            debugPrint('Final result: ${result.recognizedWords}');
            processCommand(result.recognizedWords);
            stopListening();
          }
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_US',
        cancelOnError: true,
        partialResults: false,
      );
    } catch (e) {
      debugPrint('Error starting speech recognition: $e');
      _isListening = false;
      notifyListeners();
    }
  }

  /// Stop listening and release resources immediately
  Future<void> stopListening() async {
    if (!_isListening) return;
    
    try {
      // cancel() is more aggressive/safer for releasing microphone than stop()
      await _speech.cancel(); 
    } catch (e) {
      debugPrint('Error stopping speech: $e');
    }
    _isListening = false;
    notifyListeners();
  }

  /// Process text command with delay to allow STT to cleanup
  void processCommand(String text) async {
    final command = text.toLowerCase().trim();
    if (command.isEmpty) return;
    
    _lastRecognizedWords = command;
    debugPrint('Processing command: $command');

    // Force stop if not already
    if (_isListening) {
      await stopListening();
    }

    // Wait for configured delay (default 1000ms safe buffer) plus user setting
    // This prevents native crashes where Mic and TTS conflict
    // We add a minimum 500ms safety buffer even if user sets 0
    final minDelay = 500; 
    final extraDelay = SettingsService().commandDelay;
    await Future.delayed(Duration(milliseconds: minDelay + extraDelay));
    
    // Navigation commands - check for "navigate to" or "go to" first
    if (command.contains('navigate to') || command.contains('go to')) {
      onUnrecognizedCommand?.call(command);
    } else if (command.contains('start') && (command.contains('navigation') || command.contains('navigate'))) {
      onStartNavigation?.call();
    } else if (command.contains('stop') || command.contains('cancel') || command.contains('end')) {
      onStopNavigation?.call();
    } else if (command.contains('next') || command.contains('continue')) {
      onNextStep?.call();
    } 
    // Help and repeat
    else if (command.contains('help') && !command.contains('help me')) {
      onHelp?.call();
    } else if (command.contains('repeat') || command.contains('say again') || command.contains('again')) {
      onRepeat?.call();
    } 
    // Emergency
    else if (command.contains('sos') || command.contains('emergency') || command.contains('help me')) {
      onSOS?.call();
    } 
    // Information commands
    else if (command.contains('time') || command.contains('clock') || command.contains('what time')) {
      onTime?.call();
    } else if (command.contains('battery') || command.contains('power') || command.contains('battery level')) {
      onBattery?.call();
    } else if (command.contains('where') || command.contains('location') || command.contains('address') || command.contains('where am i')) {
      onLocation?.call();
    } 
    // Scene and obstacle commands
    else if (command.contains('describe') || command.contains('see') || command.contains('look')) {
      onDescribeScene?.call();
    } else if (command.contains('obstacle') || command.contains('ahead') || command.contains('front')) {
      onReadObstacles?.call();
    } 
    // Camera commands
    else if (command.contains('camera') || command.contains('vision')) {
      if (command.contains('on') || command.contains('enable') || command.contains('start')) {
         onCameraEnable?.call();
      } else if (command.contains('off') || command.contains('disable') || command.contains('stop')) {
         onCameraDisable?.call();
      } else {
         onToggleCamera?.call();
      }
    } 
    // Flashlight commands
    else if (command.contains('flashlight') || command.contains('torch') || command.contains('light')) {
      if (command.contains('off') || command.contains('disable') || command.contains('stop')) {
        onFlashlightOff?.call();
      } else {
        onFlashlightOn?.call();
      }
    }
    // Speed control
    else if (command.contains('faster') || command.contains('speed up') || command.contains('quick')) {
      onSpeedUp?.call();
    } else if (command.contains('slower') || command.contains('slow down')) {
      onSlowDown?.call();
    } 
    // Pause/Resume
    else if (command.contains('pause') || command.contains('quiet') || command.contains('mute')) {
      onPause?.call();
    } else if (command.contains('resume') || command.contains('unmute') || command.contains('speak')) {
      onResume?.call();
    } 
    // Nearby places
    else if (command.contains('nearby') || command.contains('around') || command.contains('places')) {
      onNearbyPlaces?.call();
    }
    // Status
    else if (command.contains('status')) {
      onStatus?.call();
    }
    // Unrecognized - pass to handler
    else {
      onUnrecognizedCommand?.call(command);
    }
  }

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  String getAvailableCommands() {
    return "You can say: Start Navigation, Stop, Next, Repeat, Describe Scene, "
           "What's Ahead, Toggle Camera, Faster, Slower, Pause, Resume, "
           "Time, Battery, Location, Nearby Places, Status, Navigate to [location], Save Location, or SOS.";
  }
}
