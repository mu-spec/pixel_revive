import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixel_revive/services/image_processor.dart';
import 'package:pixel_revive/services/storage_service.dart';
import 'package:pixel_revive/services/ai_api_service.dart';
import 'package:pixel_revive/services/cloud_api_config.dart';
import 'package:pixel_revive/services/gpu_shader_service.dart';
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
  int cloudAiUsedToday = 0;

  // Sliders for dynamic fine-tuning
  double enhanceStrength = 0.8;
  double skinSmoothness = 0.5;
  double bokehBlur = 0.6;

  // Cloud AI configs — now driven by CloudApiConfig
  bool useCloudAi = false;
  // Developer override token (for testing only — hidden behind 5 taps)
  String devOverrideToken = '';

  // Language settings
  String languageCode = 'en';

  // Creations History List (Saves paths of enhanced images)
  List<String> creationHistory = [];

  static const int _dailyFreeExports = 3;

  AppProvider() {
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    isPremium = prefs.getBool('is_premium') ?? false;
    freeExportsToday = prefs.getInt('free_exports_today') ?? 0;
    lastExportDate = prefs.getString('last_export_date');
    useCloudAi = prefs.getBool('use_cloud_ai') ?? false;
    devOverrideToken = prefs.getString('dev_override_token') ?? '';
    cloudAiUsedToday = prefs.getInt('cloud_ai_used_today') ?? 0;
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
    await prefs.setString('dev_override_token', devOverrideToken);
    await prefs.setInt('cloud_ai_used_today', cloudAiUsedToday);
    await prefs.setString('language_code', languageCode);
    await prefs.setStringList('creation_history', creationHistory);
  }

  void _resetDailyIfNeeded() {
    final today = _todayString();
    if (lastExportDate != today) {
      freeExportsToday = 0;
      cloudAiUsedToday = 0;
      lastExportDate = today;
    }
  }

  String _todayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Returns the API token to use:
  /// 1. Developer override token (if set via hidden settings)
  /// 2. Embedded token from CloudApiConfig
  String get _activeApiToken {
    if (devOverrideToken.isNotEmpty) return devOverrideToken;
    return CloudApiConfig.activeToken;
  }

  /// Whether Cloud AI is available (has a valid token)
  bool get isCloudAiAvailable {
    return _activeApiToken.isNotEmpty;
  }

  /// Can this user use Cloud AI right now?
  /// Premium = unlimited. Free = limited daily quota.
  bool get canUseCloudAi {
    if (!isCloudAiAvailable) return false;
    if (!useCloudAi) return false;
    if (isPremium) return true;
    // Free user: check daily limit
    return cloudAiUsedToday < CloudApiConfig.freeDailyCloudLimit;
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

  void setDisplayBytes(Uint8List bytes) {
    displayBytes = bytes;
    notifyListeners();
  }

  void setUseCloudAi(bool value) {
    useCloudAi = value;
    _savePrefs();
    notifyListeners();
  }

  void setDevOverrideToken(String value) {
    devOverrideToken = value;
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
      creationHistory.insert(0, filePath);
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

      GpuShaderService.initialize();
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

    // 1. Try Cloud AI if configured, enabled, and user has quota
    if (useCloudAi && canUseCloudAi) {
      try {
        final cloudResult = await AiApiService.smartEnhance(
          imageBytes: originalBytes!,
          featureId: featureId,
          apiToken: _activeApiToken,
          isReplicate: CloudApiConfig.useReplicate,
        );

        if (cloudResult != null) {
          processedBytes = cloudResult;
          displayBytes = isPremium ? cloudResult : await ImageProcessor.applyWatermark(cloudResult);
          if (!isPremium) {
            cloudAiUsedToday++;
          }
          _resetDailyIfNeeded();
          await _savePrefs();
          isProcessing = false;
          notifyListeners();
          return; // SUCCESS
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
        case 'bg_cleanup':
          result = await ImageProcessor.backgroundCleanup(originalBytes!);
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
        await addToHistory(path);
        if (!isPremium) {
          freeExportsToday++;
          await _savePrefs();
        }
        notifyListeners();
        return path;
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
  }

  // =========================================================================
  // BATCH PROCESSING ENGINE
  // =========================================================================
  List<File> batchImages = [];
  List<Uint8List> batchOriginalBytes = [];
  List<Uint8List> batchProcessedBytes = [];
  bool isBatchProcessing = false;
  int batchCurrentIndex = 0;
  String? batchStatusMessage;

  void clearBatch() {
    batchImages.clear();
    batchOriginalBytes.clear();
    batchProcessedBytes.clear();
    notifyListeners();
  }

  Future<void> pickBatchImages() async {
    try {
      final List<XFile> pickedList = await _picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 90,
      );
      if (pickedList.isEmpty) return;

      batchImages = pickedList.map((x) => File(x.path)).toList();
      batchOriginalBytes.clear();
      batchProcessedBytes.clear();

      for (var file in batchImages) {
        final bytes = await file.readAsBytes();
        batchOriginalBytes.add(bytes);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('pickBatchImages error: $e');
    }
  }

  Future<void> processBatch(String featureId) async {
    if (batchOriginalBytes.isEmpty) return;

    isBatchProcessing = true;
    batchCurrentIndex = 0;
    batchProcessedBytes.clear();
    batchStatusMessage = "Starting batch queue...";
    notifyListeners();

    try {
      for (int i = 0; i < batchOriginalBytes.length; i++) {
        batchCurrentIndex = i;
        batchStatusMessage = "Processing image ${i + 1} of ${batchOriginalBytes.length}...";
        notifyListeners();

        final Uint8List input = batchOriginalBytes[i];
        Uint8List result;

        // Try Cloud AI for batch (Premium only, to save your costs)
        if (useCloudAi && isPremium && _activeApiToken.isNotEmpty) {
          Uint8List? cloudResult = await AiApiService.smartEnhance(
            imageBytes: input,
            featureId: featureId,
            apiToken: _activeApiToken,
            isReplicate: CloudApiConfig.useReplicate,
          );
          result = cloudResult ?? await _processLocalFeatureSync(input, featureId);
        } else {
          result = await _processLocalFeatureSync(input, featureId);
        }

        final Uint8List finalBytes = isPremium ? result : await ImageProcessor.applyWatermark(result);
        batchProcessedBytes.add(finalBytes);
      }

      batchStatusMessage = "Batch processing complete! 🎉";
    } catch (e) {
      batchStatusMessage = "Batch process failed: $e";
      debugPrint("processBatch error: $e");
    } finally {
      isBatchProcessing = false;
      notifyListeners();
    }
  }

  Future<Uint8List> _processLocalFeatureSync(Uint8List input, String featureId) async {
    switch (featureId) {
      case 'auto':
        return await ImageProcessor.autoEnhance(input, strength: enhanceStrength);
      case 'upscale':
        return await ImageProcessor.upscale(input, scale: 2);
      case 'face':
        return await ImageProcessor.faceEnhance(input, smoothness: skinSmoothness, strength: enhanceStrength);
      case 'denoise':
        return await ImageProcessor.denoise(input);
      case 'unblur':
        return await ImageProcessor.unblur(input);
      case 'colorize':
        return await ImageProcessor.colorize(input);
      case 'restore':
        return await ImageProcessor.restoreOldPhoto(input);
      case 'cartoon':
        return await ImageProcessor.cartoonEffect(input);
      case 'bg':
        return await ImageProcessor.backgroundBlur(input, radius: bokehBlur);
      case 'bg_cleanup':
        return await ImageProcessor.backgroundCleanup(input);
      default:
        return await ImageProcessor.autoEnhance(input, strength: enhanceStrength);
    }
  }

  Future<bool> saveBatchToGallery() async {
    if (batchProcessedBytes.isEmpty) return false;
    try {
      for (var bytes in batchProcessedBytes) {
        final path = await StorageService.saveToGallery(bytes);
        if (path != null) {
          await addToHistory(path);
        }
      }
      return true;
    } catch (e) {
      debugPrint("saveBatchToGallery error: $e");
      return false;
    }
  }
}