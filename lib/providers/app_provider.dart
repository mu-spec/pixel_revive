import 'dart:async';
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
import 'package:pixel_revive/services/app_telemetry_service.dart';

class AppProvider extends ChangeNotifier {
  // TEMPORARY FOR SENIOR/QA TESTING ONLY. Set to false before Play Store release.
  static const bool forcePremiumForTesting = true;

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
  // Cloud AI credits used today. Free users get CloudApiConfig.freeDailyCloudLimit
  // base credits plus any rewarded-ad credits earned today.
  int cloudAiUsedToday = 0;
  int rewardedCloudCreditsToday = 0;

  double enhanceStrength = 0.8;
  double skinSmoothness = 0.5;
  double bokehBlur = 0.6;
  int upscaleScale = 2;
  String enhancementPreset = 'balanced'; // natural, balanced, strong
  String processingQuality = 'fast'; // fast, balanced, hd
  String backgroundChangePrompt = 'professional studio background, realistic lighting';
  Map<String, dynamic> pendingEffectExtraInput = <String, dynamic>{};

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

  // Features that have a real cloud model. Background blur remains local-only.
  static const Set<String> _cloudCapableFeatures = {
    'auto',
    'face',
    'restore',
    'upscale',
    'colorize',
    'bg_cleanup',
    'denoise',
    'unblur',
    'cartoon',
    'age_progression',
    'baby_version',
    'background_change',
    'broccoli_haircut',
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

  static const Set<String> _cloudOnlyFeatures = {
    'age_progression',
    'baby_version',
    'background_change',
    'broccoli_haircut',
  };

  bool _shouldUseFastLocal(String featureId) =>
      processingQuality == 'fast' && _fastModeLocalFeatures.contains(featureId);

  bool _shouldAttemptCloudForFeature(String featureId) =>
      useCloudAi &&
      canUseCloudAiForFeature(featureId) &&
      _isCloudCapableFeature(featureId) &&
      !_shouldUseFastLocal(featureId);

  bool _canStartBackgroundCloud(String featureId) =>
      useCloudAi && canUseCloudAiForFeature(featureId) && _isCloudCapableFeature(featureId);

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
    isPremium = forcePremiumForTesting ? true : (prefs.getBool('is_premium') ?? false);
    freeExportsToday = prefs.getInt('free_exports_today') ?? 0;
    lastExportDate = prefs.getString('last_export_date');
    useCloudAi = prefs.getBool('use_cloud_ai') ?? CloudApiConfig.useBackendProxy;
    devOverrideToken = prefs.getString('dev_override_token') ?? '';
    cloudAiUsedToday = prefs.getInt('cloud_ai_used_today') ?? 0;
    rewardedCloudCreditsToday = prefs.getInt('rewarded_cloud_credits_today') ?? 0;
    upscaleScale = (prefs.getInt('upscale_scale') ?? 2).clamp(2, isPremium ? 4 : 2).toInt();
    enhancementPreset = prefs.getString('enhancement_preset') ?? 'balanced';
    processingQuality = prefs.getString('processing_quality') ?? 'fast';
    if (!isPremium && processingQuality == 'hd') processingQuality = 'fast';
    languageCode = prefs.getString('language_code') ?? 'en';
    creationHistory = prefs.getStringList('creation_history') ?? [];
    _resetDailyIfNeeded();
    unawaited(AppTelemetryService.setUserProperties(
      isPremium: isPremium,
      processingQuality: processingQuality,
      cloudEnabled: useCloudAi,
      languageCode: languageCode,
    ));
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
    await prefs.setInt('rewarded_cloud_credits_today', rewardedCloudCreditsToday);
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
      rewardedCloudCreditsToday = 0;
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

  int get totalCloudCreditsToday =>
      CloudApiConfig.freeDailyCloudLimit + rewardedCloudCreditsToday;

  int get remainingCloudCreditsToday =>
      (totalCloudCreditsToday - cloudAiUsedToday).clamp(0, 999999).toInt();

  int cloudCreditCost(String featureId, {bool isHdExport = false, bool isBatch = false}) {
    if (isBatch) return 1;
    if (isHdExport) return 3;
    switch (featureId) {
      case 'colorize':
        return isPremium ? 2 : 1;
      case 'upscale':
        return upscaleScale >= 4 ? 2 : 1;
      case 'background_change':
      case 'age_progression':
      case 'baby_version':
      case 'broccoli_haircut':
        return 2;
      case 'auto':
      case 'face':
      case 'denoise':
      case 'unblur':
      case 'restore':
      case 'bg_cleanup':
      default:
        return 1;
    }
  }

  bool canUseCloudAiForFeature(String featureId, {bool isHdExport = false, bool isBatch = false}) {
    if (!isCloudAiAvailable) return false;
    if (!useCloudAi) return false;
    if (isPremium) return true;
    if (CloudApiConfig.cloudAiPremiumOnly) return false;
    return cloudAiUsedToday + cloudCreditCost(featureId, isHdExport: isHdExport, isBatch: isBatch) <= totalCloudCreditsToday;
  }

  bool get canUseCloudAi => canUseCloudAiForFeature('auto');

  Future<void> addRewardedCloudCredit({int amount = 1}) async {
    _resetDailyIfNeeded();
    rewardedCloudCreditsToday += amount.clamp(1, 10).toInt();
    await _savePrefs();
    unawaited(AppTelemetryService.logEvent('rewarded_cloud_credit_added', parameters: {
      'amount': amount,
      'rewarded_credits_today': rewardedCloudCreditsToday,
      'remaining_credits_today': remainingCloudCreditsToday,
    }));
    notifyListeners();
  }

  Future<bool> consumeCloudCredits(String featureId, {bool isHdExport = false, bool isBatch = false}) async {
    if (isPremium) return true;
    final cost = cloudCreditCost(featureId, isHdExport: isHdExport, isBatch: isBatch);
    if (cloudAiUsedToday + cost > totalCloudCreditsToday) return false;
    cloudAiUsedToday += cost;
    _resetDailyIfNeeded();
    await _savePrefs();
    return true;
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
    if (!useCloudAi || !canUseCloudAiForFeature(featureId) || !_isCloudCapableFeature(featureId)) {
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
    unawaited(AppTelemetryService.logEvent('processing_quality_changed', parameters: {
      'quality': processingQuality,
      'is_premium': isPremium,
    }));
    notifyListeners();
  }

  void setBackgroundChangePrompt(String prompt) {
    backgroundChangePrompt = prompt.trim().isEmpty
        ? 'professional studio background, realistic lighting'
        : prompt.trim();
    notifyListeners();
  }

  void setPendingEffectExtraInput(Map<String, dynamic> input) {
    pendingEffectExtraInput = Map<String, dynamic>.from(input);
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
    unawaited(AppTelemetryService.logEvent('enhancement_preset_changed', parameters: {
      'preset': enhancementPreset,
      'strength': enhanceStrength,
    }));
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

  String _ageProgressionPromptFor(int targetAge, String gender) {
    if (gender == 'female') {
      return 'transform the person into a realistic female aged $targetAge years old, preserve facial identity, keep a smooth feminine face, do not add beard, do not add mustache, no facial hair, no stubble, realistic photo';
    }
    return 'transform the person into a realistic male aged $targetAge years old, preserve facial identity, preserve existing beard or mustache if present, if clean-shaven remain clean-shaven, do not remove facial hair, realistic photo';
  }

  String _babyPromptFor(String ageGroup, String gender) {
    switch (ageGroup) {
      case 'toddler':
        return 'transform the person into a cute $gender toddler aged 2 to 5 years old, preserve facial identity, realistic photo';
      case 'preschool':
        return 'transform the person into a cute $gender preschool child aged 5 to 7 years old, preserve facial identity, realistic photo';
      case 'baby':
      default:
        return 'transform the person into a cute 1 year old $gender baby, preserve facial identity, realistic photo';
    }
  }

  Map<String, dynamic>? _extraInputForFeature(String featureId) {
    if (featureId == 'background_change') {
      return {
        'prompt': pendingEffectExtraInput['prompt'] ?? backgroundChangePrompt,
      };
    }
    if (featureId == 'baby_version') {
      final ageGroup = (pendingEffectExtraInput['age_group'] ?? 'baby').toString();
      final gender = (pendingEffectExtraInput['gender'] ?? 'male').toString();
      return {
        'age_group': ageGroup,
        'gender': gender,
        'prompt': pendingEffectExtraInput['prompt'] ?? _babyPromptFor(ageGroup, gender),
      };
    }
    if (featureId == 'broccoli_haircut') {
      final gender = (pendingEffectExtraInput['gender'] ?? 'male').toString();
      return {
        'gender': gender,
        'prompt': pendingEffectExtraInput['prompt'] ?? (gender == 'female'
            ? 'create a feminine broccoli-inspired curly hairstyle with soft voluminous curls, preserve long feminine hair shape as much as possible, do not make it a boy haircut, keep natural realistic hair and preserve face identity'
            : 'broccoli haircut style, preserve face identity, realistic hairstyle'),
      };
    }

    if (featureId == 'age_progression') {
      final gender = (pendingEffectExtraInput['gender'] ?? 'male').toString();
      final targetAge = pendingEffectExtraInput['target_age'] is int
          ? pendingEffectExtraInput['target_age'] as int
          : int.tryParse(pendingEffectExtraInput['target_age']?.toString() ?? '') ?? 30;
      return {
        'target_age': targetAge,
        'gender': gender,
        'prompt': pendingEffectExtraInput['prompt'] ?? _ageProgressionPromptFor(targetAge, gender),
      };
    }
    return null;
  }

  Future<void> processFeature(String featureId) async {
    if (originalPreviewBytes == null && originalBytes == null) return;
    final Uint8List inputBytes = originalPreviewBytes ?? originalBytes!;

    _cancelProcessingRequested = false;
    final int runId = ++_processingRunId;
    isProcessing = true;
    isCloudRefining = false;
    lastProcessingUsedCloud = false;
    localResultBytes = null;
    cloudResultBytes = null;
    resultViewMode = 'auto';

    final bool canUseCloudForThisFeature = _canStartBackgroundCloud(featureId);
    final bool freeCloudLimitReached = !isPremium &&
        CloudApiConfig.isCloudAvailable &&
        !CloudApiConfig.cloudAiPremiumOnly &&
        useCloudAi &&
        _isCloudCapableFeature(featureId) &&
        cloudAiUsedToday + cloudCreditCost(featureId) > totalCloudCreditsToday;

    lastProcessingSource = canUseCloudForThisFeature ? 'Cloud AI' : 'Local';
    lastProcessingMessage = canUseCloudForThisFeature
        ? 'Cloud AI is processing ${featureId.replaceAll('_', ' ')} with ${CloudApiConfig.activeProviderLabel}...'
        : (freeCloudLimitReached
            ? 'Daily cloud credits used ($cloudAiUsedToday/$totalCloudCreditsToday). Processing locally.'
            : 'Processing locally (${estimatedProcessingTime(featureId)})...');
    notifyListeners();

    final cacheKey = _cacheKey(featureId);
    final cachedResult = _processedCache[cacheKey];
    if (cachedResult != null) {
      processedBytes = cachedResult;
      processedPreviewBytes = cachedResult;
      await _refreshDisplayFromProcessed();
      isProcessing = false;
      lastProcessingMessage = 'Loaded instantly from cache.';
      unawaited(AppTelemetryService.logEvent('processing_cache_hit', parameters: {
        'feature': featureId,
        'quality': processingQuality,
      }));
      notifyListeners();
      return;
    }

    unawaited(AppTelemetryService.logEvent('feature_processing_started', parameters: {
      'feature': featureId,
      'quality': processingQuality,
      'preset': enhancementPreset,
      'cloud_enabled': useCloudAi,
      'cloud_possible': canUseCloudForThisFeature,
      'is_premium': isPremium,
    }));

    if (canUseCloudForThisFeature) {
      try {
        final cloudResult = await AiApiService.smartEnhance(
          imageBytes: inputBytes,
          featureId: featureId,
          apiToken: _activeApiToken,
          isReplicate: CloudApiConfig.useReplicate,
          scale: featureId == 'upscale' ? upscaleScale : null,
          uploadMaxDimension: cloudUploadMaxDimension,
          uploadQuality: cloudUploadQuality,
          isPremiumUser: isPremium,
          extraInput: _extraInputForFeature(featureId),
          onProgress: (message) {
            if (_cancelProcessingRequested || runId != _processingRunId) return;
            lastProcessingMessage = message;
            notifyListeners();
          },
        );

        if (_cancelProcessingRequested || runId != _processingRunId) return;
        _rememberTimings({
          ...AiApiService.lastTimings,
          'stage': 'cloud_primary',
          'quality': processingQuality,
        });

        if (cloudResult != null) {
          processedPreviewBytes = cloudResult;
          processedHdBytes = null;
          cloudResultBytes = cloudResult;
          localResultBytes = null;
          resultViewMode = 'cloud';
          hdExportReady = false;
          lastProcessedFeatureId = featureId;
          processedBytes = cloudResult;
          await _refreshDisplayFromProcessed();
          _rememberProcessedResult(featureId, cloudResult);
          lastProcessingUsedCloud = true;
          lastProcessingSource = 'Cloud AI';
          lastProcessingMessage = 'Cloud AI result applied. You can save or compare now.';
          await consumeCloudCredits(featureId);
          unawaited(AppTelemetryService.logEvent('cloud_primary_success', parameters: {
            'feature': featureId,
            'quality': processingQuality,
            'model': AiApiService.lastCloudModel ?? '',
            'total_ms': AiApiService.lastTimings['totalMs'] ?? 0,
            'polls': AiApiService.lastTimings['polls'] ?? 0,
          }));
          isProcessing = false;
          notifyListeners();
          return;
        }

        lastProcessingSource = 'Cloud unavailable';
        lastProcessingMessage = AiApiService.lastErrorMessage ?? 'Cloud AI was unavailable. Processing locally instead.';
        unawaited(AppTelemetryService.logEvent('cloud_primary_failed', parameters: {
          'feature': featureId,
          'quality': processingQuality,
          'reason': AiApiService.lastErrorMessage ?? 'null_result',
          'model': AiApiService.lastCloudModel ?? '',
          'total_ms': AiApiService.lastTimings['totalMs'] ?? 0,
        }));
        notifyListeners();
      } catch (e, st) {
        lastProcessingSource = 'Cloud unavailable';
        lastProcessingMessage = 'Cloud AI failed. Processing locally instead.';
        debugPrint('Cloud primary failed: $e');
        unawaited(AppTelemetryService.recordError(e, st, reason: 'cloud_primary_failed', information: {
          'feature': featureId,
          'quality': processingQuality,
        }));
      }
    }

    if (_cloudOnlyFeatures.contains(featureId)) {
      lastProcessingUsedCloud = false;
      lastProcessingSource = 'Cloud required';
      lastProcessingMessage = freeCloudLimitReached
          ? 'This AI effect needs cloud credits. Watch a rewarded ad or upgrade to Premium.'
          : 'This AI effect requires Cloud AI. Please enable Cloud AI and try again.';
      isProcessing = false;
      notifyListeners();
      return;
    }

    // Local fallback/offline path. This runs only when cloud is off, credits are
    // exhausted, the feature is local-only, or cloud failed.
    try {
      final stopwatch = Stopwatch()..start();
      if (featureId == 'face' || featureId == 'bg') {
        await _preWarmServices();
      }
      final result = await _processLocalFeatureSync(inputBytes, featureId);
      stopwatch.stop();
      if (_cancelProcessingRequested || runId != _processingRunId) return;

      _rememberTimings({
        'stage': 'local_result',
        'feature': featureId,
        'quality': processingQuality,
        'localMs': stopwatch.elapsedMilliseconds,
        'inputBytes': inputBytes.length,
        'outputBytes': result.length,
      });

      processedPreviewBytes = result;
      processedHdBytes = null;
      localResultBytes = result;
      cloudResultBytes = null;
      resultViewMode = 'local';
      hdExportReady = false;
      lastProcessedFeatureId = featureId;
      processedBytes = result;
      await _refreshDisplayFromProcessed();
      _rememberProcessedResult(featureId, result);
      lastProcessingUsedCloud = false;
      lastProcessingSource = freeCloudLimitReached ? 'Daily AI limit reached' : 'Local';
      lastProcessingMessage = freeCloudLimitReached
          ? 'Daily cloud credits used ($cloudAiUsedToday/$totalCloudCreditsToday). Local result is ready. Watch a rewarded ad or upgrade for more cloud AI.'
          : 'Local result is ready.';
      unawaited(AppTelemetryService.logEvent('local_result_ready', parameters: {
        'feature': featureId,
        'quality': processingQuality,
        'local_ms': stopwatch.elapsedMilliseconds,
      }));
    } catch (e, st) {
      debugPrint('processFeature local fallback error: $e\n$st');
      processedBytes = originalBytes;
      displayBytes = originalBytes;
      unawaited(AppTelemetryService.recordError(e, st, reason: 'process_feature_failed'));
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
      unawaited(AppTelemetryService.logEvent('cloud_refine_started', parameters: {
        'feature': featureId,
        'quality': processingQuality,
        'is_premium': isPremium,
      }));
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
          await consumeCloudCredits(featureId);
          unawaited(AppTelemetryService.logEvent('cloud_refine_success', parameters: {
            'feature': featureId,
            'quality': processingQuality,
            'model': AiApiService.lastCloudModel ?? '',
            'total_ms': AiApiService.lastTimings['totalMs'] ?? 0,
            'polls': AiApiService.lastTimings['polls'] ?? 0,
          }));
        } else {
          lastProcessingUsedCloud = false;
          lastProcessingSource = 'Fast Preview';
          lastProcessingMessage = AiApiService.lastErrorMessage ?? 'Cloud AI was slow or unavailable. Fast local result is kept.';
          unawaited(AppTelemetryService.logEvent('cloud_refine_failed', parameters: {
            'feature': featureId,
            'quality': processingQuality,
            'reason': AiApiService.lastErrorMessage ?? 'null_result',
            'model': AiApiService.lastCloudModel ?? '',
            'total_ms': AiApiService.lastTimings['totalMs'] ?? 0,
          }));
        }
      } catch (e) {
        if (runId == _processingRunId) {
          lastProcessingUsedCloud = false;
          lastProcessingSource = 'Fast Preview';
          lastProcessingMessage = 'Cloud AI failed. Fast local result is kept.';
          debugPrint('Cloud refinement failed: $e');
          unawaited(AppTelemetryService.logEvent('cloud_refine_exception', parameters: {
            'feature': featureId,
            'quality': processingQuality,
            'error': e.toString(),
          }));
          unawaited(AppTelemetryService.recordError(e, null, reason: 'cloud_refinement_failed', information: {
            'feature': featureId,
            'quality': processingQuality,
          }));
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
        unawaited(AppTelemetryService.logEvent('save_success', parameters: {
          'is_premium': isPremium,
          'hd': false,
          'feature': lastProcessedFeatureId ?? '',
        }));
        notifyListeners();
        return path;
      }
      return null;
    } catch (e, st) {
      isProcessing = false;
      unawaited(AppTelemetryService.logEvent('save_failed', parameters: {
        'hd': false,
        'error': e.toString(),
      }));
      unawaited(AppTelemetryService.recordError(e, st, reason: 'save_failed'));
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
      unawaited(AppTelemetryService.logEvent('save_hd_started', parameters: {
        'feature': lastProcessedFeatureId ?? '',
        'scale': upscaleScale,
      }));

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
          extraInput: _extraInputForFeature(lastProcessedFeatureId!),
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
        await consumeCloudCredits(lastProcessedFeatureId!, isHdExport: true);
        await _savePrefs();
        unawaited(AppTelemetryService.logEvent('save_hd_success', parameters: {
          'feature': lastProcessedFeatureId ?? '',
          'model': AiApiService.lastCloudModel ?? '',
          'total_ms': AiApiService.lastTimings['totalMs'] ?? 0,
        }));
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
    isPremium = forcePremiumForTesting ? true : value;
    if (!isPremium) {
      if (upscaleScale > 2) upscaleScale = 2;
      if (processingQuality == 'hd') processingQuality = 'fast';
    }
    _clearProcessingCache();
    await _savePrefs();
    unawaited(AppTelemetryService.setUserProperties(
      isPremium: isPremium,
      processingQuality: processingQuality,
      cloudEnabled: useCloudAi,
      languageCode: languageCode,
    ));
    unawaited(AppTelemetryService.logEvent('premium_status_changed', parameters: {
      'is_premium': isPremium,
    }));
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
            extraInput: _extraInputForFeature(featureId),
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
