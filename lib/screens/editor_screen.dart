import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/constants/app_strings.dart';
import 'package:pixel_revive/models/feature_item.dart';
import 'package:pixel_revive/providers/app_provider.dart';
import 'package:pixel_revive/screens/premium_screen.dart';
import 'package:pixel_revive/screens/result_screen.dart';
import 'package:pixel_revive/screens/crop_rotate_screen.dart';
import 'package:pixel_revive/widgets/processing_dialog.dart';
import 'package:pixel_revive/widgets/ad_banner.dart';
import 'package:pixel_revive/services/ai_api_service.dart';
import 'package:pixel_revive/services/gpu_shader_service.dart';
import 'package:pixel_revive/services/image_processor.dart';

class EditorScreen extends StatefulWidget {
  final String? initialFeatureId;
  const EditorScreen({super.key, this.initialFeatureId});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  String? selectedFeatureId;
  bool _processingDialogShown = false;
  Timer? _debounceTimer;
  Timer? _previewTimer;
  
  double _lastStrengthValue = 0.8;
  double _lastSmoothnessValue = 0.5;
  double _lastBokehValue = 0.6;
  bool _previewInitialized = false;
  bool _showAdvancedOptions = false;

  @override
  void initState() {
    super.initState();
    selectedFeatureId = widget.initialFeatureId ?? 'auto';
    _lastStrengthValue = context.read<AppProvider>().enhanceStrength;

    if (widget.initialFeatureId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _process();
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _previewTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(
          AppStrings.getText('aiStudio', provider.languageCode),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.crop_rotate, color: AppColors.success),
            tooltip: AppStrings.getText('cropRotate', provider.languageCode),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CropRotateScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.appBackgroundGradient),
        child: Column(
          children: [
            Expanded(flex: 7, child: _buildImagePreview(provider)),
            _buildSelectedFeatureSummary(provider),
            _buildFeatureSelector(provider),
            _buildAdvancedOptions(provider),
            const AdBanner(margin: EdgeInsets.fromLTRB(20, 0, 20, 6)),
            _buildActionBar(provider),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(AppProvider provider) {
    final imageToShow = provider.displayBytes ?? provider.originalBytes;
    if (imageToShow == null) {
      return Center(
        child: Text(
          AppStrings.getText('noImageSelected', provider.languageCode),
          style: const TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.11), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.34), blurRadius: 28, offset: const Offset(0, 14)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: CustomPaint(painter: _GridBackdropPainter()),
              ),
            ),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Image.memory(
                  imageToShow,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                  gaplessPlayback: true,
                ),
              ),
            ),
            Positioned(
              left: 14,
              top: 14,
              child: _processingRouteBadge(provider),
            ),
            if (provider.processedBytes != null && provider.lastProcessingMessage.isNotEmpty)
              Positioned(
                left: 14,
                right: 14,
                bottom: 14,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    provider.lastProcessingMessage,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                ),
              ),
            if (provider.isProcessing)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.accent, strokeWidth: 3),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFeatureSummary(AppProvider provider) {
    final id = selectedFeatureId ?? 'auto';
    final feature = allFeatures.firstWhere(
      (f) => f.id == id,
      orElse: () => allFeatures.first,
    );
    final desc = AppStrings.getText('desc_$id', provider.languageCode);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 2, 20, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: feature.color.withOpacity(0.24), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [feature.color.withOpacity(0.95), feature.color.withOpacity(0.55)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(feature.icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        feature.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _cloudModeChip(provider),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  desc,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11.2,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cloudModeChip(AppProvider provider) {
    final bool fast = provider.processingQuality == 'fast';
    final color = fast ? AppColors.success : AppColors.accent;
    final text = fast ? 'Fast' : provider.processingQualityLabel.replaceAll(' Quality', '');
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(fast ? Icons.flash_on_rounded : Icons.cloud_done_rounded, color: color, size: 13),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedOptions(AppProvider provider) {
    if (provider.originalBytes == null) return const SizedBox.shrink();
    final hasOptions = _adjustmentHasOptions(selectedFeatureId ?? 'auto');
    if (!hasOptions) return const SizedBox.shrink();

    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
            child: InkWell(
              onTap: () => setState(() => _showAdvancedOptions = !_showAdvancedOptions),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.035),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.tune_rounded, color: AppColors.textMuted, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _showAdvancedOptions
                            ? 'Hide advanced options'
                            : 'Advanced options: Look, strength and quality controls',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Icon(
                      _showAdvancedOptions ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_showAdvancedOptions) _buildAdjustmentSliders(provider),
        ],
      ),
    );
  }

  bool _adjustmentHasOptions(String id) {
    return id == 'auto' ||
        id == 'upscale' ||
        id == 'face' ||
        id == 'bg' ||
        {'restore', 'denoise', 'unblur', 'colorize', 'bg_cleanup'}.contains(id);
  }

  Widget _buildDescriptionBox(AppProvider provider) {
    final desc = AppStrings.getText('desc_$selectedFeatureId', provider.languageCode);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withOpacity(0.15), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(desc, style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.45, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustmentSliders(AppProvider provider) {
    if (provider.originalBytes == null) return const SizedBox.shrink();

    final id = selectedFeatureId ?? 'auto';

    if (id == 'auto') {
      return Column(
        children: [
          _enhancementPresetCard(provider),
          _sliderCard(
            title: AppStrings.getText('enhanceStrength', provider.languageCode),
            value: provider.enhanceStrength,
            onChanged: (v) {
              provider.setEnhanceStrength(v);
              _applyRealTimePreview(v);
            },
            icon: Icons.shutter_speed,
            activeColor: AppColors.success,
          ),
        ],
      );
    } else if (id == 'upscale') {
      return _upscaleSelectorCard(provider);
    } else if (id == 'face') {
      return Column(
        children: [
          _enhancementPresetCard(provider),
          _sliderCard(
            title: AppStrings.getText('faceStrength', provider.languageCode),
            value: provider.enhanceStrength,
            onChanged: (v) {
              provider.setEnhanceStrength(v);
              _applyRealTimePreview(v);
            },
            icon: Icons.face_retouching_natural,
            activeColor: AppColors.success,
          ),
          _sliderCard(
            title: AppStrings.getText('skinSmoothness', provider.languageCode),
            value: provider.skinSmoothness,
            onChanged: (v) {
              provider.setSkinSmoothness(v);
              _applyRealTimePreviewSmoothness(v);
            },
            icon: Icons.spa,
            activeColor: AppColors.accentLight,
          ),
        ],
      );
    } else if (id == 'bg') {
      return _sliderCard(
        title: AppStrings.getText('bokehDepth', provider.languageCode),
        value: provider.bokehBlur,
        onChanged: (v) {
          provider.setBokehBlur(v);
          _applyRealTimePreviewBokeh(v);
        },
        icon: Icons.blur_on,
        activeColor: AppColors.accent,
      );
    } else if ({'restore', 'denoise', 'unblur', 'colorize', 'bg_cleanup'}.contains(id)) {
      return _enhancementPresetCard(provider, compact: true);
    }

    return const SizedBox.shrink();
  }

  Widget _processingRouteBadge(AppProvider provider) {
    final color = provider.processingRouteColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.62),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.45), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(provider.processingRouteIcon, color: color, size: 15),
          const SizedBox(width: 6),
          Text(
            provider.processingRouteLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _enhancementPresetCard(AppProvider provider, {bool compact = false}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune_rounded, color: AppColors.success, size: 17),
              const SizedBox(width: 8),
              Text(
                'Look: ${provider.enhancementPresetLabel}',
                style: const TextStyle(color: AppColors.text, fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (!compact) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _presetChip(provider, 'natural', 'Natural'),
                const SizedBox(width: 8),
                _presetChip(provider, 'balanced', 'Balanced'),
                const SizedBox(width: 8),
                _presetChip(provider, 'strong', 'Strong'),
              ],
            ),
          ] else ...[
            const SizedBox(height: 6),
            const Text(
              'Natural/Balanced/Strong affects local preview strength. Cloud model quality depends on selected speed mode.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 10.5, height: 1.3),
            ),
          ],
        ],
      ),
    );
  }

  Widget _presetChip(AppProvider provider, String value, String label) {
    final selected = provider.enhancementPreset == value;
    return Expanded(
      child: InkWell(
        onTap: () {
          provider.setEnhancementPreset(value);
          _applyRealTimePreview(provider.enhanceStrength);
        },
        borderRadius: BorderRadius.circular(999),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppColors.success.withOpacity(0.16) : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AppColors.success : Colors.white12),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.success : AppColors.textMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _upscaleSelectorCard(AppProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.hd, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Text(
                AppStrings.getText('upscaleSize', provider.languageCode),
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${provider.upscaleScale}x',
                style: const TextStyle(color: AppColors.gold, fontSize: 13, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _scaleOption(provider, 2, '2x', AppStrings.getText('fastHd', provider.languageCode)),
              const SizedBox(width: 10),
              _scaleOption(provider, 4, '4x', AppStrings.getText('ultraHd', provider.languageCode)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.getText('upscaleNote', provider.languageCode),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _scaleOption(AppProvider provider, int scale, String title, String subtitle) {
    final selected = provider.upscaleScale == scale;
    return Expanded(
      child: InkWell(
        onTap: provider.isProcessing
            ? null
            : () {
                provider.setUpscaleScale(scale);
                if (selectedFeatureId == 'upscale' && provider.originalBytes != null) {
                  _process();
                }
              },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.gold : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.gold : Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: selected ? Colors.black : AppColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  color: selected ? Colors.black.withOpacity(0.7) : AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sliderCard({required String title, required double value, required ValueChanged<double> onChanged, required IconData icon, required Color activeColor}) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.04), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: activeColor, size: 18),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('${(value * 100).round()}%', style: TextStyle(color: activeColor, fontSize: 13, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 2),
          SliderTheme(
            data: SliderThemeData(trackHeight: 3, activeTrackColor: activeColor, inactiveTrackColor: AppColors.card, thumbColor: Colors.white, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), overlayShape: const RoundSliderOverlayShape(overlayRadius: 14)),
            child: Slider(value: value, min: 0.0, max: 1.0, onChanged: onChanged),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureSelector(AppProvider provider) {
    return Container(
      height: 112,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: allFeatures.length,
        itemBuilder: (context, index) {
          final feature = allFeatures[index];
          final isSelected = selectedFeatureId == feature.id;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SizedBox(
              width: 86,
              child: Material(
                color: isSelected ? AppColors.accent : AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: () { setState(() { selectedFeatureId = feature.id; _showAdvancedOptions = false; }); _process(); },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isSelected ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.05), width: 1.5),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(feature.icon, color: isSelected ? Colors.white : feature.color, size: 24),
                        const SizedBox(height: 8),
                        Text(AppStrings.getText('feat_${feature.id}_title', provider.languageCode), textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.white : AppColors.text, fontSize: 10.5, fontWeight: FontWeight.bold, letterSpacing: 0.1), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionBar(AppProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!provider.isPremium)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.star, size: 14, color: AppColors.gold),
                    const SizedBox(width: 6),
                    Text('${AppStrings.getText('freeSaves', provider.languageCode)} ${3 - provider.freeExportsToday.clamp(0, 3)}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: AppColors.brandGradient),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: provider.isProcessing ? null : _process,
                      icon: provider.isProcessing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.auto_fix_high, size: 20),
                      label: Text(provider.isProcessing ? AppStrings.getText('processingLabel', provider.languageCode) : AppStrings.getText('enhance', provider.languageCode), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, foregroundColor: Colors.white, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: provider.processedBytes == null ? null : _goToResult,
                      icon: const Icon(Icons.compare, size: 20),
                      label: Text(AppStrings.getText('compare', provider.languageCode), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white, disabledBackgroundColor: AppColors.card, disabledForegroundColor: AppColors.textMuted, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _applyRealTimePreview(double strength) {
    if ((strength - _lastStrengthValue).abs() < 0.05 && _previewInitialized) return;
    _lastStrengthValue = strength;
    _previewInitialized = true;
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () async {
      final provider = context.read<AppProvider>();
      if (provider.originalBytes == null || provider.isProcessing) return;

      try {
        if (GpuShaderService.isAvailable) {
          final result = await GpuShaderService.processOnGpu(
            inputBytes: provider.originalBytes!,
            brightness: 0.0,
            contrast: 1.0 + strength * 0.45,
            saturation: 1.0 + strength * 0.50,
            sharpen: strength * 1.8,
          );
          
          if (result != null && mounted) {
            provider.setDisplayBytes(result);
            return;
          }
        }
        
        final result = await ImageProcessor.fastPreview(
          provider.originalBytes!,
          contrast: 1.0 + strength * 0.40,
          saturation: 1.0 + strength * 0.45,
          sharpness: strength * 1.5,
        );
        
        if (mounted) provider.setDisplayBytes(result);
      } catch (_) {}
    });
  }

  void _applyRealTimePreviewSmoothness(double smoothness) {
    if ((smoothness - _lastSmoothnessValue).abs() < 0.05 && _previewInitialized) return;
    _lastSmoothnessValue = smoothness;
    _previewInitialized = true;
  }

  void _applyRealTimePreviewBokeh(double bokeh) {
    if ((bokeh - _lastBokehValue).abs() < 0.05 && _previewInitialized) return;
    _lastBokehValue = bokeh;
    _previewInitialized = true;
  }

  Future<void> _process() async {
    if (selectedFeatureId == null) return;
    final provider = context.read<AppProvider>();

    setState(() => _processingDialogShown = true);
    showDialog(context: context, barrierDismissible: false, builder: (_) => const ProcessingDialog());

    await provider.processFeature(selectedFeatureId!);

    if (mounted && _processingDialogShown) {
      Navigator.of(context).pop();
      setState(() => _processingDialogShown = false);
      _previewInitialized = false;
    }
  }

  void _goToResult() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ResultScreen()));
  }
}

class _GridBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.5)..style = PaintingStyle.fill;
    const double cellSize = 12.0;
    for (double y = 0; y < size.height; y += cellSize) {
      for (double x = 0; x < size.width; x += cellSize) {
        if (((x / cellSize).floor() + (y / cellSize).floor()) % 2 == 0) {
          canvas.drawRect(Rect.fromLTWH(x, y, cellSize, cellSize), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}