import 'package:flutter/material.dart';
import '../services/voice_command_service.dart';
import '../services/tts_service.dart';
import '../services/settings_service.dart';

/// Dialog for voice commands with visual feedback
class VoiceCommandDialog extends StatefulWidget {
  const VoiceCommandDialog({super.key});

  @override
  State<VoiceCommandDialog> createState() => _VoiceCommandDialogState();
}

class _VoiceCommandDialogState extends State<VoiceCommandDialog> {
  final TextEditingController _commandController = TextEditingController();
  final VoiceCommandService _voice = VoiceCommandService();
  final TtsService _tts = TtsService();
  final SettingsService _settings = SettingsService();

  bool _isListening = false;
  bool _showKeyboard = false;
  String _statusText = 'Initializing...';
  bool _isProcessingCommand = false;

  @override
  void initState() {
    super.initState();
    _voice.addListener(_onVoiceStateChanged);
    _startListening();
  }

  @override
  void dispose() {
    _voice.removeListener(_onVoiceStateChanged);
    // Only stop listening if we are NOT processing a command
    // If we are processing, the service handles the stop sequence safely
    if (!_isProcessingCommand) {
      _voice.stopListening();
    }
    _commandController.dispose();
    super.dispose();
  }

  void _onVoiceStateChanged() {
    if (mounted) {
      if (_isProcessingCommand) return; // Ignore updates if we are done

      setState(() {
        _isListening = _voice.isListening;
        if (_voice.lastRecognizedWords.isNotEmpty) {
           _commandController.text = _voice.lastRecognizedWords;
        }
      });

      // If listening stopped and we have text, process it automatically after a brief pause
      if (!_isListening && _voice.lastRecognizedWords.isNotEmpty && !_showKeyboard) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted && !_isListening && !_isProcessingCommand) {
            _processCommand();
          }
        });
      }
    }
  }

  Future<void> _startListening() async {
    setState(() => _statusText = 'Listening...');
    await _voice.startListening();
    if (!_voice.isAvailable) {
      if (mounted) {
        setState(() {
          _statusText = 'Voice unavailable. Use keyboard.';
          _showKeyboard = true;
        });
      }
      _tts.speak('Voice recognition not available. Please type your command.');
    }
  }

  void _processCommand() {
    if (_isProcessingCommand) return;
    
    final command = _commandController.text.trim();
    if (command.isNotEmpty) {
      _isProcessingCommand = true; // Flag to prevent double processing / dispose cleanup
      _voice.processCommand(command);
      
      if (mounted) Navigator.pop(context);
      // Removed immediate TTS "Command processed" to prevent audio conflict crash
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: Row(
        children: [
          Icon(
            _isListening ? Icons.mic : Icons.mic_none,
            color: _isListening ? Colors.redAccent : Colors.white,
          ),
          const SizedBox(width: 8),
          Text(
            'Voice Command',
            style: TextStyle(
              color: Colors.white,
              fontSize: _settings.textSize,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_showKeyboard)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Text(
                    _isListening ? 'Listening...' : (_commandController.text.isNotEmpty ? 'Processing...' : 'Tap mic to speak'),
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  if (_commandController.text.isNotEmpty)
                    Text(
                      '"${_commandController.text}"',
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          
          if (_showKeyboard)
            TextField(
              controller: _commandController,
              autofocus: true,
              style: TextStyle(
                color: Colors.white,
                fontSize: _settings.textSize,
              ),
              decoration: InputDecoration(
                hintText: 'Enter command',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _processCommand(),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(_showKeyboard ? Icons.mic : Icons.keyboard),
          color: Colors.white,
          onPressed: () {
            setState(() {
              _showKeyboard = !_showKeyboard;
              if (_showKeyboard) {
                _voice.stopListening();
              } else {
                _startListening();
              }
            });
          },
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
        ),
        if (_showKeyboard)
          ElevatedButton(
            onPressed: _processCommand,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Execute'),
          ),
      ],
    );
  }
}

