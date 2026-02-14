import 'dart:typed_data';
import 'dart:ui';
import 'dart:async'; // For Timer
import 'dart:io'; // For File
import 'dart:isolate'; // For Isolate

import 'package:camera/camera.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:flutter/foundation.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:image/image.dart' as img; // image package

/// Detection result with position
class DetectionResult {
  final String label;
  final double confidence;
  final String position; // "left", "center", "right"
  final bool isClose;
  final double relativeWidth;
  
  DetectionResult({
    required this.label,
    required this.confidence,
    required this.position,
    required this.isClose,
    required this.relativeWidth,
  });
  
  String getDescription() {
    String distance = isClose ? "close" : "ahead";
    return "$label $distance on your $position";
  }
}

/// Vision service using Ultralytics YOLO26n with manual image processing
class VisionService {
  static final VisionService _instance = VisionService._internal();
  factory VisionService() => _instance;
  VisionService._internal();

  CameraController? _cameraController;
  YOLO? _objectDetector; // Ultralytics YOLO class
  bool _isInitialized = false;
  bool _isProcessing = false;
  bool _isDetectionActive = false;
  bool _isCameraEnabled = true; // Camera toggle state
  bool _isFlashlightOn = false; // Manual flashlight state
  bool _isLowLight = false; // Auto low-light state
  
  // Detection state
  List<DetectionResult> _currentDetections = [];
  DateTime? _lastDetectionRun; // Throttling
  DateTime? _lastLightCheck; // Light check throttling
  static const Duration _detectionInterval = Duration(milliseconds: 500); 
  String _lastAnnouncedDescription = '';

  // Proximity Alert State
  Timer? _blinkTimer;
  bool _isBlinking = false;
  bool _isProximityAlertActive = false;

  // Settings
  bool useMock = false; 

  // Callbacks
  void Function(List<DetectionResult> detections, String description)? onObstacleDetected;
  void Function(CameraController controller)? onCameraReady;
  void Function(bool enabled)? onCameraToggled;
  void Function(bool on)? onFlashlightChanged;
  
  // Public getters
  List<DetectionResult> get currentDetections => _currentDetections;
  CameraController? get cameraController => _cameraController;
  bool get isCameraEnabled => _isCameraEnabled;
  bool get isInitialized => _isInitialized;
  bool get isFlashlightOn => _isFlashlightOn;

  /// Set Manual Flashlight
  Future<void> setFlashlight(bool on) async {
    _isFlashlightOn = on;
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      if (!_isProximityAlertActive) { // Don't override safety blink
        try {
          await _cameraController!.setFlashMode(on ? FlashMode.torch : FlashMode.off);
        } catch (e) {
          debugPrint('Error setting flash: $e');
        }
      }
    }
    onFlashlightChanged?.call(on);
  }

  /// Trigger Proximity Alert (Blinking + Vibration)
  void _triggerProximityAlert(bool active) {
    if (_isProximityAlertActive == active) return;
    _isProximityAlertActive = active;

    if (active) {
      _startBlinking();
    } else {
      _stopBlinking();
      if (_cameraController != null && _cameraController!.value.isInitialized) {
         _cameraController!.setFlashMode((_isFlashlightOn || _isLowLight) ? FlashMode.torch : FlashMode.off);
      }
    }
  }

  void _startBlinking() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 250), (timer) {
      if (_cameraController != null && _cameraController!.value.isInitialized) {
         _isBlinking = !_isBlinking;
         _cameraController!.setFlashMode(_isBlinking ? FlashMode.torch : FlashMode.off);
         if (_isBlinking) HapticFeedback.heavyImpact(); // Vibrate on blink on
      }
    });
  }

  void _stopBlinking() {
    _blinkTimer?.cancel();
    _blinkTimer = null;
  }
  
  /// Check for low light conditions
  void _checkLowLight(CameraImage image) {
    final now = DateTime.now();
    if (_lastLightCheck != null && now.difference(_lastLightCheck!) < const Duration(seconds: 2)) return;
    _lastLightCheck = now;

    // Y-plane is the first plane
    if (image.planes.isEmpty) return;
    final yPlane = image.planes[0];
    int total = 0;
    int step = 100;
    for (int i = 0; i < yPlane.bytes.length; i += step) {
      total += yPlane.bytes[i];
    }
    double avg = total / (yPlane.bytes.length / step);
    
    bool low = avg < 40;
    if (low != _isLowLight) {
      _isLowLight = low;
      if (!_isFlashlightOn && !_isProximityAlertActive) {
         _cameraController?.setFlashMode(low ? FlashMode.torch : FlashMode.off);
      }
      debugPrint("Light Level: $avg (Low: $low)");
    }
  }

  /// Get current scene description
  String getCurrentSceneDescription() {
    if (_lastAnnouncedDescription.isEmpty) {
      return "Processing scene...";
    }
    return _lastAnnouncedDescription;
  }

  /// Toggle camera on/off
  Future<void> toggleCamera() async {
    _isCameraEnabled = !_isCameraEnabled;
    if (_isCameraEnabled) {
      await startDetection();
    } else {
      await stopDetection();
    }
    onCameraToggled?.call(_isCameraEnabled);
  }

  /// Enable camera
  Future<void> enableCamera() async {
    if (!_isCameraEnabled) {
      _isCameraEnabled = true;
      await startDetection();
      onCameraToggled?.call(true);
    }
  }

  /// Disable camera
  Future<void> disableCamera() async {
    if (_isCameraEnabled) {
      _isCameraEnabled = false;
      await stopDetection();
      onCameraToggled?.call(false);
    }
  }

  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return false;

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.medium, // 720p/480p is good for performance
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(FlashMode.off);
      
      onCameraReady?.call(_cameraController!);

      // Initialize YOLO detector
      await _initializeDetector();
      
      _isInitialized = true;
      debugPrint('Vision service initialized with YOLO26n');
      return true;
    } catch (e) {
      debugPrint('Vision initialization error: $e');
      return false;
    }
  }

  Future<void> _initializeDetector() async {
    try {
      final modelPath = 'assets/models/yolo26n.tflite';
      // Use the correct API based on my research
      _objectDetector = YOLO(
        modelPath: modelPath,
        task: YOLOTask.detect, 
      );
      await (_objectDetector as YOLO).loadModel();
    } catch (e) {
      debugPrint('Error initializing YOLO detector: $e');
    }
  }

  Future<void> startDetection() async {
    if (!_isCameraEnabled) return; 

    if (!_isInitialized || _cameraController == null) await initialize();
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    if (_isDetectionActive) return;
    _isDetectionActive = true;

    try {
      if (!_cameraController!.value.isStreamingImages) {
        await _cameraController!.startImageStream(_processFrame);
        debugPrint('Detection started');
      }
    } catch (e) {
      debugPrint('Error starting stream: $e');
    }
  }

  void _processFrame(CameraImage image) async {
    // Throttling
    final now = DateTime.now();
    if (_lastDetectionRun != null && now.difference(_lastDetectionRun!) < _detectionInterval) {
      return;
    }
    
    if (_isProcessing || _objectDetector == null) return;
    _isProcessing = true;
    _lastDetectionRun = now;

    try {
      _checkLowLight(image); 

      // Prepare data for isolate
      final rawData = CameraImageRaw(
        width: image.width,
        height: image.height,
        planes: image.planes.map((p) => PlaneRaw(
          bytes: p.bytes,
          bytesPerRow: p.bytesPerRow,
          bytesPerPixel: p.bytesPerPixel,
        )).toList(),
        format: image.format.group,
      );

      // 1. Convert YUV to JPEG in background
      final Uint8List? jpegBytes = await compute(_encodeImage, rawData);
      
      if (jpegBytes != null) {
        // 2. Predict using YOLO
        debugPrint("DEBUG: Sending image to YOLO (${jpegBytes.length} bytes)");
        try {
          final result = await (_objectDetector as YOLO).predict(jpegBytes);
          debugPrint("DEBUG: Raw YOLO result: $result");
          
          if (result.keys.isNotEmpty) {
             debugPrint("DEBUG: Result keys: ${result.keys}");
          }

          // 3. Process results — plugin may return 'detections' or 'boxes'
          List<dynamic>? detections = result['detections'] as List<dynamic>?;
          if (detections == null && result.containsKey('boxes')) {
            detections = result['boxes'] as List<dynamic>?;
          }
          if (detections != null && detections.isNotEmpty) {
            debugPrint("DEBUG: Found ${detections.length} detections");
            _processDetections(detections, image.width.toDouble(), image.height.toDouble());
          }
        } catch (e) {
          debugPrint("DEBUG: YOLO prediction failed: $e");
        }
      }
    } catch (e) {
      debugPrint('Frame processing error: $e'); 
    } finally {
      _isProcessing = false;
    }
  }

  void _processDetections(List<dynamic> rawDetections, double imageWidth, double imageHeight) {
    List<DetectionResult> results = [];
    Map<String, int> counts = {};
    bool dangerousProximity = false;

    for (var detectionData in rawDetections) {
      // Clean up detection data to map to our model
      // We expect a Map.
      if (detectionData is! Map) continue;
      
      // Try to parse using YOLOResult if imported, or just manual map access
      // Using manual access to be safe/generic
      // Keys might be 'className', 'confidence', 'boundingBox' (Map or rect info)
      
      String label = detectionData['className'] ?? detectionData['label'] ?? "Unknown";
      label = _normalizeLabel(label);
      
      double confidence = (detectionData['confidence'] as num?)?.toDouble() ?? 0.0;
      
      // Bounding box: ultralytics_yolo uses 'boundingBox' (pixels) and 'normalizedBox' (0–1) with left/top/right/bottom.
      // Also support x/y/width/height and list [x1,y1,x2,y2].
      Rect rect = Rect.zero;
      Map<dynamic, dynamic>? normalizedBox;
      if (detectionData['normalizedBox'] != null && detectionData['normalizedBox'] is Map) {
        normalizedBox = detectionData['normalizedBox'] as Map<dynamic, dynamic>;
      }
      if (detectionData['boundingBox'] != null) {
        final box = detectionData['boundingBox'];
        if (box is Map) {
          final b = Map<String, dynamic>.from(box.map((k, v) => MapEntry(k.toString(), v)));
          // Prefer left/top/right/bottom (ultralytics format)
          if (b.containsKey('left') && b.containsKey('top') && b.containsKey('right') && b.containsKey('bottom')) {
            rect = Rect.fromLTRB(
              (b['left'] as num).toDouble(),
              (b['top'] as num).toDouble(),
              (b['right'] as num).toDouble(),
              (b['bottom'] as num).toDouble(),
            );
          } else {
            double x = (b['x'] as num?)?.toDouble() ?? (b['left'] as num?)?.toDouble() ?? 0;
            double y = (b['y'] as num?)?.toDouble() ?? (b['top'] as num?)?.toDouble() ?? 0;
            double w = (b['width'] as num?)?.toDouble() ?? (b['w'] as num?)?.toDouble() ?? 0;
            double h = (b['height'] as num?)?.toDouble() ?? (b['h'] as num?)?.toDouble() ?? 0;
            if (b.containsKey('right') && b.containsKey('bottom')) {
              rect = Rect.fromLTRB(x, y, (b['right'] as num).toDouble(), (b['bottom'] as num).toDouble());
            } else {
              rect = Rect.fromLTWH(x, y, w, h);
            }
          }
        } else if (box is List && box.length >= 4) {
          double x1 = (box[0] as num).toDouble();
          double y1 = (box[1] as num).toDouble();
          double x2 = (box[2] as num).toDouble();
          double y2 = (box[3] as num).toDouble();
          rect = Rect.fromLTRB(x1, y1, x2, y2);
        }
      }
      // Use normalized box for relative position/size when available (0–1)
      if (normalizedBox != null) {
        final n = Map<String, dynamic>.from(normalizedBox.map((k, v) => MapEntry(k.toString(), v)));
        if (n.containsKey('left') && n.containsKey('top') && n.containsKey('right') && n.containsKey('bottom')) {
          rect = Rect.fromLTRB(
            (n['left'] as num).toDouble(),
            (n['top'] as num).toDouble(),
            (n['right'] as num).toDouble(),
            (n['bottom'] as num).toDouble(),
          );
        }
      }

      if (confidence < 0.25) continue; 

      counts[label] = (counts[label] ?? 0) + 1;
      
      final centerX = rect.center.dx;
      // If we used normalized coordinates?
      // Assuming 'boundingBox' from this package are PIXEL coordinates if image size is known, or Normalized?
      // Usually packages return what valid. 
      // If normalized (0-1), then relativeWidth = rect.width.
      // If pixel, relativeWidth = rect.width / imageWidth.
      
      // Heuristic: if width is small (< 1.0), it's likely normalized.
      // if width is > 1.0, it's pixels.
      double relativeW = rect.width;
      double relativeX = centerX;
      
      if (rect.width > 2.0) {
         relativeW = rect.width / imageWidth;
         relativeX = centerX / imageWidth;
      }
      
      String position = "center";
      
      if (relativeX < 0.35) position = "left"; 
      else if (relativeX > 0.65) position = "right";

      bool isClose = relativeW > 0.4;
      
      if (relativeW > 0.6) {
        dangerousProximity = true;
      }
      
      results.add(DetectionResult(
        label: label,
        confidence: confidence,
        position: position,
        isClose: isClose,
        relativeWidth: relativeW,
      ));
    }

    _triggerProximityAlert(dangerousProximity);

    _currentDetections = results;
    _handleResultDistribution(results, counts);
  }

  String _normalizeLabel(String rawLabel) {
    String lower = rawLabel.toLowerCase();
    if (lower.contains('chair')) return 'chair';
    if (lower.contains('table')) return 'table';
    if (lower.contains('person')) return 'person';
    if (lower.contains('monitor') || lower.contains('screen')) return 'screen';
    if (lower.contains('bottle')) return 'bottle';
    if (lower.contains('door')) return 'door';
    return rawLabel; 
  }

  void _handleResultDistribution(List<DetectionResult> detections, Map<String, int> counts) {
    String description = _buildAggregatedDescription(detections, counts);
    
    if (description == "Path clear" && _lastAnnouncedDescription == "Path clear") {
      return; 
    }
    
    _lastAnnouncedDescription = description;
    onObstacleDetected?.call(detections, description);
  }

  String _buildAggregatedDescription(List<DetectionResult> detections, Map<String, int> counts) {
    var relevantDetections = detections.where((d) => d.relativeWidth > 0.2).toList();
    bool centerBlocked = relevantDetections.any((d) => d.position == "center");

    if (!centerBlocked) {
       return "Path clear";
    }

    if (relevantDetections.isEmpty) return "Path clear";

    List<String> warnings = [];
    for (var d in relevantDetections) {
      if (d.isClose && d.position == "center") {
        warnings.add("Watch out, ${d.label} directly ahead");
      }
    }
    
    if (warnings.isNotEmpty) {
      return warnings.first; 
    }

    List<String> summaryParts = [];
    Map<String, int> detailedCounts = {};
    for (var d in relevantDetections) {
      String key = "${d.label} on your ${d.position}";
      detailedCounts[key] = (detailedCounts[key] ?? 0) + 1;
    }

    detailedCounts.forEach((key, count) {
      int splitIndex = key.indexOf(" on your ");
      if (splitIndex != -1) {
         String label = key.substring(0, splitIndex);
         String positionPhrase = key.substring(splitIndex); 

         if (count == 1) {
           summaryParts.add("a $label$positionPhrase");
         } else {
           summaryParts.add("$count ${label}s$positionPhrase");
         }
      }
    });

    if (summaryParts.isEmpty) return "Path clear";

    String summary = "I see " + summaryParts.join(", ");
    return summary;
  }

  Future<void> stopDetection() async {
    _isDetectionActive = false;
    if (_cameraController != null && _cameraController!.value.isStreamingImages) {
      await _cameraController!.stopImageStream();
    }
  }

  Future<void> dispose() async {
    await stopDetection();
    await _cameraController?.dispose();
    _cameraController = null;
    _objectDetector = null;
    _isInitialized = false;
  }
}

// --- Background Isolate Constants/Functions ---

class PlaneRaw {
  final Uint8List bytes;
  final int bytesPerRow;
  final int? bytesPerPixel;
  
  PlaneRaw({required this.bytes, required this.bytesPerRow, this.bytesPerPixel});
}

class CameraImageRaw {
  final int width;
  final int height;
  final List<PlaneRaw> planes;
  final ImageFormatGroup format;
  
  CameraImageRaw({
    required this.width, 
    required this.height, 
    required this.planes, 
    required this.format
  });
}

/// Run in background isolate
Future<Uint8List?> _encodeImage(CameraImageRaw image) async {
  try {
     // Currently we support YUV420 to JPEG.
     // Android defaults to YUV420. iOS BGRA8888 or YUV420.
     // We assume YUV420 here as it's the most common stream format.
     
     if (image.format == ImageFormatGroup.yuv420 && image.planes.length >= 3) {
       return _yuv420ToJpeg(image);
     } else if (image.format == ImageFormatGroup.bgra8888) {
       return _bgra8888ToJpeg(image);
     }
     
     return null;
  } catch (e) {
    debugPrint("Image conversion error: $e");
    return null;
  }
}

Uint8List _yuv420ToJpeg(CameraImageRaw image) {
  final int width = image.width;
  final int height = image.height;
  
  // Create an image buffer
  // Note: processing full resolution 720p/1080p in Dart is slow.
  // We can downsample here if needed.
  
  final img.Image converted = img.Image(width: width, height: height);

  final int yRowStride = image.planes[0].bytesPerRow;
  // Unused UV strides removed for grayscale-only optimization
  // final int uRowStride = image.planes[1].bytesPerRow;
  // final int vRowStride = image.planes[2].bytesPerRow;
  // final int uPixelStride = image.planes[1].bytesPerPixel ?? 1;
  // final int vPixelStride = image.planes[2].bytesPerPixel ?? 1;

  final Uint8List yBytes = image.planes[0].bytes;

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int yIndex = y * yRowStride + x;
      
      // Simplest YUV conversion (Grayscale)
      int yVal = yBytes[yIndex];
      converted.setPixelRgb(x, y, yVal, yVal, yVal);
    }
  }

  return img.encodeJpg(converted);
}

Uint8List _bgra8888ToJpeg(CameraImageRaw image) {
  // iOS typically
  final int width = image.width;
  final int height = image.height;
  final Uint8List bytes = image.planes[0].bytes;
  
  // img.Image.fromBytes expects RGBA usually. BGRA needs swapping.
  // We can manually swap or just let 'image' package handle it?
  // image v4 supports formats.
  
  return img.encodeJpg(img.Image.fromBytes(
    width: width, 
    height: height, 
    bytes: bytes.buffer,
    order: img.ChannelOrder.bgra
  ));
}
