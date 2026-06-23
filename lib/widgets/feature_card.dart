import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/constants/app_strings.dart';
import 'package:pixel_revive/models/feature_item.dart';
import 'package:pixel_revive/providers/app_provider.dart';

class FeatureCard extends StatelessWidget {
  final FeatureItem feature;
  final VoidCallback onTap;

  const FeatureCard({
    super.key,
    required this.feature,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    // Dynamic localized texts
    final String localizedTitle = AppStrings.getText('feat_${feature.id}_title', provider.languageCode);
    final String localizedSub = AppStrings.getText('feat_${feature.id}_sub', provider.languageCode);

    // Determine badges or tags for specific features
    String? badgeText;
    Color badgeColor = AppColors.success;
    if (feature.id == 'upscale' || feature.id == 'restore') {
      badgeText = 'PRO';
      badgeColor = AppColors.gold;
    } else if (feature.id == 'auto') {
      badgeText = 'BEST';
      badgeColor = const Color(0xFFEC4899); // Rose Pink
    } else if (feature.id == 'face' || feature.id == 'bg') {
      badgeText = 'AI';
      badgeColor = AppColors.success;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: feature.color.withOpacity(0.12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Top Portion: Beautiful high-definition thumbnail photo representing the feature
                Expanded(
                  flex: 11,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        feature.imagePath,
                        fit: BoxFit.cover,
                      ),
                      // Soft black vignette overlay at bottom of the image for premium blending
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.transparent,
                                AppColors.surface.withOpacity(0.8),
                                AppColors.surface,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Corner tag badge (PRO, BEST, AI)
                      if (badgeText != null)
                        Positioned(
                          top: 10,
                          right: 10,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: badgeColor,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: badgeColor.withOpacity(0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              badgeText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // 2. Bottom Portion: Detailed textual specifications
                Expanded(
                  flex: 7,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            Icon(
                              feature.icon,
                              color: feature.color,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                localizedTitle,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          localizedSub,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 10.5,
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}