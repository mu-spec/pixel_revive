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

  @override
  void initState() {
    super.initState();
    selectedFeatureId = widget.initialFeatureId ?? 'auto';
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AppProvider>();
      if (provider.useCloudAi && provider.falToken.isNotEmpty) {
        AiApiService.preWarmModel(
          modelName: 'fal-ai/codeformer',
          apiToken: provider.falToken,
        );
      }
    });

    if (widget.initialFeatureId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _process();
      });
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text(
          'AI Photo Studio',
          style: TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.crop_rotate, color: AppColors.success),
            tooltip: 'Crop & Rotate',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CropRotateScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 4,
            child: _buildImagePreview(provider),
          ),
          _buildDescriptionBox(provider),
          _buildAdjustmentSliders(provider),
          _buildFeatureSelector(provider),
          _buildActionBar(provider),
        ],
      ),
    );
  }

  Widget _buildImagePreview(AppProvider provider) {
    final imageToShow = provider.displayBytes ?? provider.originalBytes;
    if (imageToShow == null) {
      return const Center(
        child: Text(
          'No image selected',
          style: TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.1,
                child: CustomPaint(
                  painter: _GridBackdropPainter(),
                ),
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
        border: Border.all(
          color: AppColors.accent.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: AppColors.accent,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              desc,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.5,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustmentSliders(AppProvider provider) {
    if (provider.originalBytes == null) return const SizedBox.shrink();

    final id = selectedFeatureId ?? 'auto';

    if (id == 'auto') {
      return _sliderCard(
        title: 'Enhance Strength',
        value: provider.enhanceStrength,
        onChanged: (v) {
          provider.setEnhanceStrength(v);
          _applyRealTimePreview(v);
        },
        icon: Icons.shutter_speed,
        activeColor: AppColors.success,
      );
    } else if (id == 'face') {
      return Column(
        children: [
          _sliderCard(
            title: 'Face Enhance Strength',
            value: provider.enhanceStrength,
            onChanged: (v) {
              provider.setEnhanceStrength(v);
              _applyRealTimePreview(v);
            },
            icon: Icons.face_retouching_natural,
            activeColor: AppColors.success,
          ),
          _sliderCard(
            title: 'Skin Smoothness',
            value: provider.skinSmoothness,
            onChanged: (v) => provider.setSkinSmoothness(v),
            icon: Icons.spa,
            activeColor: AppColors.accentLight,
          ),
        ],
      );
    } else if (id == 'bg') {
      return _sliderCard(
        title: 'Background Bokeh Depth',
        value: provider.bokehBlur,
        onChanged: (v) {
          provider.setBokehBlur(v);
          _applyRealTimePreview(v);
        },
        icon: Icons.blur_on,
        activeColor: AppColors.accent,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _sliderCard({
    required String title,
    required double value,
    required ValueChanged<double> onChanged,
    required IconData icon,
    required Color activeColor,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.04),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: activeColor, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${(value * 100).round()}%',
                style: TextStyle(
                  color: activeColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 3,
              activeTrackColor: activeColor,
              inactiveTrackColor: AppColors.card,
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            ),
            child: Slider(
              value: value,
              min: 0.0,
              max: 1.0,
              onChanged: onChanged,
            ),
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
                  onTap: () {
                    setState(() => selectedFeatureId = feature.id);
                    _process();
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? Colors.white.withOpacity(0.2)
                            : Colors.white.withOpacity(0.05),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          feature.icon,
                          color: isSelected ? Colors.white : feature.color,
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          feature.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.text,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, -6),
          ),
        ],
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
                    const Icon(Icons.star,
                        size: 14, color: AppColors.gold),
                    const SizedBox(width: 6),
                    Text(
                      '${AppStrings.getText('freeSaves', provider.languageCode)} ${3 - provider.freeExportsToday.clamp(0, 3)}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.brandGradient,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: provider.isProcessing ? null : _process,
                      icon: provider.isProcessing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_fix_high, size: 20),
                      label: Text(
                        provider.isProcessing ? 'Processing' : AppStrings.getText('enhance', provider.languageCode),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
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
                      label: Text(
                        AppStrings.getText('compare', provider.languageCode),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.card,
                        disabledForegroundColor: AppColors.textMuted,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
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

  // ==================== REAL-TIME GPU PREVIEW ====================
  void _applyRealTimePreview(double value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 16), () async {
      final provider = context.read<AppProvider>();
      if (provider.originalBytes == null) return;

      try {
        Uint8List result;
        
        if (GpuShaderService.isAvailable) {
          double brightness = 0.0;
          double contrast = 1.0;
          double saturation = 1.0;
          double sharpen = 0.0;

          if (selectedFeatureId == 'auto') {
            contrast = 1.0 + value * 0.40;
            saturation = 1.0 + value * 0.45;
            sharpen = value * 1.80;
          } else if (selectedFeatureId == 'face') {
            contrast = 1.05 + value * 0.15;
            saturation = 1.0 + value * 0.16;
            sharpen = value * 1.35;
          }

          result = await GpuShaderService.processOnGpu(
            inputBytes: provider.originalBytes!,
            brightness: brightness,
            contrast: contrast,
            saturation: saturation,
            sharpen: sharpen,
          );
        } else {
          result = await ImageProcessor.autoEnhance(
            provider.originalBytes!,
            strength: value,
          );
        }
        
        if (mounted) {
          provider.setDisplayBytes(result);
        }
      } catch (_) {}
    });
  }

  Future<void> _process() async {
    if (selectedFeatureId == null) return;
    final provider = context.read<AppProvider>();

    setState(() => _processingDialogShown = true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const ProcessingDialog(),
    );

    await provider.processFeature(selectedFeatureId!);

    if (mounted && _processingDialogShown) {
      Navigator.of(context).pop();
      setState(() => _processingDialogShown = false);
    }
  }

  void _goToResult() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ResultScreen()),
    );
  }
}

class _GridBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    const double cellSize = 12.0;
    for (double y = 0; y < size.height; y += cellSize) {
      for (double x = 0; x < size.width; x += cellSize) {
        if (((x / cellSize).floor() + (y / cellSize).floor()) % 2 == 0) {
          canvas.drawRect(
              Rect.fromLTWH(x, y, cellSize, cellSize), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}