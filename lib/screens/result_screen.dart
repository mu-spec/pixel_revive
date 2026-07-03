import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/constants/app_strings.dart';
import 'package:pixel_revive/providers/app_provider.dart';
import 'package:pixel_revive/screens/premium_screen.dart';
import 'package:pixel_revive/services/storage_service.dart';
import 'package:pixel_revive/widgets/before_after_slider.dart';
import 'package:pixel_revive/widgets/ad_banner.dart';
import 'package:pixel_revive/widgets/processing_dialog.dart';
import 'package:pixel_revive/services/ad_mob_service.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(
          AppStrings.getText('resultTitle', provider.languageCode),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.appBackgroundGradient),
        child: Column(
          children: [
            Expanded(
              flex: 6,
              child: _buildSliderView(provider),
            ),
            _buildProcessingSourcePanel(provider),
            _buildInfoPanel(context, provider),
            const AdBanner(margin: EdgeInsets.fromLTRB(20, 4, 20, 8)),
            _buildActionPanel(context, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderView(AppProvider provider) {
    if (provider.originalBytes == null || provider.processedBytes == null) {
      return Center(
        child: Text(
          AppStrings.getText('imageMissing', provider.languageCode),
          style: const TextStyle(color: AppColors.textMuted),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withOpacity(0.11),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
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
                child: BeforeAfterSlider(
                  beforeImage: provider.originalBytes!,
                  afterImage: provider.displayBytes ?? provider.processedBytes!,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingSourcePanel(AppProvider provider) {
    if (provider.processedBytes == null) return const SizedBox.shrink();

    final color = provider.processingRouteColor;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(provider.processingRouteIcon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.processingRouteLabel,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  provider.lastProcessingMessage,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (provider.lastProcessingTimingSummary.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    provider.lastProcessingTimingSummary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (provider.hasLocalAndCloudResults) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _resultModeChip(provider, 'local', 'Fast'),
                      const SizedBox(width: 8),
                      _resultModeChip(provider, 'cloud', 'Cloud'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Debug timings',
            onPressed: () => _showDebugDialog(context, provider),
            icon: const Icon(Icons.bug_report_outlined, size: 18, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _resultModeChip(AppProvider provider, String mode, String label) {
    final selected = provider.resultViewMode == mode || (provider.resultViewMode == 'auto' && mode == 'cloud');
    return InkWell(
      onTap: () => provider.setResultViewMode(mode),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.success.withOpacity(0.16) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.success : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.success : AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  void _showDebugDialog(BuildContext context, AppProvider provider) {
    final lines = <String>[
      'Feature: ${provider.lastProcessedFeatureId ?? '-'}',
      'Mode: ${provider.processingQualityLabel}',
      'Preset: ${provider.enhancementPresetLabel}',
      'Route: ${provider.processingRouteLabel}',
      'Message: ${provider.lastProcessingMessage}',
      if (provider.lastProcessingTimingSummary.isNotEmpty) 'Summary: ${provider.lastProcessingTimingSummary}',
      '',
      'Raw timings:',
      if (provider.lastProcessingTimings.isEmpty) '-' else ...provider.lastProcessingTimings.entries.map((e) => '${e.key}: ${e.value}'),
    ];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Processing debug', style: TextStyle(color: AppColors.text)),
        content: SingleChildScrollView(
          child: SelectableText(
            lines.join('\n'),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.35),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel(BuildContext context, AppProvider provider) {
    if (provider.isPremium) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.gold.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.star, color: AppColors.gold, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${AppStrings.getText('freeExports', provider.languageCode)} ${3 - provider.freeExportsToday.clamp(0, 3)}',
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PremiumScreen()),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    AppStrings.getText('goPremium', provider.languageCode).toUpperCase(),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppStrings.getText('watermarkNotice', provider.languageCode),
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionPanel(BuildContext context, AppProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
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
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: () => _shareImage(context, provider),
                      icon: const Icon(Icons.share, size: 20),
                      label: Text(
                        AppStrings.getText('share', provider.languageCode),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text,
                        side: BorderSide(color: Colors.black.withOpacity(0.15)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: AppColors.brandGradient),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: () => _saveImage(context, provider),
                      icon: const Icon(Icons.download, size: 20),
                      label: Text(
                        AppStrings.getText('save', provider.languageCode),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
              ],
            ),
            if (provider.needsHdExportForSave) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _saveHdImage(context, provider),
                  icon: const Icon(Icons.hd_rounded, size: 20, color: AppColors.gold),
                  label: const Text(
                    'Save HD (Premium)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.gold),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _saveImage(BuildContext context, AppProvider provider) async {
    final ok = await provider.canExport();
    if (!ok) {
      _showLimitReachedDialog(context, provider);
      return;
    }

    final path = await provider.saveToGallery();

    if (context.mounted) {
      if (path != null) {
        // Free users see an interstitial only after every few successful saves.
        // Premium users never see ads.
        AdMobService.maybeShowInterstitialAfterSave(isPremium: provider.isPremium);
        _showSuccessDialog(context, provider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.getText('saveFailedSnack', provider.languageCode)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _saveHdImage(BuildContext context, AppProvider provider) async {
    final ok = await provider.canExport();
    if (!ok) {
      _showLimitReachedDialog(context, provider);
      return;
    }

    bool dialogOpen = false;
    if (context.mounted) {
      dialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const ProcessingDialog(),
      ).then((_) => dialogOpen = false);
    }

    final path = await provider.saveHdToGallery();

    if (dialogOpen && context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    if (context.mounted) {
      if (path != null) {
        _showSuccessDialog(context, provider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppStrings.getText('saveFailedSnack', provider.languageCode)),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _shareImage(BuildContext context, AppProvider provider) async {
    final error = await provider.shareImage();
    if (error != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showSuccessDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.black.withOpacity(0.05),
              width: 1,
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                  size: 44,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppStrings.getText('successTitle', provider.languageCode),
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppStrings.getText('successSub', provider.languageCode),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Pop dialog
                        Navigator.pop(context); // Pop result screen to go back to editor
                      },
                      child: Text(
                        AppStrings.getText('excellent', provider.languageCode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await StorageService.openGallery();
                      },
                      icon: const Icon(Icons.photo_library_outlined, size: 18),
                      label: Text(
                        AppStrings.getText('openGallery', provider.languageCode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLimitReachedDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.gold),
            const SizedBox(width: 8),
            Text(AppStrings.getText('limitReachedTitle', provider.languageCode)),
          ],
        ),
        content: Text(
          AppStrings.getText('limitReachedSub', provider.languageCode),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              AppStrings.getText('later', provider.languageCode),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumScreen()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.white,
            ),
            child: Text(
              AppStrings.getText('goPremium', provider.languageCode),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.02)
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