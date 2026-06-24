import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

class GpuShaderService {
  static ui.FragmentProgram? _program;
  static bool _isLoading = false;
  static bool _initFailed = false;
  static String? _lastError;
  
  static int _compilationAttempts = 0;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 500);

  static bool get isAvailable => _program != null && !_initFailed;
  
  static String? get lastError => _lastError;
  
  static bool get isLoading => _isLoading;

  static Future<bool> initialize() async {
    if (_program != null) return true;
    if (_initFailed && _compilationAttempts >= _maxRetries) return false;
    if (_isLoading) {
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 50));
      }
      return _program != null;
    }
    
    _isLoading = true;
    
    for (int attempt = _compilationAttempts; attempt < _maxRetries; attempt++) {
      _compilationAttempts = attempt + 1;
      
      try {
        debugPrint("🎨 Loading GLSL GPU Shader (attempt ${attempt + 1}/$_maxRetries)...");
        _program = await ui.FragmentProgram.fromAsset('assets/shaders/filter.frag');
        _initFailed = false;
        _lastError = null;
        debugPrint("✅ GLSL GPU Shader loaded and compiled successfully!");
        _isLoading = false;
        return true;
      } catch (e) {
        _lastError = e.toString();
        debugPrint("⚠️ Shader compilation attempt ${attempt + 1} failed: $e");
        
        if (attempt < _maxRetries - 1) {
          await Future.delayed(_retryDelay * (attempt + 1));
        }
      }
    }
    
    _initFailed = true;
    _isLoading = false;
    debugPrint("❌ GPU Shader initialization failed after $_maxRetries attempts: $_lastError");
    return false;
  }

  static void reset() {
    _program = null;
    _initFailed = false;
    _lastError = null;
    _compilationAttempts = 0;
    _isLoading = false;
  }

  static Future<ui.Image> _bytesToUiImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  static Future<Uint8List?> processOnGpu({
    required Uint8List inputBytes,
    required double brightness,
    required double contrast,
    required double saturation,
    required double sharpen,
  }) async {
    if (_program == null) {
      final success = await initialize();
      if (!success) {
        debugPrint("⚠️ GPU Shader unavailable, caller should use CPU fallback");
        return null;
      }
    }

    try {
      final textureImage = await _bytesToUiImage(inputBytes);
      final double width = textureImage.width.toDouble();
      final double height = textureImage.height.toDouble();

      final ui.FragmentShader shader = _program!.fragmentShader();

      shader.setFloat(0, width);
      shader.setFloat(1, height);
      shader.setFloat(2, brightness);
      shader.setFloat(3, contrast);
      shader.setFloat(4, saturation);
      shader.setFloat(5, sharpen);
      shader.setImageSampler(0, textureImage);

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(
        recorder, 
        Rect.fromLTWH(0, 0, width, height)
      );
      
      final Paint shaderPaint = Paint()..shader = shader;
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), shaderPaint);

      final ui.Picture picture = recorder.endRecording();
      final ui.Image processedImage = await picture.toImage(
        width.toInt(), 
        height.toInt()
      );

      final ByteData? byteData = await processedImage.toByteData(
        format: ui.ImageByteFormat.png
      );

      textureImage.dispose();
      processedImage.dispose();
      picture.dispose();

      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
      
      debugPrint("⚠️ GPU processing: byte conversion failed");
      return null;
    } catch (e) {
      debugPrint("⚠️ GPU Shader processing error: $e");
      return null;
    }
  }

  static Future<Uint8List?> processPreviewFast({
    required Uint8List inputBytes,
    required double contrast,
    required double saturation,
    required double sharpen,
  }) async {
    if (!isAvailable) return null;
    
    try {
      return await processOnGpu(
        inputBytes: inputBytes,
        brightness: 0.0,
        contrast: contrast,
        saturation: saturation,
        sharpen: sharpen,
      );
    } catch (e) {
      debugPrint("⚠️ Fast preview failed: $e");
      return null;
    }
  }
}

void debugPrint(String message) {
  assert(() {
    // ignore: avoid_print
    print(message);
    return true;
  }());
}