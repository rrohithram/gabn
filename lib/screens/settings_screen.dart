import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/tts_service.dart';
import '../services/sos_service.dart';

/// Settings screen for accessibility preferences
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settings = SettingsService();
  final TtsService _tts = TtsService();
  final SosService _sos = SosService();

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
    _sos.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    _sos.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Text Size Section
          Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Text Size',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _settings.textSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: _settings.textSize,
                    min: 12.0,
                    max: 32.0,
                    divisions: 20,
                    label: '${_settings.textSize.toStringAsFixed(0)}px',
                    onChanged: (value) async {
                      await _settings.setTextSize(value);
                      _tts.speak('Text size set to ${value.toStringAsFixed(0)}');
                    },
                  ),
                  Text(
                    'Current: ${_settings.textSize.toStringAsFixed(0)}px',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: _settings.textSize * 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Button Size Section
          Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Button Size',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _settings.textSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: _settings.buttonSize,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    label: '${(_settings.buttonSize * 100).toStringAsFixed(0)}%',
                    onChanged: (value) async {
                      await _settings.setButtonSize(value);
                      _tts.speak('Button size set to ${(value * 100).toStringAsFixed(0)} percent');
                    },
                  ),
                  Text(
                    'Current: ${(_settings.buttonSize * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: _settings.textSize * 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Contrast Section
          Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Contrast',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _settings.textSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: _settings.contrast,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    label: '${_settings.contrast.toStringAsFixed(1)}x',
                    onChanged: (value) async {
                      await _settings.setContrast(value);
                      _tts.speak('Contrast set to ${value.toStringAsFixed(1)}');
                    },
                  ),
                  Text(
                    'Current: ${_settings.contrast.toStringAsFixed(1)}x',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: _settings.textSize * 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Vibration Intensity Section
          Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'Vibration Intensity',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _settings.textSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: _settings.vibrationIntensity,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label: '${(_settings.vibrationIntensity * 100).toStringAsFixed(0)}%',
                    onChanged: (value) async {
                      await _settings.setVibrationIntensity(value);
                      _tts.speak('Vibration intensity ${(_settings.vibrationIntensity * 100).toStringAsFixed(0)} percent');
                    },
                  ),
                  Text(
                    'Current: ${(_settings.vibrationIntensity * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: _settings.textSize * 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Command Delay Section
          Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'Command Delay',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _settings.textSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                   Text(
                    'Pause before executing voice commands',
                     style: TextStyle(
                      color: Colors.white70,
                      fontSize: _settings.textSize * 0.6,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: _settings.commandDelay.toDouble(),
                    min: 0.0,
                    max: 3000.0,
                    divisions: 6, // 500ms steps
                    label: '${_settings.commandDelay}ms',
                    onChanged: (value) async {
                      await _settings.setCommandDelay(value.toInt());
                      _tts.speak('Command delay ${_settings.commandDelay} milliseconds');
                    },
                  ),
                  Text(
                    'Current: ${_settings.commandDelay}ms',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: _settings.textSize * 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Speech Rate Section
          Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'Voice Speed',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _settings.textSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: _settings.speechRate,
                    min: 0.1, // Don't allow 0.0 (too slow/stop)
                    max: 1.0,
                    divisions: 9,
                    label: '${_settings.speechRate.toStringAsFixed(1)}x',
                    onChanged: (value) async {
                      await _settings.setSpeechRate(value);
                      await _tts.setSpeechRate(value);
                      _tts.speak('Voice speed ${value.toStringAsFixed(1)}');
                    },
                  ),
                  Text(
                    'Current: ${_settings.speechRate.toStringAsFixed(1)}x',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: _settings.textSize * 0.8,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Emergency Contacts Section
          Card(
            color: Colors.grey[900],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency Contacts',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: _settings.textSize,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_sos.contacts.isEmpty)
                    const Text("No contacts added", style: TextStyle(color: Colors.white70)),
                  ..._sos.contacts.map((contact) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(contact.name, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(contact.phoneNumber, style: const TextStyle(color: Colors.white70)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        _sos.removeContact(contact.phoneNumber);
                        _tts.speak("Removed ${contact.name}");
                      },
                    ),
                  )),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.person_add),
                      label: Text('Add from Contacts', style: TextStyle(fontSize: _settings.textSize * 0.8)),
                      onPressed: () async {
                        try {
                          final contact = await _sos.pickContact();
                          if (contact != null) {
                            _tts.speak("Added ${contact.name} to emergency contacts");
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No contact selected or permission denied')),
                              );
                            }
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Reset Button
          SizedBox(
            width: double.infinity,
            height: 56 * _settings.buttonSize,
            child: ElevatedButton(
              onPressed: () async {
                await _settings.resetToDefaults();
                _tts.speak('Settings reset to defaults');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Settings reset to defaults'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: Text(
                'Reset to Defaults',
                style: TextStyle(fontSize: _settings.textSize),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

