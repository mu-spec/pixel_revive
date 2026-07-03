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
  // Full/HD original kept for final premium export.
  Uint8List? originalFullBytes;
  // Lightweight preview original used for fast preview processing and UI.
  Uint8List? originalPreviewBytes;
  // Backward-compatible current original used by existing screens (preview-sized).
  Uint8List? originalBytes;

  Uint8List? processedPreviewBytes;
  Uint8List? processedHdBytes;
  Uint8List? localResultBytes;
  Uint8List? cloudResultBytes;
  String resultViewMode = 'auto'; // auto, local, cloud
  Uint8List? processedBytes;
  Uint8List? displayBytes;
  bool hdExportReady = false;
  String? lastProcessedFeatureId;

  bool isPremium = false;
  bool isProcessing = false;
  int freeExportsToday = 0;
  String? lastExportDate;
  int cloudAiUsedToday = 0;

  double enhanceStrength = 0.8;
  double skinSmoothness = 0.5;
  double bokehBlur = 0.6;
  int upscaleScale = 2;
  String enhancementPreset = 'balanced'; // natural, balanced, strong
  String processingQuality = 'fast'; // fast, balanced, hd

  bool lastProcessingUsedCloud = false;
  bool isCloudRefining = false;
  String lastProcessingSource = 'Local';
  String lastProcessingMessage = 'Ready for on-device enhancement';
  String lastProcessingTimingSummary = '';
  Map<String, Object?> lastProcessingTimings = <String, Object?>{};

  bool useCloudAi = false;
  String devOverrideToken = '';

  String languageCode = 'en';

  List<String> creationHistory = [];

  Uint8List? _lastProcessedBytes;
  String? _lastFeatureId;
  final Map<String, Uint8List> _processedCache = <String, Uint8List>{};
  bool _mlServicePreWarmed = false;
  bool _cancelProcessingRequested = false;
  int _processingRunId = 0;

// Line 48:
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

  // Speed policy: in Fast mode, these features stay on-device so users get an
  // immediate result instead of waiting for slower cloud restoration models.
  static const Set<String> _fastModeLocalFeatures = {
    'auto',
    'denoise',
    'unblur',
  };

  bool _shouldUseFastLocal(String featureId) =>
      processingQuality == 'fast' && _fastModeLocalFeatures.contains(featureId);

  bool _shouldAttemptCloudForFeature(String featureId) =>
      useCloudAi &&
      canUseCloudAi &&
      _isCloudCapableFeature(featureId) &&
      !_shouldUseFastLocal(featureId);

  bool _canStartBackgroundCloud(String featureId) =>
      useCloudAi && canUseCloudAi && _isCloudCapableFeature(featureId);

  AppProvider() {
    _loadPrefs();
    _initIap();
    // Heavy ML/GPU services are now lazy-loaded only when a local feature needs them.
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
    upscaleScale = (prefs.getInt('upscale_scale') ?? 2).clamp(2, isPremium ? 4 : 2).toInt();
    enhancementPreset = prefs.getString('enhancement_preset') ?? 'balanced';
    processingQuality = prefs.getString('processing_quality') ?? 'fast';
    if (!isPremium && processingQuality == 'hd') processingQuality = 'fast';
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
    await prefs.setString('enhancement_preset', enhancementPreset);
    await prefs.setString('processing_quality', processingQuality);
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


  bool get canUseHdQuality => isPremium;

  int get cloudUploadMaxDimension {
    if (processingQuality == 'hd' && isPremium) return 1920;
    if (processingQuality == 'balanced') return 1280;
    return 1024;
  }

  int get cloudUploadQuality {
    if (processingQuality == 'hd' && isPremium) return 90;
    if (processingQuality == 'balanced') return 82;
    return 76;
  }

  String get processingQualityLabel {
    switch (processingQuality) {
      case 'hd':
        return 'HD Quality';
      case 'fast':
        return 'Fast';
      default:
        return 'Balanced';
    }
  }

  String get enhancementPresetLabel {
    switch (enhancementPreset) {
      case 'natural':
        return 'Natural';
      case 'strong':
        return 'Strong';
      default:
        return 'Balanced';
    }
  }

  bool get hasLocalAndCloudResults => localResultBytes != null && cloudResultBytes != null;

  Future<void> _refreshDisplayFromProcessed() async {
    final bytes = processedBytes;
    if (bytes == null) {
      displayBytes = null;
      return;
    }
    displayBytes = isPremium ? bytes : await ImageProcessor.applyWatermark(bytes);
  }

  Future<void> setResultViewMode(String mode) async {
    if (mode != 'local' && mode != 'cloud' && mode != 'auto') return;
    resultViewMode = mode;
    if (mode == 'local' && localResultBytes != null) {
      processedBytes = localResultBytes;
      lastProcessingUsedCloud = false;
      lastProcessingSource = 'Fast Preview';
      lastProcessingMessage = 'Showing fast local preview result.';
    } else if (mode == 'cloud' && cloudResultBytes != null) {
      processedBytes = cloudResultBytes;
      lastProcessingUsedCloud = true;
      lastProcessingSource = 'Cloud AI';
      lastProcessingMessage = 'Showing cloud AI result.';
    } else if (mode == 'auto') {
      processedBytes = cloudResultBytes ?? localResultBytes ?? processedPreviewBytes;
      lastProcessingUsedCloud = cloudResultBytes != null;
      lastProcessingSource = cloudResultBytes != null ? 'Cloud AI' : 'Fast Preview';
      lastProcessingMessage = cloudResultBytes != null
          ? 'Cloud AI result applied. You can save or compare now.'
          : 'Showing fast local preview result.';
    }
    await _refreshDisplayFromProcessed();
    notifyListeners();
  }

  String estimatedProcessingTime(String featureId) {
    if (!useCloudAi || !canUseCloudAi || !_isCloudCapableFeature(featureId)) {
      return 'usually 3–20 sec on device';
    }
    switch (featureId) {
      case 'upscale':
        return upscaleScale >= 4 ? 'usually 25–60 sec' : 'usually 12–35 sec';
      case 'restore':
      case 'colorize':
        return 'usually 15–45 sec';
      case 'denoise':
      case 'unblur':
        return 'usually 10–30 sec';
      default:
        return 'usually 5–20 sec';
    }
  }

  String _formatMs(Object? value) {
    final ms = value is int ? value : int.tryParse(value?.toString() ?? '');
    if (ms == null) return '-';
    if (ms < 1000) return '${ms}ms';
    return '${(ms / 1000).toStringAsFixed(1)}s';
  }

  void _rememberTimings(Map<String, Object?> timings) {
    lastProcessingTimings = Map<String, Object?>.from(timings);
    final parts = <String>[];
    if (timings['localMs'] != null) parts.add('local ${_formatMs(timings['localMs'])}');
    if (timings['prepMs'] != null) parts.add('prep ${_formatMs(timings['prepMs'])}');
    if (timings['startMs'] != null) parts.add('start ${_formatMs(timings['startMs'])}');
    if (timings['polls'] != null) parts.add('polls ${timings['polls']}');
    if (timings['downloadMs'] != null) parts.add('download ${_formatMs(timings['downloadMs'])}');
    if (timings['totalMs'] != null) parts.add('total ${_formatMs(timings['totalMs'])}');
    final model = timings['model']?.toString();
    lastProcessingTimingSummary = [
      if (model != null && model.isNotEmpty) 'model $model',
      if (parts.isNotEmpty) parts.join(' • '),
    ].join(' • ');
    debugPrint('⏱ PixelRevive timings: $lastProcessingTimings');
  }

  bool get needsHdExportForSave =>
      isPremium &&
      processedPreviewBytes != null &&
      processedHdBytes == null &&
      !hdExportReady &&
      lastProcessedFeatureId != null &&
      useCloudAi &&
      _isCloudCapableFeature(lastProcessedFeatureId!);

  String get cloudProviderLabel => CloudApiConfig.activeProviderLabel;

  String get processingRouteLabel {
    if (isProcessing) return 'Processing...';
    if (isCloudRefining) return 'Fast Preview • Cloud improving...';
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

  String _cacheKey(String featureId) => [
        featureId,
        _shouldAttemptCloudForFeature(featureId) ? 'cloud' : 'local',
        processingQuality,
        upscaleScale,
        enhanceStrength.toStringAsFixed(2),
        skinSmoothness.toStringAsFixed(2),
        bokehBlur.toStringAsFixed(2),
        originalPreviewBytes?.length ?? originalBytes?.length ?? 0,
        originalFullBytes?.length ?? 0,
      ].join('|');

  void _rememberProcessedResult(String featureId, Uint8List bytes) {
    _lastProcessedBytes = bytes;
    _lastFeatureId = featureId;
    _processedCache[_cacheKey(featureId)] = bytes;
    if (_processedCache.length > 8) {
      _processedCache.remove(_processedCache.keys.first);
    }
  }

  void _clearProcessingCache() {
    _lastProcessedBytes = null;
    _lastFeatureId = null;
    _processedCache.clear();
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
    upscaleScale = value.clamp(2, isPremium ? 4 : 2).toInt();
    _clearProcessingCache();
    _savePrefs();
    notifyListeners();
  }

  void setProcessingQuality(String value) {
    final normalized = value == 'fast' || value == 'hd' ? value : 'balanced';
    processingQuality = (!isPremium && normalized == 'hd') ? 'fast' : normalized;
    _clearProcessingCache();
    _savePrefs();
    notifyListeners();
  }

  void setEnhancementPreset(String value) {
    final normalized = value == 'natural' || value == 'strong' ? value : 'balanced';
    enhancementPreset = normalized;
    switch (normalized) {
      case 'natural':
        enhanceStrength = 0.45;
        skinSmoothness = 0.35;
        break;
      case 'strong':
        enhanceStrength = 0.95;
        skinSmoothness = 0.70;
        break;
      default:
        enhanceStrength = 0.75;
        skinSmoothness = 0.50;
    }
    _clearProcessingCache();
    _savePrefs();
    notifyListeners();
  }

  void cancelProcessing() {
    if (!isProcessing) return;
    _cancelProcessingRequested = true;
    isProcessing = false;
    isCloudRefining = false;
    lastProcessingSource = 'Canceled';
    lastProcessingMessage = 'Processing canceled. The cloud job may finish in the background but its result will be ignored.';
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
        // Keep a larger source for premium HD export, then create a fast preview copy below.
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 95,
      );
      if (picked == null) return;

      final prepSw = Stopwatch()..start();
      originalImage = File(picked.path);
      originalFullBytes = await originalImage!.readAsBytes();
      originalPreviewBytes = await ImageProcessor.preparePreview(
        originalFullBytes!,
        maxDimension: 1024,
        quality: 76,
      );
      prepSw.stop();
      _rememberTimings({
        'stage': 'image_prepare',
        'originalBytes': originalFullBytes!.length,
        'previewBytes': originalPreviewBytes!.length,
        'prepMs': prepSw.elapsedMilliseconds,
      });
      originalBytes = originalPreviewBytes;
      
      _clearProcessingCache();
      processedPreviewBytes = null;
      processedHdBytes = null;
      localResultBytes = null;
      cloudResultBytes = null;
      resultViewMode = 'auto';
      processedBytes = null;
      displayBytes = originalPreviewBytes;
      hdExportReady = false;
      lastProcessedFeatureId = null;
      lastProcessingUsedCloud = false;
      isCloudRefining = false;
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
    originalFullBytes = null;
    originalPreviewBytes = null;
    originalBytes = null;
    processedPreviewBytes = null;
    processedHdBytes = null;
    localResultBytes = null;
    cloudResultBytes = null;
    resultViewMode = 'auto';
    processedBytes = null;
    displayBytes = null;
    hdExportReady = false;
    lastProcessedFeatureId = null;
    _clearProcessingCache();
    lastProcessingUsedCloud = false;
    isCloudRefining = false;
    lastProcessingSource = 'Local';
    lastProcessingMessage = 'Ready for on-device enhancement';
    lastProcessingTimingSummary = '';
    lastProcessingTimings = <String, Object?>{};
    notifyListeners();
  }

  Future<void> processFeature(String featureId) async {
    if (originalPreviewBytes == null && originalBytes == null) return;
    final Uint8List previewInput = originalPreviewBytes ?? originalBytes!;

    _cancelProcessingRequested = false;
    final int runId = ++_processingRunId;
    final bool canStartCloudInBackground = _canStartBackgroundCloud(featureId);
    isProcessing = true;
    lastProcessingUsedCloud = false;
    lastProcessingSource = 'Fast Preview';
    lastProcessingMessage = canStartCloudInBackground
        ? 'Creating fast local preview first. Cloud AI will improve it in the background...'
        : 'Creating fast local preview (${estimatedProcessingTime(featureId)})...';
    notifyListeners();

    final cacheKey = _cacheKey(featureId);
    final cachedResult = _processedCache[cacheKey];
    if (cachedResult != null) {
      processedBytes = cachedResult;
      displayBytes = isPremium ? cachedResult : await ImageProcessor.applyWatermark(cachedResult);
      isProcessing = false;
      lastProcessingMessage = 'Loaded instantly from cache.';
      notifyListeners();
      return;
    }

    if (_canUseCache && _lastFeatureId == featureId) {
      processedBytes = _lastProcessedBytes;
      displayBytes = isPremium ? processedBytes : await ImageProcessor.applyWatermark(processedBytes!);
      isProcessing = false;
      notifyListeners();
      return;
    }

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

    final bool shouldStartBackgroundCloud = canStartCloudInBackground && !freeCloudLimitReached;

    try {
      Uint8List result;
      final stopwatch = Stopwatch()..start();
      if (featureId == 'face' || featureId == 'bg') {
        await _preWarmServices();
      }

      switch (featureId) {
        case 'auto':
          result = await ImageProcessor.autoEnhance(previewInput, strength: enhanceStrength);
          break;
        case 'upscale':
          result = await ImageProcessor.upscale(previewInput, scale: upscaleScale);
          break;
        case 'face':
          result = await ImageProcessor.faceEnhance(previewInput, smoothness: skinSmoothness, strength: enhanceStrength);
          break;
        case 'denoise':
          result = await ImageProcessor.denoise(previewInput);
          break;
        case 'unblur':
          result = await ImageProcessor.unblur(previewInput);
          break;
        case 'colorize':
          result = await ImageProcessor.colorize(previewInput);
          break;
        case 'restore':
          result = await ImageProcessor.restoreOldPhoto(previewInput);
          break;
        case 'cartoon':
          result = await ImageProcessor.cartoonEffect(previewInput);
          break;
        case 'bg':
          result = await ImageProcessor.backgroundBlur(previewInput, radius: bokehBlur);
          break;
        case 'bg_cleanup':
          result = await ImageProcessor.backgroundCleanup(previewInput);
          break;
        default:
          result = await ImageProcessor.autoEnhance(previewInput, strength: enhanceStrength);
      }

      stopwatch.stop();
      _rememberTimings({
        'stage': 'local_preview',
        'feature': featureId,
        'quality': processingQuality,
        'localMs': stopwatch.elapsedMilliseconds,
        'inputBytes': previewInput.length,
        'outputBytes': result.length,
      });
      debugPrint("⚡ Local processing completed in ${stopwatch.elapsedMilliseconds}ms");
      if (_cancelProcessingRequested) return;

      processedPreviewBytes = result;
      processedHdBytes = null;
      localResultBytes = result;
      cloudResultBytes = null;
      resultViewMode = 'local';
      hdExportReady = false;
      lastProcessedFeatureId = featureId;
      processedBytes = result;
      displayBytes = isPremium ? result : await ImageProcessor.applyWatermark(result);

      _rememberProcessedResult(featureId, result);
      lastProcessingUsedCloud = false;
      lastProcessingSource = shouldStartBackgroundCloud ? 'Fast Preview' : (freeCloudLimitReached ? 'Daily AI limit reached' : 'Local');
      lastProcessingMessage = freeCloudLimitReached
          ? 'Daily free AI limit (${CloudApiConfig.freeDailyCloudLimit}) reached — fast local result is ready. Upgrade to Premium for more cloud AI.'
          : (shouldStartBackgroundCloud
              ? 'Fast preview ready. Cloud AI is improving it in the background...'
              : 'Fast local result is ready.');

      _resetDailyIfNeeded();
      await _savePrefs();

      if (shouldStartBackgroundCloud) {
        _startCloudRefinement(
          runId: runId,
          featureId: featureId,
          previewInput: previewInput,
        );
      }
    } catch (e, st) {
      debugPrint('processFeature error: $e\n$st');
      processedBytes = originalBytes;
      displayBytes = originalBytes;
    } finally {
      isProcessing = false;
      notifyListeners();
    }
  }

  void _startCloudRefinement({
    required int runId,
    required String featureId,
    required Uint8List previewInput,
  }) {
    Future<void>(() async {
      isCloudRefining = true;
      notifyListeners();
      try {
        final cloudResult = await AiApiService.smartEnhance(
          imageBytes: previewInput,
          featureId: featureId,
          apiToken: _activeApiToken,
          isReplicate: CloudApiConfig.useReplicate,
          scale: featureId == 'upscale' ? upscaleScale : null,
          uploadMaxDimension: cloudUploadMaxDimension,
          uploadQuality: cloudUploadQuality,
          isPremiumUser: isPremium,
          onProgress: (message) {
            if (runId != _processingRunId || _cancelProcessingRequested) return;
            lastProcessingMessage = 'Fast preview ready. Cloud AI: $message';
            notifyListeners();
          },
        );

        if (runId != _processingRunId || _cancelProcessingRequested) return;
        _rememberTimings({
          ...AiApiService.lastTimings,
          'stage': 'cloud_refine',
          'quality': processingQuality,
        });

        if (cloudResult != null) {
          processedPreviewBytes = cloudResult;
          processedHdBytes = null;
          cloudResultBytes = cloudResult;
          resultViewMode = 'cloud';
          hdExportReady = false;
          lastProcessedFeatureId = featureId;
          processedBytes = cloudResult;
          displayBytes = isPremium ? cloudResult : await ImageProcessor.applyWatermark(cloudResult);
          _rememberProcessedResult(featureId, cloudResult);
          lastProcessingUsedCloud = true;
          lastProcessingSource = 'Cloud AI';
          lastProcessingMessage = 'Cloud AI result applied. You can save or compare now.';
          if (!isPremium) cloudAiUsedToday++;
          _resetDailyIfNeeded();
          await _savePrefs();
        } else {
          lastProcessingUsedCloud = false;
          lastProcessingSource = 'Fast Preview';
          lastProcessingMessage = AiApiService.lastErrorMessage ?? 'Cloud AI was slow or unavailable. Fast local result is kept.';
        }
      } catch (e) {
        if (runId == _processingRunId) {
          lastProcessingUsedCloud = false;
          lastProcessingSource = 'Fast Preview';
          lastProcessingMessage = 'Cloud AI failed. Fast local result is kept.';
          debugPrint('Cloud refinement failed: $e');
        }
      } finally {
        if (runId == _processingRunId) {
          isCloudRefining = false;
          notifyListeners();
        }
      }
    });
  }

  Future<bool> canExport() async {
    _resetDailyIfNeeded();
    if (isPremium) return true;
    return freeExportsToday < _dailyFreeExports;
  }

  Future<String?> saveToGallery() async {
    if (displayBytes == null && processedPreviewBytes == null) return 'No image to save';

    final ok = await canExport();
    if (!ok) {
      return 'Daily free limit reached. Upgrade to Premium.';
    }

    try {
      // Normal Save is intentionally instant: save the current preview result.
      // Premium HD export is available through a separate Save HD action.
      final Uint8List bytesToSave = displayBytes ?? processedPreviewBytes!;
      final path = await StorageService.saveToGallery(bytesToSave);
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
      isProcessing = false;
      return null;
    }
  }

  Future<String?> saveHdToGallery() async {
    if (!isPremium) return 'HD export is a Premium feature.';
    if (originalFullBytes == null || lastProcessedFeatureId == null) {
      return 'No processed image available for HD export.';
    }

    try {
      _cancelProcessingRequested = false;
      isProcessing = true;
      lastProcessingSource = 'HD Export';
      lastProcessingMessage = 'Preparing premium HD export...';
      notifyListeners();

      Uint8List? hdBytes = processedHdBytes;
      if (hdBytes == null) {
        hdBytes = await AiApiService.smartEnhance(
          imageBytes: originalFullBytes!,
          featureId: lastProcessedFeatureId!,
          apiToken: _activeApiToken,
          isReplicate: CloudApiConfig.useReplicate,
          scale: lastProcessedFeatureId == 'upscale' ? upscaleScale : null,
          uploadMaxDimension: 1920,
          uploadQuality: 90,
          isPremiumUser: true,
          isHdExport: true,
          onProgress: (message) {
            if (_cancelProcessingRequested) return;
            lastProcessingMessage = 'HD export: $message';
            notifyListeners();
          },
        );
      }

      if (_cancelProcessingRequested) return null;
      if (hdBytes == null) {
        isProcessing = false;
        lastProcessingMessage = 'HD export was unavailable. Please try again.';
        notifyListeners();
        return null;
      }

      processedHdBytes = hdBytes;
      hdExportReady = true;
      final path = await StorageService.saveToGallery(hdBytes);
      if (path != null) {
        await addToHistory(path);
        lastProcessingMessage = 'HD export saved to gallery.';
        await _savePrefs();
        notifyListeners();
        return path;
      }
      return null;
    } catch (e) {
      lastProcessingMessage = 'HD export failed: $e';
      return null;
    } finally {
      isProcessing = false;
      notifyListeners();
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
    if (!isPremium) {
      if (upscaleScale > 2) upscaleScale = 2;
      if (processingQuality == 'hd') processingQuality = 'fast';
    }
    _clearProcessingCache();
    await _savePrefs();
    if (processedBytes != null) {
      await _refreshDisplayFromProcessed();
    }
    notifyListeners();
  }

  Future<void> updateOriginalImage(Uint8List editedBytes) async {
    originalFullBytes = editedBytes;
    originalPreviewBytes = await ImageProcessor.preparePreview(
      editedBytes,
      maxDimension: 1024,
      quality: 76,
    );
    originalBytes = originalPreviewBytes;
    processedPreviewBytes = null;
    processedHdBytes = null;
    localResultBytes = null;
    cloudResultBytes = null;
    resultViewMode = 'auto';
    processedBytes = null;
    displayBytes = originalPreviewBytes;
    hdExportReady = false;
    lastProcessedFeatureId = null;
    _clearProcessingCache();
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
            _isCloudCapableFeature(featureId) &&
            !_shouldUseFastLocal(featureId)) {
          Uint8List? cloudResult = await AiApiService.smartEnhance(
            imageBytes: input,
            featureId: featureId,
            apiToken: _activeApiToken,
            isReplicate: CloudApiConfig.useReplicate,
            scale: featureId == 'upscale' ? upscaleScale : null,
            uploadMaxDimension: cloudUploadMaxDimension,
            uploadQuality: cloudUploadQuality,
            isPremiumUser: isPremium,
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
