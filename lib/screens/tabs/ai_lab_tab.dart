import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/constants/app_strings.dart';
import 'package:pixel_revive/models/feature_item.dart';
import 'package:pixel_revive/providers/app_provider.dart';
import 'package:pixel_revive/screens/editor_screen.dart';
import 'package:pixel_revive/screens/demo_comparison_screen.dart';
import 'package:pixel_revive/widgets/feature_card.dart';
import 'package:pixel_revive/widgets/ad_banner.dart';

class AiLabTab extends StatelessWidget {
  const AiLabTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 110),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroPromoCard(context, provider),
          const SizedBox(height: 16),
          _buildShowcaseGallery(context, provider),
          const SizedBox(height: 28),
          _buildPhotoSection(context, provider),
          const SizedBox(height: 28),
          _buildFeaturesTitle(context, provider),
          const SizedBox(height: 16),
          _buildFeaturesGrid(context),
          const AdBanner(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeroPromoCard(BuildContext context, AppProvider provider) {
    final bool isCloudActive = provider.useCloudAi && provider.isCloudAiAvailable;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isCloudActive ? AppColors.goldGradient : AppColors.brandGradient,
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: (isCloudActive ? AppColors.gold : AppColors.accent).withOpacity(0.26),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -32,
            bottom: -32,
            child: Icon(
              Icons.blur_circular,
              size: 160,
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    isCloudActive ? AppStrings.getText('cloudBadge', provider.languageCode) : AppStrings.getText('onDeviceBadge', provider.languageCode),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isCloudActive
                      ? AppStrings.getText('cloudHeadline', provider.languageCode)
                      : AppStrings.getText('subTagline', provider.languageCode),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.55,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isCloudActive
                      ? AppStrings.getText('cloudDesc', provider.languageCode)
                      : AppStrings.getText('onDeviceHeroDesc', provider.languageCode),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13.2,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowcaseGallery(BuildContext context, AppProvider provider) {
    final List<Map<String, String>> showcaseItems = [
      {
        'title': AppStrings.getText('showcase1Title', provider.languageCode),
        'subtitle': AppStrings.getText('showcase1Sub', provider.languageCode),
        'type': 'restore',
        'desc': AppStrings.getText('showcase1Desc', provider.languageCode),
      },
      {
        'title': AppStrings.getText('showcase2Title', provider.languageCode),
        'subtitle': AppStrings.getText('showcase2Sub', provider.languageCode),
        'type': 'upscale',
        'desc': AppStrings.getText('showcase2Desc', provider.languageCode),
      },
      {
        'title': AppStrings.getText('showcase3Title', provider.languageCode),
        'subtitle': AppStrings.getText('showcase3Sub', provider.languageCode),
        'type': 'blur',
        'desc': AppStrings.getText('showcase3Desc', provider.languageCode),
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              AppStrings.getText('showcaseTitle', provider.languageCode),
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.3,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.touch_app_rounded, color: AppColors.accent, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    AppStrings.getText('tapToCompare', provider.languageCode),
                    style: const TextStyle(
                      color: AppColors.accent,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: showcaseItems.length,
            itemBuilder: (context, index) {
              final item = showcaseItems[index];
              return Container(
                width: 210,
                margin: const EdgeInsets.only(right: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.black.withOpacity(0.05),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DemoComparisonScreen(
                              type: item['type']!,
                              title: item['title']!,
                              description: item['desc']!,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                item['type'] == 'restore'
                                    ? Icons.restore
                                    : item['type'] == 'upscale'
                                        ? Icons.hd
                                        : Icons.blur_on,
                                color: AppColors.accent,
                                size: 20,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              item['title']!,
                              style: const TextStyle(
                                color: AppColors.text,
                                fontSize: 13.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item['subtitle']!,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 11,
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
        ),
      ],
    );
  }

  Widget _buildPhotoSection(BuildContext context, AppProvider provider) {
    if (provider.originalImage == null) {
      return _buildEmptyPhotoSection(context, provider);
    }
    return _buildPhotoPreview(context, provider);
  }

  Widget _buildEmptyPhotoSection(BuildContext context, AppProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.black.withOpacity(0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.accent.withOpacity(0.1),
                  AppColors.accent.withOpacity(0.02),
                ],
              ),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accent.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.add_photo_alternate_outlined,
              size: 40,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            AppStrings.getText('selectPhoto', provider.languageCode),
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.getText('importBlurry', provider.languageCode),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.brandGradient,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _pickAndGo(context, ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined, size: 18),
                    label: Text(
                      AppStrings.getText('gallery', provider.languageCode),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickAndGo(context, ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: Text(
                    AppStrings.getText('camera', provider.languageCode),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: BorderSide(color: Colors.black.withOpacity(0.15)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoPreview(BuildContext context, AppProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.black.withOpacity(0.05),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                provider.originalImage!,
                height: 240,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickAndGo(context, ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: Text(
                    AppStrings.getText('changePhoto', provider.languageCode),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: BorderSide(color: Colors.black.withOpacity(0.1)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.brandGradient,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.2),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _goToEditor(context, provider),
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: Text(
                      AppStrings.getText('aiEditor', provider.languageCode),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturesTitle(BuildContext context, AppProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.getText('chooseFeature', provider.languageCode),
          style: const TextStyle(
            color: AppColors.text,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          AppStrings.getText('onDevice', provider.languageCode),
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturesGrid(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 18,
        crossAxisSpacing: 18,
        childAspectRatio: 0.82,
      ),
      itemCount: allFeatures.length,
      itemBuilder: (context, index) {
        final feature = allFeatures[index];
        return FeatureCard(
          feature: feature,
          onTap: () => _onFeatureTapped(context, feature.id),
        );
      },
    );
  }

  Future<void> _pickAndGo(BuildContext context, ImageSource source) async {
    final provider = context.read<AppProvider>();
    await provider.pickImage(source);
    if (provider.originalImage != null && context.mounted) {
      _goToEditor(context, provider);
    }
  }

  void _goToEditor(BuildContext context, AppProvider provider) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditorScreen()),
    );
  }

  Future<void> _onFeatureTapped(BuildContext context, String featureId) async {
    final provider = context.read<AppProvider>();
    if (provider.originalImage == null) {
      await _pickAndGo(context, ImageSource.gallery);
      if (provider.originalImage == null) return;
    }
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EditorScreen(initialFeatureId: featureId),
        ),
      );
    }
  }
}