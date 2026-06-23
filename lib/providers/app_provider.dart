import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixel_revive/services/image_processor.dart';
import 'package:pixel_revive/services/storage_service.dart';
import 'package:pixel_revive/services/ai_api_service.dart';
import 'package:pixel_revive/services/gpu_shader_service.dart';
import 'package:pixel_revive/services/native_ffi_service.dart';
import 'package:pixel_revive/services/on_device_ml_service.dart';

class AppProvider extends ChangeNotifier {
  final ImagePicker _picker = ImagePicker();

  File? originalImage;
  Uint8List? originalBytes;
  Uint8List? processedBytes;
  Uint8List? displayBytes;

  bool isPremium = false;
  bool isProcessing = false;
  int freeExportsToday = 0;
  String? lastExportDate;

  // Sliders for dynamic fine-tuning
  double enhanceStrength = 0.8;
  double skinSmoothness = 0.5;
  double bokehBlur = 0.6;

  // Cloud AI configs (Switched to Fal.ai!)
  bool useCloudAi = false;
  String falToken = '';

  // Language settings
  String languageCode = 'en';

  // Creations History List (Saves paths of enhanced images)
  List<String> creationHistory = [];

  static const int _dailyFreeExports = 3;

  AppProvider() {
    _loadPrefs();
    GpuShaderService.initialize(); // Compile GLSL shader program into VRAM on app launch
    NativeFfiService.initialize(); // Link C++ FFI library into Dart runtime on launch
    OnDeviceMlService.initialize(); // Initialize local ML Kit Face Detector on app launch
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    isPremium = prefs.getBool('is_premium') ?? false;
    freeExportsToday = prefs.getInt('free_exports_today') ?? 0;
    lastExportDate = prefs.getString('last_export_date');
    useCloudAi = prefs.getBool('use_cloud_ai') ?? false;
    falToken = prefs.getString('fal_token') ?? '';
    languageCode = prefs.getString('language_code') ?? 'en';
    creationHistory = prefs.getStringList('creation_history') ?? [];
    _resetDailyIfNeeded();
    notifyListeners();
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', isPremium);
    await prefs.setInt('free_exports_today', freeExportsToday);
    await prefs.setString('last_export_date', lastExportDate ?? '');
    await prefs.setBool('use_cloud_ai', useCloudAi);
    await prefs.setString('fal_token', falToken);
    await prefs.setString('language_code', languageCode);
    await prefs.setStringList('creation_history', creationHistory);
  }

  void _resetDailyIfNeeded() {
    final today = _todayString();
    if (lastExportDate != today) {
      freeExportsToday = 0;
      lastExportDate = today;
    }
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  void setEnhanceStrength(double value) {
    enhanceStrength = value;
    notifyListeners();
  }

  void setSkinSmoothness(double value) {
    skinSmoothness = value;
    notifyListeners();
  }

  void setBokehBlur(double value) {
    bokehBlur = value;
    notifyListeners();
  }

  void setUseCloudAi(bool value) {
    useCloudAi = value;
    _savePrefs();
    notifyListeners();
  }

  void setFalToken(String value) {
    falToken = value;
    _savePrefs();
    notifyListeners();
  }

  void setLanguageCode(String code) {
    languageCode = code;
    _savePrefs();
    notifyListeners();
  }

  Future<void> addToHistory(String filePath) async {
    if (!creationHistory.contains(filePath)) {
      creationHistory.insert(0, filePath); // Add to beginning of list
      await _savePrefs();
      notifyListeners();
    }
  }

  Future<void> removeFromHistory(String filePath) async {
    if (creationHistory.contains(filePath)) {
      creationHistory.remove(filePath);
      try {
        final file = File(filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error deleting file from disk: $e');
      }
      await _savePrefs();
      notifyListeners();
    }
  }

  void _preWarmAllCloudModels() {
    if (useCloudAi && falToken.isNotEmpty) {
      debugPrint('⚡ Instant background pre-warming triggered!');
      AiApiService.preWarmModel(modelName: 'fal-ai/codeformer', apiToken: falToken);
      AiApiService.preWarmModel(modelName: 'fal-ai/esrgan', apiToken: falToken);
      AiApiService.preWarmModel(modelName: 'fal-ai/image-editing/photo-restoration', apiToken: falToken);
    }
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 90,
      );
      if (picked == null) return;

      originalImage = File(picked.path);
      originalBytes = await originalImage!.readAsBytes();
      processedBytes = null;
      displayBytes = null;
      notifyListeners();

      // PART 2 OPTIMIZATION 1: Pre-warming the exact millisecond the photo is selected!
      _preWarmAllCloudModels();
    } catch (e) {
      debugPrint('pickImage error: $e');
    }
  }

  Future<void> clearImage() async {
    originalImage = null;
    originalBytes = null;
    processedBytes = null;
    displayBytes = null;
    notifyListeners();
  }

  Future<void> processFeature(String featureId) async {
    if (originalBytes == null) return;

    isProcessing = true;
    notifyListeners();

    // 1. Try Cloud AI if configured and enabled (SWITCHED TO HIGH-SPEED FAL.AI!)
    if (useCloudAi && falToken.isNotEmpty) {
      try {
        Uint8List? cloudResult;
        if (featureId == 'face' || featureId == 'restore' || featureId == 'auto') {
          // PART 2 OPTIMIZATION 3: Multi-Stage Cloud Pipeline (Remini Studio Mode)
          // Runs Stage 1 (CodeFormer) + Stage 2 (Real-ESRGAN) + Stage 3 (Local detail-preserving blending filter)
          cloudResult = await AiApiService.runMultiStagePipeline(
            imageBytes: originalBytes!,
            apiToken: falToken,
            blendFactor: 0.25, // Blend 25% of original high-frequency details for natural skin grain
          );
        } else if (featureId == 'upscale') {
          // Runs ultra-fast 2x Real-ESRGAN scaling
          cloudResult = await AiApiService.runFalPrediction(
            imageBytes: originalBytes!,
            modelName: 'fal-ai/esrgan',
            apiToken: falToken,
            additionalInput: {
              'upscaling': 2,
            },
          );
        } else if (featureId == 'colorize') {
          // Runs complete Photo Restoration & Colorization in one unified pass!
          cloudResult = await AiApiService.runFalPrediction(
            imageBytes: originalBytes!,
            modelName: 'fal-ai/image-editing/photo-restoration',
            apiToken: falToken,
          );
        }

        if (cloudResult != null) {
          processedBytes = cloudResult;
          displayBytes = isPremium ? cloudResult : await ImageProcessor.applyWatermark(cloudResult);
          _resetDailyIfNeeded();
          await _savePrefs();
          isProcessing = false;
          notifyListeners();
          return; // SUCCESS - EXIT METHOD EARLY
        }
      } catch (e) {
        debugPrint("Cloud AI failed, falling back to local processing: $e");
      }
    }

    // 2. FALLBACK - Run Local On-Device processing
    try {
      Uint8List result;
      switch (featureId) {
        case 'auto':
          result = await ImageProcessor.autoEnhance(originalBytes!, strength: enhanceStrength);
          break;
        case 'upscale':
          result = await ImageProcessor.upscale(originalBytes!, scale: 2);
          break;
        case 'face':
          result = await ImageProcessor.faceEnhance(originalBytes!, smoothness: skinSmoothness, strength: enhanceStrength);
          break;
        case 'denoise':
          result = await ImageProcessor.denoise(originalBytes!);
          break;
        case 'unblur':
          result = await ImageProcessor.unblur(originalBytes!);
          break;
        case 'colorize':
          result = await ImageProcessor.colorize(originalBytes!);
          break;
        case 'restore':
          result = await ImageProcessor.restoreOldPhoto(originalBytes!);
          break;
        case 'cartoon':
          result = await ImageProcessor.cartoonEffect(originalBytes!);
          break;
        case 'bg':
          result = await ImageProcessor.backgroundBlur(originalBytes!, radius: bokehBlur);
          break;
        default:
          result = await ImageProcessor.autoEnhance(originalBytes!, strength: enhanceStrength);
      }

      processedBytes = result;
      displayBytes = isPremium ? result : await ImageProcessor.applyWatermark(result);
      _resetDailyIfNeeded();
      await _savePrefs();
    } catch (e, st) {
      debugPrint('processFeature error: $e\n$st');
      processedBytes = originalBytes;
      displayBytes = originalBytes;
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }

  Future<bool> canExport() async {
    _resetDailyIfNeeded();
    if (isPremium) return true;
    return freeExportsToday < _dailyFreeExports;
  }

  Future<String?> saveToGallery() async {
    if (displayBytes == null) return 'No image to save';

    final ok = await canExport();
    if (!ok) {
      return 'Daily free limit reached. Upgrade to Premium.';
    }

    try {
      final path = await StorageService.saveToGallery(displayBytes!);
      if (path != null) {
        await addToHistory(path); // Save file path persistently to creationHistory list!
        if (!isPremium) {
          freeExportsToday++;
          await _savePrefs();
        }
        notifyListeners();
        return path; // Return saved file path on success
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<String?> shareImage() async {
    if (displayBytes == null) return 'No image to share';
    try {
      await StorageService.shareImage(displayBytes!);
      return null;
    } catch (e) {
      return 'Share error: $e';
    }
  }

  Future<void> setPremium(bool value) async {
    isPremium = value;
    await _savePrefs();
    if (processedBytes != null) {
      displayBytes = isPremium
          ? processedBytes
          : await ImageProcessor.applyWatermark(processedBytes!);
    }
    notifyListeners();
  }

  Future<void> updateOriginalImage(Uint8List editedBytes) async {
    originalBytes = editedBytes;
    processedBytes = null;
    displayBytes = null;

    if (originalImage != null) {
      try {
        await originalImage!.writeAsBytes(editedBytes);
      } catch (e) {
        debugPrint('Error writing edited bytes: $e');
      }
    }
    notifyListeners();

    // PART 2 OPTIMIZATION 1: Pre-warming the exact millisecond the photo is updated (cropped/rotated)!
    _preWarmAllCloudModels();
  }
}