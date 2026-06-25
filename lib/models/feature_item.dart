import 'package:flutter/material.dart';
import 'package:pixel_revive/constants/app_colors.dart';

class FeatureItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String imagePath;
  final String? description;
  final bool isPremium;

  const FeatureItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.imagePath,
    this.description,
    this.isPremium = false,
  });
}

final List<FeatureItem> allFeatures = [
  FeatureItem(id: 'auto', title: 'Auto Enhance', subtitle: 'Fix color, contrast & detail', icon: Icons.auto_fix_high, color: AppColors.success, imagePath: 'assets/images/thumb_auto.png'),
  FeatureItem(id: 'upscale', title: 'HD Upscale', subtitle: 'Choose 2x or 4x enlargement', icon: Icons.hd, color: AppColors.gold, imagePath: 'assets/images/thumb_upscale.png'),
  FeatureItem(id: 'face', title: 'Face Enhance', subtitle: 'Sharpen faces & smooth skin', icon: Icons.face, color: AppColors.accentLight, imagePath: 'assets/images/thumb_face.png'),
  FeatureItem(id: 'denoise', title: 'Denoise', subtitle: 'Reduce grain while keeping edges', icon: Icons.grain, color: AppColors.text, imagePath: 'assets/images/thumb_denoise.png'),
  FeatureItem(id: 'unblur', title: 'Unblur', subtitle: 'Sharpen soft or mildly blurry photos', icon: Icons.deblur, color: AppColors.success, imagePath: 'assets/images/thumb_unblur.png'),
  FeatureItem(id: 'colorize', title: 'Colorize B&W', subtitle: 'Warm color effect for monochrome photos', icon: Icons.palette, color: AppColors.accent, imagePath: 'assets/images/thumb_colorize.png'),
  FeatureItem(id: 'restore', title: 'Old Photo Restore', subtitle: 'Fix faded tones & improve clarity', icon: Icons.restore, color: AppColors.gold, imagePath: 'assets/images/thumb_restore.png'),
  FeatureItem(id: 'cartoon', title: 'Cartoon Effect', subtitle: 'Artistic edge & color pop', icon: Icons.brush, color: AppColors.accentLight, imagePath: 'assets/images/thumb_cartoon.png'),
  FeatureItem(id: 'bg', title: 'Background Blur', subtitle: 'Center-focused bokeh effect', icon: Icons.blur_on, color: AppColors.text, imagePath: 'assets/images/thumb_bg.png'),
  FeatureItem(id: 'bg_cleanup', title: 'BG Cleanup', subtitle: 'Cloud remove-bg or local background focus', icon: Icons.cleaning_services, color: AppColors.success, imagePath: 'assets/images/thumb_bg.png'),
];

final Map<String, double> featureProcessingTimes = {
  'auto': 2.5,
  'upscale': 4.0,
  'face': 3.5,
  'denoise': 3.0,
  'unblur': 2.5,
  'colorize': 3.0,
  'restore': 4.5,
  'cartoon': 3.5,
  'bg': 4.0,
  'bg_cleanup': 3.5,
};

String getFeatureQuality(String featureId) {
  switch (featureId) {
    case 'auto':
      return 'High Quality';
    case 'upscale':
      return '2x/4x Scale';
    case 'face':
      return 'Face Aware';
    case 'denoise':
      return 'Bilateral Filter';
    case 'unblur':
      return 'Smart Sharpen';
    case 'colorize':
      return 'Color Effect';
    case 'restore':
      return 'Photo Restore';
    case 'cartoon':
      return 'Artistic';
    case 'bg':
      return 'Bokeh Effect';
    case 'bg_cleanup':
      return 'BG Focus';
    default:
      return 'Standard';
  }
}

bool isFeatureFullyOffline(String featureId) => true;
