import 'package:flutter/material.dart';
import 'package:pixel_revive/constants/app_colors.dart';

class FeatureItem {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String imagePath;

  const FeatureItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.imagePath,
  });
}

final List<FeatureItem> allFeatures = [
  FeatureItem(
    id: 'auto',
    title: 'Auto Enhance',
    subtitle: 'Fix colors, contrast & sharpness',
    icon: Icons.auto_fix_high,
    color: AppColors.success,
    imagePath: 'assets/images/thumb_auto.png',
  ),
  FeatureItem(
    id: 'upscale',
    title: 'HD Upscale',
    subtitle: '2x / 4x enlarge without blur',
    icon: Icons.hd,
    color: AppColors.gold,
    imagePath: 'assets/images/thumb_upscale.png',
  ),
  FeatureItem(
    id: 'face',
    title: 'Face Enhance',
    subtitle: 'Sharpen & smooth faces',
    icon: Icons.face,
    color: AppColors.accentLight,
    imagePath: 'assets/images/thumb_face.png',
  ),
  FeatureItem(
    id: 'denoise',
    title: 'Denoise',
    subtitle: 'Remove grain & noise',
    icon: Icons.grain,
    color: AppColors.text,
    imagePath: 'assets/images/thumb_denoise.png',
  ),
  FeatureItem(
    id: 'unblur',
    title: 'Unblur',
    subtitle: 'Reduce motion & soft blur',
    icon: Icons.deblur,
    color: AppColors.success,
    imagePath: 'assets/images/thumb_unblur.png',
  ),
  FeatureItem(
    id: 'colorize',
    title: 'Colorize B&W',
    subtitle: 'Add warm color to old photos',
    icon: Icons.palette,
    color: AppColors.accent,
    imagePath: 'assets/images/thumb_colorize.png',
  ),
  FeatureItem(
    id: 'restore',
    title: 'Old Photo Restore',
    subtitle: 'Fix faded, sepia & scratches',
    icon: Icons.restore,
    color: AppColors.gold,
    imagePath: 'assets/images/thumb_restore.png',
  ),
  FeatureItem(
    id: 'cartoon',
    title: 'Cartoon Effect',
    subtitle: 'Artistic edge & color pop',
    icon: Icons.brush,
    color: AppColors.accentLight,
    imagePath: 'assets/images/thumb_cartoon.png',
  ),
  FeatureItem(
    id: 'bg',
    title: 'Background Blur',
    subtitle: 'Blur background, keep face sharp',
    icon: Icons.blur_on,
    color: AppColors.text,
    imagePath: 'assets/images/thumb_bg.png',
  ),
  FeatureItem(
    id: 'bg_cleanup',
    title: 'BG Cleanup',
    subtitle: 'Remove background distractions',
    icon: Icons.cleaning_services,
    color: AppColors.success,
    imagePath: 'assets/images/thumb_bg.png',
  ),
];