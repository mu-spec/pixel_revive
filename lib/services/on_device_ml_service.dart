import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:path_provider/path_provider.dart';

class OnDeviceMlService {
  static FaceDetector? _faceDetector;
  
  /// Cache for face detection results to avoid repeated processing
  static final Map<String, List<Rect>> _faceCache = {};
  static const int _maxCacheSize = 10;
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static final Map<String, DateTime> _cacheTimestamps = {};

  /// Initializes the Google ML Kit Face Detector
  static void initialize() {
    if (_faceDetector != null) return;
    
    final options = FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableContours: false,
      enableClassification: false,
      enableLandmarks: false,
    );
    _faceDetector = FaceDetector(options: options);
    debugPrint("🧠 On-Device ML Kit Face Detector initialized (fully offline!)");
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
      _faceCache.remove(key);
      _cacheTimestamps.remove(key);
    }
    
    while (_faceCache.length > _maxCacheSize) {
      final oldestKey = _cacheTimestamps.keys.first;
      _faceCache.remove(oldestKey);
      _cacheTimestamps.remove(oldestKey);
    }
  }

  /// Processes the image bytes completely offline to detect faces
  /// Uses caching to avoid repeated detection on the same image
  static Future<List<Rect>> detectFaces(Uint8List imageBytes, {bool forceRefresh = false}) async {
    initialize();
    
    final cacheKey = _generateCacheKey(imageBytes);
    
    if (!forceRefresh && _faceCache.containsKey(cacheKey)) {
      final timestamp = _cacheTimestamps[cacheKey];
      if (timestamp != null && DateTime.now().difference(timestamp) < _cacheExpiry) {
        debugPrint("🧠 Face Detection: Using cached result (${_faceCache[cacheKey]!.length} faces)");
        return _faceCache[cacheKey]!;
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

      final List<Rect> boundingBoxes = faces.map((face) => face.boundingBox).toList();

      _faceCache[cacheKey] = boundingBoxes;
      _cacheTimestamps[cacheKey] = DateTime.now();

      debugPrint("🧠 Face Detection: Detected ${faces.length} face(s) (cached)");
      return boundingBoxes;
    } catch (e) {
      debugPrint("⚠️ Face Detection failed: $e");
      return [];
    }
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
    _faceCache.clear();
    _cacheTimestamps.clear();
    debugPrint("🧠 Face detection cache cleared");
  }

  static void dispose() {
    _faceDetector?.close();
    _faceDetector = null;
    clearCache();
  }
}