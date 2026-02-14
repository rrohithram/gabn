import 'package:flutter/material.dart';
import '../services/tts_service.dart';
import '../services/settings_service.dart';

/// Tutorial screen for first-time users
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final TtsService _tts = TtsService();
  final SettingsService _settings = SettingsService();
  int _currentStep = 0;

  final List<TutorialStep> _steps = [
    TutorialStep(
      title: 'Welcome',
      description: 'Welcome to Gaze. This app helps you navigate safely using your camera and voice commands.',
      icon: Icons.waving_hand,
    ),
    TutorialStep(
      title: 'Camera Preview',
      description: 'The camera preview shows what\'s in front of you. The app automatically detects obstacles and warns you about them.',
      icon: Icons.camera_alt,
    ),
    TutorialStep(
      title: 'Voice Commands',
      description: 'You can use voice commands to control the app. Say "help" to hear all available commands, or "navigate to" followed by a location name.',
      icon: Icons.mic,
    ),
    TutorialStep(
      title: 'Obstacle Detection',
      description: 'The app uses AI to detect objects in front of you. It will tell you what obstacles are ahead and where they are located.',
      icon: Icons.visibility,
    ),
    TutorialStep(
      title: 'Photo Capture',
      description: 'Press the photo button or double-press the volume button to capture a photo. The app will describe what\'s in the image using AI.',
      icon: Icons.camera,
    ),
    TutorialStep(
      title: 'Text Reading',
      description: 'Use the "Read Text" button or say "read text" to read any text visible in the camera view.',
      icon: Icons.text_fields,
    ),
    TutorialStep(
      title: 'Saved Locations',
      description: 'You can save your current location and navigate to it later by saying "navigate to" followed by the location name, like "navigate to home".',
      icon: Icons.bookmark,
    ),
    TutorialStep(
      title: 'Settings',
      description: 'Adjust text size, button size, and contrast in the settings menu to make the app easier to use.',
      icon: Icons.settings,
    ),
    TutorialStep(
      title: 'Emergency SOS',
      description: 'Press the SOS button or shake your phone vigorously to trigger an emergency alert. The app will send your location to emergency contacts.',
      icon: Icons.warning,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _speakCurrentStep();
  }

  void _speakCurrentStep() {
    if (_currentStep < _steps.length) {
      final step = _steps[_currentStep];
      _tts.speak('${step.title}. ${step.description}');
    }
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
      });
      _speakCurrentStep();
    } else {
      _tts.speak('Tutorial complete. You can now use the app.');
      Navigator.pop(context);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _speakCurrentStep();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Tutorial (${_currentStep + 1}/${_steps.length})'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      step.icon,
                      size: 120 * _settings.buttonSize,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 32),
                    Text(
                      step.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: _settings.textSize * 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      step.description,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: _settings.textSize,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[900],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _currentStep > 0 ? _previousStep : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[700],
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _nextStep,
                  icon: Icon(_currentStep < _steps.length - 1 ? Icons.arrow_forward : Icons.check),
                  label: Text(_currentStep < _steps.length - 1 ? 'Next' : 'Finish'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TutorialStep {
  final String title;
  final String description;
  final IconData icon;

  TutorialStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}

