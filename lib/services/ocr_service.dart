import 'dart:typed_data';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter/foundation.dart';

/// OCR service for reading text from camera images
class OcrService {
  static final OcrService _instance = OcrService._internal();
  factory OcrService() => _instance;
  OcrService._internal();

  TextRecognizer? _textRecognizer;
  CameraController? _cameraController;
  bool _isInitialized = false;

  /// Initialize OCR service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      _isInitialized = true;
      debugPrint('OCR service initialized');
    } catch (e) {
      debugPrint('OCR initialization error: $e');
    }
  }

  /// Set camera controller for image conversion
  void setCameraController(CameraController? controller) {
    _cameraController = controller;
  }

  /// Process camera image and extract text
  Future<String> recognizeText(CameraImage image) async {
    if (!_isInitialized || _textRecognizer == null) {
      await initialize();
      if (_textRecognizer == null) return '';
    }

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return '';

      final recognizedText = await _textRecognizer!.processImage(inputImage);
      
      if (recognizedText.text.isEmpty) {
        return 'No text detected';
      }

      return recognizedText.text;
    } catch (e) {
      debugPrint('OCR error: $e');
      return 'Error reading text';
    }
  }

  /// Process image file and extract text
  Future<String> recognizeTextFromFile(String imagePath) async {
    if (!_isInitialized || _textRecognizer == null) {
      await initialize();
      if (_textRecognizer == null) return '';
    }

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer!.processImage(inputImage);
      
      if (recognizedText.text.isEmpty) {
        return 'No text detected';
      }

      return recognizedText.text;
    } catch (e) {
      debugPrint('OCR error: $e');
      return 'Error reading text';
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_cameraController == null) return null;
    
    try {
      final camera = _cameraController!.description;
      final sensorOrientation = camera.sensorOrientation;
      
      InputImageRotation? rotation;
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        rotation = InputImageRotation.rotation0deg;
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        switch (sensorOrientation) {
          case 90:
            rotation = InputImageRotation.rotation90deg;
          case 270:
            rotation = InputImageRotation.rotation270deg;
          case 180:
            rotation = InputImageRotation.rotation180deg;
          default:
            rotation = InputImageRotation.rotation0deg;
        }
      }
      if (rotation == null) return null;

      final format = InputImageFormat.nv21;
      
      final yPlane = image.planes[0];
      final uPlane = image.planes[1];
      final vPlane = image.planes[2];
      
      final int width = image.width;
      final int height = image.height;
      
      final int ySize = width * height;
      final int uvSize = (width * height) ~/ 2;
      
      final Uint8List nv21Bytes = Uint8List(ySize + uvSize);
      
      int yIndex = 0;
      for (int row = 0; row < height; row++) {
        final int rowStart = row * yPlane.bytesPerRow;
        for (int col = 0; col < width; col++) {
          if (rowStart + col < yPlane.bytes.length) {
            nv21Bytes[yIndex++] = yPlane.bytes[rowStart + col];
          }
        }
      }
      
      int uvIndex = ySize;
      final int uvHeight = height ~/ 2;
      final int uvWidth = width ~/ 2;
      
      for (int row = 0; row < uvHeight; row++) {
        for (int col = 0; col < uvWidth; col++) {
          final int vRowStart = row * vPlane.bytesPerRow;
          final int uRowStart = row * uPlane.bytesPerRow;
          final int pixelStride = vPlane.bytesPerPixel ?? 1;
          
          final int vOffset = vRowStart + (col * pixelStride);
          final int uOffset = uRowStart + (col * pixelStride);
          
          if (uvIndex < nv21Bytes.length && vOffset < vPlane.bytes.length) {
            nv21Bytes[uvIndex++] = vPlane.bytes[vOffset];
          }
          if (uvIndex < nv21Bytes.length && uOffset < uPlane.bytes.length) {
            nv21Bytes[uvIndex++] = uPlane.bytes[uOffset];
          }
        }
      }

      final size = Size(width.toDouble(), height.toDouble());

      final metadata = InputImageMetadata(
        size: size,
        rotation: rotation,
        format: format,
        bytesPerRow: width,
      );

      return InputImage.fromBytes(bytes: nv21Bytes, metadata: metadata);
    } catch (e) {
      debugPrint('Error converting camera image for OCR: $e');
      return null;
    }
  }

  Future<void> dispose() async {
    await _textRecognizer?.close();
    _textRecognizer = null;
    _isInitialized = false;
  }
}

