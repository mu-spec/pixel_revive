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
    final String localizedTitle =
        AppStrings.getText('feat_${feature.id}_title', provider.languageCode);
    final String localizedSub =
        AppStrings.getText('feat_${feature.id}_sub', provider.languageCode);

    String? badgeText;
    Color badgeColor = AppColors.success;
    if (feature.id == 'upscale' || feature.id == 'restore') {
      badgeText = 'HD AI';
      badgeColor = AppColors.gold;
    } else if (feature.id == 'auto') {
      badgeText = '1-TAP';
      badgeColor = AppColors.rose;
    } else if (feature.id == 'face' || feature.id == 'bg_cleanup') {
      badgeText = 'AI';
      badgeColor = AppColors.cyan;
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: AppColors.cardGradient,
        border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: feature.color.withOpacity(0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: feature.color.withOpacity(0.12),
            highlightColor: Colors.white.withOpacity(0.04),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(feature.imagePath, fit: BoxFit.cover),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.02),
                          Colors.black.withOpacity(0.12),
                          AppColors.primary.withOpacity(0.62),
                          AppColors.primary.withOpacity(0.92),
                        ],
                        stops: const [0.0, 0.35, 0.72, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.36),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: Icon(feature.icon, color: feature.color, size: 21),
                  ),
                ),
                if (badgeText != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: badgeColor.withOpacity(0.95),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: badgeColor.withOpacity(0.26),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        localizedTitle,
                        style: const TextStyle(
                          color: AppColors.text,
                          fontSize: 15.2,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.25,
                          height: 1.05,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        localizedSub,
                        style: const TextStyle(
                          color: AppColors.textSoft,
                          fontSize: 11.2,
                          height: 1.28,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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
