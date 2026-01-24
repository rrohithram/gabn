import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:io';

/// Gemini AI service for reasoning tasks
/// Used ONLY for refining instructions and emergency summaries
/// NOT for real-time vision or navigation decisions
class GeminiService {
  static final GeminiService _instance = GeminiService._internal();
  factory GeminiService() => _instance;
  GeminiService._internal();

  GenerativeModel? _model;
  bool _isInitialized = false;

  // Mock mode for testing without API
  bool useMock = false;

  /// Initialize with API key
  void initialize(String apiKey) {
    if (apiKey.isEmpty) {
      print('Gemini API key is empty');
      return;
    }

    _model = GenerativeModel(
      model: 'gemini-2.5-flash', // Use stable flash model
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        maxOutputTokens: 1024,
      ),
    );
    _isInitialized = true;
  }

  /// Refine a navigation instruction into accessibility-friendly language
  Future<String> refineInstruction(String instruction) async {
    if (useMock) {
      return _mockRefineInstruction(instruction);
    }

    if (!_isInitialized || _model == null) {
      return instruction; // Return original if not initialized
    }

    try {
      final prompt = '''
You are helping a blind person navigate. Rewrite this navigation instruction to be:
- Clear and concise
- Using clock positions for directions (e.g., "turn to your 3 o'clock" instead of "turn right")
- Including tactile or environmental cues when possible
- Easy to understand through audio

Original instruction: "$instruction"

Respond with ONLY the refined instruction, no explanations.
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text ?? instruction;
    } catch (e) {
      print('Gemini refinement error: $e');
      return instruction; // Fallback to original
    }
  }

  /// Generate an emergency summary for SOS
  Future<String> generateEmergencySummary({
    required Map<String, dynamic> location,
    String? lastInstruction,
    bool? fallDetected,
    List<String>? detectedObstacles,
  }) async {
    if (useMock) {
      return _mockEmergencySummary(location);
    }

    if (!_isInitialized || _model == null) {
      return _fallbackEmergencySummary(location);
    }

    try {
      final prompt = '''
Generate a brief emergency summary for a blind person's SOS alert. Include:
1. Current situation (1 sentence)
2. Location information
3. Any detected hazards or concerns

Context:
- Location: ${location['googleMapsUrl'] ?? 'Unknown'}
- Coordinates: ${location['latitude']}, ${location['longitude']}
- Last navigation instruction: ${lastInstruction ?? 'None'}
- Fall detected: ${fallDetected ?? false}
- Nearby obstacles: ${detectedObstacles?.join(', ') ?? 'None detected'}

Generate a concise emergency message suitable for text or voice call.
''';

      final response = await _model!.generateContent([Content.text(prompt)]);
      return response.text ?? _fallbackEmergencySummary(location);
    } catch (e) {
      print('Gemini SOS error: $e');
      return _fallbackEmergencySummary(location);
    }
  }

  /// Mock instruction refinement for testing
  String _mockRefineInstruction(String instruction) {
    // Simple mock transformations
    String refined = instruction
        .replaceAll('turn right', 'turn to your 3 o\'clock')
        .replaceAll('turn left', 'turn to your 9 o\'clock')
        .replaceAll('Turn right', 'Turn to your 3 o\'clock')
        .replaceAll('Turn left', 'Turn to your 9 o\'clock');
    
    return refined;
  }

  /// Mock emergency summary for testing
  String _mockEmergencySummary(Map<String, dynamic> location) {
    final lat = location['latitude'] ?? 'unknown';
    final lng = location['longitude'] ?? 'unknown';
    final url = location['googleMapsUrl'] ?? '';

    return '''
EMERGENCY ALERT: A visually impaired person needs assistance.

Location: Coordinates $lat, $lng
Map Link: $url

The person has activated their SOS emergency button on their navigation app. Please send help to this location immediately.

This is an automated emergency message.
''';
  }

  /// Fallback summary when Gemini is unavailable
  String _fallbackEmergencySummary(Map<String, dynamic> location) {
    final lat = location['latitude'] ?? 'unknown';
    final lng = location['longitude'] ?? 'unknown';
    final url = location['googleMapsUrl'] ?? '';

    return 'EMERGENCY: Blind user needs help at coordinates $lat, $lng. Map: $url';
  }

  /// Describe an image using Gemini Vision
  Future<String> describeImage(String imagePath) async {
    if (useMock) {
      return _mockImageDescription();
    }

    if (!_isInitialized || _model == null) {
      return 'Gemini AI not available. Please check your API key.';
    }

    try {
      final prompt = '''
Describe this image in detail for a visually impaired person. Include:
- Main objects and people
- Layout and spatial relationships
- Colors and visual characteristics
- Any text visible in the image
- Overall scene context
Be concise but descriptive, suitable for text-to-speech.
''';

      // Read image file
      final imageBytes = await File(imagePath).readAsBytes();
      
      // Create content with image
      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await _model!.generateContent(content);
      return response.text ?? 'Could not generate description';
    } catch (e) {
      print('Gemini image description error: $e');
      return 'Error describing image: $e';
    }
  }

  /// Mock image description for testing
  String _mockImageDescription() {
    return 'Mock description: This appears to be a scene with various objects. '
           'The image contains multiple elements that would be better described with a real AI model.';
  }

  /// Check if service is ready
  bool get isReady => _isInitialized && _model != null;
}
