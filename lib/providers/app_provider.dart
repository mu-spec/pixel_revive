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
import 'package:pixel_revive/services/iap_service.dart';

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

  double enhanceStrength = 0.8;
  double skinSmoothness = 0.5;
  double bokehBlur = 0.6;
  int upscaleScale = 2;

  bool lastProcessingUsedCloud = false;
  String lastProcessingSource = 'Local';
  String lastProcessingMessage = 'Ready for on-device enhancement';

  bool useCloudAi = false;
  String devOverrideToken = '';

  String languageCode = 'en';

  List<String> creationHistory = [];

  Uint8List? _lastProcessedBytes;
  String? _lastFeatureId;
  bool _mlServicePreWarmed = false;

  static const int _dailyFreeExports = 3;

  // Features that have a real Replicate cloud model. Others (cartoon, bokeh)
  // are local-only and must NOT be sent to cloud (they'd get the wrong model).
  static const Set<String> _cloudCapableFeatures = {
    'auto',
    'face',
    'restore',
    'upscale',
    'colorize',
    'bg_cleanup',
    'denoise',
    'unblur',
  };

  static bool _isCloudCapableFeature(String featureId) =>
      _cloudCapableFeatures.contains(featureId);

  AppProvider() {
    _loadPrefs();
    _initIap();
    // Do not run heavy ML/GPU initialization immediately on app open.
    // Delaying it makes splash/main UI much faster on low-memory phones.
    Future.delayed(const Duration(seconds: 3), _preWarmServices);
  }

  Future<void> _initIap() async {
    await IapService.instance.init(onEntitlementChanged: _applyIapEntitlement);
  }

  /// Called by the IAP service when a verified purchase/restore grants or
  /// revokes Premium. Uses the same canonical setter as everything else.
  void _applyIapEntitlement(bool isPremiumEntitled) {
    if (isPremium != isPremiumEntitled) {
      setPremium(isPremiumEntitled);
    }
  }

  Future<void> _preWarmServices() async {
    if (_mlServicePreWarmed) return;
    _mlServicePreWarmed = true;
    
    Future.wait<bool>([
      GpuShaderService.initialize(),
      OnDeviceMlService.preWarm().then((_) => true),
    ]).then((results) {
      debugPrint("🚀 Services pre-warmed: GPU=${results[0]}, ML=${results[1]}");
    }).catchError((error) {
      debugPrint("⚠️ Service pre-warm failed: $error");
    });
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    isPremium = prefs.getBool('is_premium') ?? false;
    freeExportsToday = prefs.getInt('free_exports_today') ?? 0;
    lastExportDate = prefs.getString('last_export_date');
    useCloudAi = prefs.getBool('use_cloud_ai') ?? CloudApiConfig.useBackendProxy;
    devOverrideToken = prefs.getString('dev_override_token') ?? '';
    cloudAiUsedToday = prefs.getInt('cloud_ai_used_today') ?? 0;
    upscaleScale = (prefs.getInt('upscale_scale') ?? 2).clamp(2, 4).toInt();
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
    await prefs.setInt('upscale_scale', upscaleScale);
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

  String get _activeApiToken {
    if (devOverrideToken.isNotEmpty) return devOverrideToken;
    return CloudApiConfig.activeToken;
  }

  bool get isCloudAiAvailable => CloudApiConfig.isCloudAvailable || devOverrideToken.isNotEmpty;

  bool get canUseCloudAi {
    if (!isCloudAiAvailable) return false;
    if (!useCloudAi) return false;
    if (isPremium) return true;
    if (CloudApiConfig.cloudAiPremiumOnly) return false;
    return cloudAiUsedToday < CloudApiConfig.freeDailyCloudLimit;
  }

  String get cloudProviderLabel => CloudApiConfig.activeProviderLabel;

  String get processingRouteLabel {
    if (isProcessing) return 'Processing...';
    if (processedBytes == null) {
      return CloudApiConfig.isCloudAvailable
          ? 'Cloud ready • ${CloudApiConfig.activeProviderLabel}'
          : 'Local ready';
    }
    return lastProcessingUsedCloud
        ? 'Cloud AI • ${CloudApiConfig.activeProviderLabel}'
        : lastProcessingSource;
  }

  IconData get processingRouteIcon {
    if (lastProcessingUsedCloud || (processedBytes == null && CloudApiConfig.isCloudAvailable)) {
      return Icons.cloud_done_rounded;
    }
    return Icons.phone_android_rounded;
  }

  Color get processingRouteColor {
    if (lastProcessingUsedCloud || (processedBytes == null && CloudApiConfig.isCloudAvailable)) {
      return Colors.lightBlueAccent;
    }
    if (lastProcessingSource == 'Local Fallback') return Colors.orangeAccent;
    if (lastProcessingSource == 'Daily AI limit reached') return Colors.orangeAccent;
    return Colors.greenAccent;
  }

  bool get _canUseCache => _lastProcessedBytes != null && _lastFeatureId != null && originalBytes != null;

  void _clearProcessingCache() {
    _lastProcessedBytes = null;
    _lastFeatureId = null;
  }

  void setEnhanceStrength(double value) {
    enhanceStrength = value;
    _clearProcessingCache();
    notifyListeners();
  }

  void setSkinSmoothness(double value) {
    skinSmoothness = value;
    _clearProcessingCache();
    notifyListeners();
  }

  void setBokehBlur(double value) {
    bokehBlur = value;
    _clearProcessingCache();
    notifyListeners();
  }

  void setUpscaleScale(int value) {
    upscaleScale = value.clamp(2, 4).toInt();
    _lastProcessedBytes = null;
    if (_lastFeatureId == 'upscale') {
      _lastFeatureId = null;
    }
    _savePrefs();
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
        debugPrint('Error deleting file: $e');
      }
      await _savePrefs();
      notifyListeners();
    }
  }

  Future<void> pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        // Smaller import = faster preview, faster offline processing, faster cloud upload.
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (picked == null) return;

      originalImage = File(picked.path);
      originalBytes = await originalImage!.readAsBytes();
      
      _lastProcessedBytes = null;
      _lastFeatureId = null;
      processedBytes = null;
      displayBytes = null;
      lastProcessingUsedCloud = false;
      lastProcessingSource = 'Local';
      lastProcessingMessage = 'Ready for enhancement';
      
      notifyListeners();

      // Keep photo selection instant. Heavy ML/GPU work is lazy-loaded only
      // when a feature needs it, instead of blocking the first tap experience.
    } catch (e) {
      debugPrint('pickImage error: $e');
    }
  }

  Future<void> clearImage() async {
    originalImage = null;
    originalBytes = null;
    processedBytes = null;
    displayBytes = null;
    _lastProcessedBytes = null;
    _lastFeatureId = null;
    lastProcessingUsedCloud = false;
    lastProcessingSource = 'Local';
    lastProcessingMessage = 'Ready for on-device enhancement';
    notifyListeners();
  }

  Future<void> processFeature(String featureId) async {
    if (originalBytes == null) return;

    isProcessing = true;
    notifyListeners();

    if (_canUseCache && _lastFeatureId == featureId) {
      processedBytes = _lastProcessedBytes;
      displayBytes = isPremium ? processedBytes : await ImageProcessor.applyWatermark(processedBytes!);
      isProcessing = false;
      notifyListeners();
      return;
    }

    bool cloudAttempted = false;
    bool freeCloudLimitReached = false;

    // OPTION B: detect when a free user has hit their daily cloud AI limit so
    // we can tell them clearly why they got a local result instead of cloud AI.
    if (!isPremium &&
        CloudApiConfig.isCloudAvailable &&
        !CloudApiConfig.cloudAiPremiumOnly &&
        useCloudAi &&
        _isCloudCapableFeature(featureId) &&
        cloudAiUsedToday >= CloudApiConfig.freeDailyCloudLimit) {
      freeCloudLimitReached = true;
    }

    if (useCloudAi && canUseCloudAi && _isCloudCapableFeature(featureId)) {
      cloudAttempted = true;
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
          
          _lastProcessedBytes = cloudResult;
          _lastFeatureId = featureId;
          lastProcessingUsedCloud = true;
          lastProcessingSource = 'Cloud AI';
          lastProcessingMessage = 'Processed securely with ${CloudApiConfig.activeProviderLabel} via Vercel backend.';
          
          if (!isPremium) cloudAiUsedToday++;
          _resetDailyIfNeeded();
          await _savePrefs();
          isProcessing = false;
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint("Cloud AI failed, using local: $e");
      }
    }

    try {
      Uint8List result;
      final stopwatch = Stopwatch()..start();

      switch (featureId) {
        case 'auto':
          result = await ImageProcessor.autoEnhance(originalBytes!, strength: enhanceStrength);
          break;
        case 'upscale':
          result = await ImageProcessor.upscale(originalBytes!, scale: upscaleScale);
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

      stopwatch.stop();
      debugPrint("⚡ Local processing completed in ${stopwatch.elapsedMilliseconds}ms");

      processedBytes = result;
      displayBytes = isPremium ? result : await ImageProcessor.applyWatermark(result);

      _lastProcessedBytes = result;
      _lastFeatureId = featureId;
      lastProcessingUsedCloud = false;
      lastProcessingSource = freeCloudLimitReached
          ? 'Daily AI limit reached'
          : (cloudAttempted ? 'Local Fallback' : 'Local');
      final cloudError = AiApiService.lastErrorMessage ?? '';
      final bool replicateCreditError = cloudError.contains('Insufficient credit') || cloudError.contains('HTTP 402');

      lastProcessingMessage = freeCloudLimitReached
          ? 'Daily free AI limit (${CloudApiConfig.freeDailyCloudLimit}) reached — used fast on-device processing instead. Upgrade to Premium for unlimited AI.'
          : (cloudAttempted
              ? (replicateCreditError
                  ? 'Cloud AI could not run because Replicate has insufficient credit. Local processing was used.'
                  : 'Cloud AI was unavailable or timed out. Local processing was used.')
              : 'Processed on-device with local image enhancement.');

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
      displayBytes = isPremium ? processedBytes : await ImageProcessor.applyWatermark(processedBytes!);
    }
    notifyListeners();
  }

  Future<void> updateOriginalImage(Uint8List editedBytes) async {
    originalBytes = editedBytes;
    processedBytes = null;
    displayBytes = null;
    _lastProcessedBytes = null;
    _lastFeatureId = null;
    lastProcessingUsedCloud = false;
    lastProcessingSource = 'Local';
    lastProcessingMessage = 'Image edited. Run enhancement again.';

    if (originalImage != null) {
      try {
        await originalImage!.writeAsBytes(editedBytes);
      } catch (e) {
        debugPrint('Error writing edited bytes: $e');
      }
    }
    notifyListeners();
  }

  // BATCH PROCESSING
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
    batchCurrentIndex = 0;
    batchStatusMessage = null;
    notifyListeners();
  }

  Future<void> pickBatchImages() async {
    try {
      final List<XFile> pickedList = await _picker.pickMultiImage(
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 84,
      );
      if (pickedList.isEmpty) return;

      batchImages = pickedList.map((x) => File(x.path)).toList();
      batchOriginalBytes.clear();
      batchProcessedBytes.clear();

      final futures = batchImages.map((file) => file.readAsBytes());
      final results = await Future.wait(futures);
      batchOriginalBytes.addAll(results);

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

        // Batch: only send features that truly have a cloud model to Cloud AI.
        // Local-only tools like Cartoon and Background Blur must stay offline,
        // otherwise the backend would run the wrong AI model.
        if (useCloudAi &&
            isPremium &&
            isCloudAiAvailable &&
            _isCloudCapableFeature(featureId)) {
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

      batchStatusMessage = "Batch complete! ${batchOriginalBytes.length} images processed.";
    } catch (e) {
      batchStatusMessage = "Batch failed: $e";
      debugPrint("processBatch error: $e");
    } finally {
      isBatchProcessing = false;
      notifyListeners();
    }
  }

  Future<Uint8List> _processLocalFeatureSync(Uint8List input, String featureId) async {
    final stopwatch = Stopwatch()..start();
    
    Uint8List result;
    switch (featureId) {
      case 'auto':
        result = await ImageProcessor.autoEnhance(input, strength: enhanceStrength);
        break;
      case 'upscale':
        result = await ImageProcessor.upscale(input, scale: upscaleScale);
        break;
      case 'face':
        result = await ImageProcessor.faceEnhance(input, smoothness: skinSmoothness, strength: enhanceStrength);
        break;
      case 'denoise':
        result = await ImageProcessor.denoise(input);
        break;
      case 'unblur':
        result = await ImageProcessor.unblur(input);
        break;
      case 'colorize':
        result = await ImageProcessor.colorize(input);
        break;
      case 'restore':
        result = await ImageProcessor.restoreOldPhoto(input);
        break;
      case 'cartoon':
        result = await ImageProcessor.cartoonEffect(input);
        break;
      case 'bg':
        result = await ImageProcessor.backgroundBlur(input, radius: bokehBlur);
        break;
      case 'bg_cleanup':
        result = await ImageProcessor.backgroundCleanup(input);
        break;
      default:
        result = await ImageProcessor.autoEnhance(input, strength: enhanceStrength);
    }
    
    stopwatch.stop();
    debugPrint("⚡ Batch image $featureId processed in ${stopwatch.elapsedMilliseconds}ms");
    return result;
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

  @override
  void dispose() {
    OnDeviceMlService.dispose();
    IapService.instance.dispose();
    super.dispose();
  }
}
