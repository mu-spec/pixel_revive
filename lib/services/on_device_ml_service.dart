import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';

class FaceRegion {
  final Rect boundingBox;
  final Rect leftEye;
  final Rect rightEye;
  final Rect mouth;

  const FaceRegion({
    required this.boundingBox,
    required this.leftEye,
    required this.rightEye,
    required this.mouth,
  });

  factory FaceRegion.fromFace(Face face) {
    final box = face.boundingBox;

    Rect getLandmarkOrFallback(FaceLandmarkType type, double fx, double fy, double wRatio, double hRatio) {
      final landmark = face.landmarks[type];
      final w = box.width * wRatio;
      final h = box.height * hRatio;
      if (landmark != null && landmark.position != null) {
        final pos = landmark.position!;
        return Rect.fromCenter(
          center: Offset(pos.x.toDouble(), pos.y.toDouble()),
          width: w,
          height: h,
        );
      }
      return Rect.fromCenter(
        center: Offset(box.left + box.width * fx, box.top + box.height * fy),
        width: w,
        height: h,
      );
    }

    return FaceRegion(
      boundingBox: box,
      leftEye: getLandmarkOrFallback(FaceLandmarkType.leftEye, 0.30, 0.38, 0.28, 0.18),
      rightEye: getLandmarkOrFallback(FaceLandmarkType.rightEye, 0.70, 0.38, 0.28, 0.18),
      mouth: getLandmarkOrFallback(FaceLandmarkType.bottomMouth, 0.50, 0.75, 0.40, 0.20),
    );
  }
}

class OnDeviceMlService {
  static FaceDetector? _faceDetector;
  
  /// Cache for face detection results to avoid repeated processing
  static final Map<String, List<FaceRegion>> _regionCache = {};
  static const int _maxCacheSize = 10;
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static final Map<String, DateTime> _cacheTimestamps = {};

  /// Initializes the Google ML Kit Face Detector with Landmark support
  static void initialize() {
    if (_faceDetector != null) return;
    
    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableContours: false,
      enableClassification: false,
      enableLandmarks: true, // Upgraded to true for eyes/lips separation
    );
    _faceDetector = FaceDetector(options: options);
    debugPrint("🧠 On-Device ML Kit Face Detector initialized with Landmarks (fully offline!)");
  }

  /// Generates a unique cache key from image bytes (first 1KB hash)
  static String _generateCacheKey(Uint8List imageBytes) {
    final keyBytes = imageBytes.length > 1024 
        ? imageBytes.sublist(0, 1024) 
        : imageBytes;
    int hash = imageBytes.length;
    for (int i = 0; i < keyBytes.length; i += 16) {
      hash = (hash * 31 + keyBytes[i]) & 0x7FFFFFFF;
    }
    return 'face_cache_$hash';
  }

  /// Clears expired entries from cache
  static void _cleanupExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = _cacheTimestamps.entries
        .where((e) => now.difference(e.value) > _cacheExpiry)
        .map((e) => e.key)
        .toList();
    
    for (final key in expiredKeys) {
      _regionCache.remove(key);
      _cacheTimestamps.remove(key);
    }
    
    while (_regionCache.length > _maxCacheSize) {
      final oldestKey = _cacheTimestamps.keys.first;
      _regionCache.remove(oldestKey);
      _cacheTimestamps.remove(oldestKey);
    }
  }

  /// Processes the image bytes completely offline to detect face regions and facial landmarks
  static Future<List<FaceRegion>> detectFaceRegions(Uint8List imageBytes, {bool forceRefresh = false}) async {
    initialize();
    
    final cacheKey = _generateCacheKey(imageBytes);
    
    if (!forceRefresh && _regionCache.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheExpiry) {
        debugPrint("🧠 Face Detection: Using cached regions (${_regionCache[cacheKey]!.length} faces)");
        return _regionCache[cacheKey]!;
      }
    }
    
    _cleanupExpiredCache();
    
    try {
      final cacheDir = await _getMlCacheDirectory();
      final tempFile = File('${cacheDir.path}/ml_face_${DateTime.now().millisecondsSinceEpoch}.jpg');
      
      await tempFile.writeAsBytes(imageBytes, flush: true);

      final inputImage = InputImage.fromFilePath(tempFile.path);
      
      final List<Face> faces = await _faceDetector!.processImage(inputImage);

      try {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (e) {
        debugPrint("⚠️ Failed to cleanup temp file: $e");
      }

      final List<FaceRegion> regions = faces.map((face) => FaceRegion.fromFace(face)).toList();

      _regionCache[cacheKey] = regions;
      _cacheTimestamps[cacheKey] = DateTime.now();

      debugPrint("🧠 Face Detection: Detected ${faces.length} face region(s) with landmarks");
      return regions;
    } catch (e) {
      debugPrint("⚠️ Face Detection failed: $e");
      return [];
    }
  }

  /// Backward compatible helper returning just bounding boxes
  static Future<List<Rect>> detectFaces(Uint8List imageBytes, {bool forceRefresh = false}) async {
    final regions = await detectFaceRegions(imageBytes, forceRefresh: forceRefresh);
    return regions.map((r) => r.boundingBox).toList();
  }

  static Future<Directory> _getMlCacheDirectory() async {
    final appDir = await getApplicationSupportDirectory();
    final mlDir = Directory('${appDir.path}/ml_cache');
    if (!await mlDir.exists()) {
      await mlDir.create(recursive: true);
    }
    return mlDir;
  }

  static Future<void> preWarm() async {
    if (_faceDetector != null) return;
    
    initialize();
    debugPrint("🧠 Face Detector pre-warmed and ready");
  }

  static void clearCache() {
    _regionCache.clear();
    _cacheTimestamps.clear();
    debugPrint("🧠 Face detection cache cleared");
  }

  static void dispose() {
    _faceDetector?.close();
    _faceDetector = null;
    clearCache();
  }
}

void debugPrint(String message) {
  assert(() {
    // ignore: avoid_print
    print(message);
    return true;
  }());
}