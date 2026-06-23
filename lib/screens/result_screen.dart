import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/constants/app_strings.dart';
import 'package:pixel_revive/providers/app_provider.dart';
import 'package:pixel_revive/screens/premium_screen.dart';
import 'package:pixel_revive/widgets/before_after_slider.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final original = provider.originalBytes;
    final processed = provider.displayBytes;

    if (original == null || processed == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            'No result to display',
            style: TextStyle(color: AppColors.text),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(
          AppStrings.getText('resultTitle', provider.languageCode),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BeforeAfterSlider(
                  beforeImage: original,
                  afterImage: processed,
                ),
              ),
            ),
          ),
          _buildBottomBar(context, provider),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, AppProvider provider) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
              Container(
                margin: const EdgeInsets.only(bottom: 18),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_half,
                      color: AppColors.gold,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${AppStrings.getText('freeExports', provider.languageCode)} ${3 - provider.freeExportsToday.clamp(0, 3)}. ${AppStrings.getText('watermarkNotice', provider.languageCode)}',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12.5,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 54,
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
                      onPressed: () => _saveImage(context, provider),
                      icon: const Icon(Icons.file_download, size: 20, color: Colors.white),
                      // Fully localized Save Button!
                      label: Text(
                        AppStrings.getText('save', provider.languageCode),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shadowColor: Colors.transparent,
                        elevation: 0,
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
                    height: 54,
                    child: OutlinedButton.icon(
                      onPressed: () => _shareImage(context, provider),
                      icon: const Icon(Icons.share, size: 20),
                      // Fully localized Share Button!
                      label: Text(
                        AppStrings.getText('share', provider.languageCode),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.text,
                        side: BorderSide(color: Colors.white.withOpacity(0.15)),
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

  Future<void> _saveImage(BuildContext context, AppProvider provider) async {
    final can = await provider.canExport();
    if (!can && context.mounted) {
      _showPremiumDialog(context, provider);
      return;
    }

    final path = await provider.saveToGallery();
    if (context.mounted) {
      if (path != null) {
        // Show our gorgeous, high-end big success dialog!
        _showSuccessDialog(context, provider, path);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save image. Please check your storage permission!'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _shareImage(BuildContext context, AppProvider provider) async {
    final error = await provider.shareImage();
    if (context.mounted && error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showSuccessDialog(BuildContext context, AppProvider provider, String path) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.55),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.success.withOpacity(0.3), width: 1.5),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: AppColors.success,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                AppStrings.getText('successTitle', provider.languageCode),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.getText('successSub', provider.languageCode),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.brandGradient,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      AppStrings.getText('excellent', provider.languageCode),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPremiumDialog(BuildContext context, AppProvider provider) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        title: Row(
          children: [
            const Icon(Icons.star, color: AppColors.gold, size: 26),
            const SizedBox(width: 10),
            Text(
              AppStrings.getText('limitReachedTitle', provider.languageCode),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        content: Text(
          AppStrings.getText('limitReachedSub', provider.languageCode),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
            height: 1.4,
          ),
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
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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