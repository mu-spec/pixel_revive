import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/constants/app_strings.dart';
import 'package:pixel_revive/providers/app_provider.dart';
import 'package:pixel_revive/screens/demo_comparison_screen.dart';
import 'package:pixel_revive/screens/editor_screen.dart';
import 'package:pixel_revive/screens/premium_screen.dart';
import 'package:pixel_revive/screens/tabs/ai_lab_tab.dart';
import 'package:pixel_revive/screens/tabs/saved_images_tab.dart';
import 'package:pixel_revive/screens/tabs/settings_tab.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final PageController _showcaseController = PageController(viewportFraction: 0.92);
  Timer? _showcaseTimer;
  int _showcaseIndex = 0;

  @override
  void initState() {
    super.initState();
    _showcaseTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_showcaseController.hasClients) return;
      final next = (_showcaseIndex + 1) % 3;
      _showcaseController.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _showcaseTimer?.cancel();
    _showcaseController.dispose();
    super.dispose();
  }

  List<Widget> _buildTabs(AppProvider provider) => [
        _buildHomeTab(provider),
        const AiLabTab(),
        const SavedImagesTab(),
        const SettingsTab(),
      ];

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      extendBody: true,
      backgroundColor: AppColors.primary,
      appBar: null,
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.appBackgroundGradient),
        child: SafeArea(
          child: IndexedStack(
            index: _currentIndex,
            children: _buildTabs(provider),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        decoration: BoxDecoration(
          color: AppColors.glass,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.32),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            backgroundColor: Colors.transparent,
            selectedItemColor: AppColors.cyan,
            unselectedItemColor: AppColors.textMuted,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            onTap: (index) => setState(() => _currentIndex = index),
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.auto_fix_high_outlined),
                activeIcon: const Icon(Icons.auto_fix_high),
                label: AppStrings.getText('tabAiLab', provider.languageCode),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.collections_outlined),
                activeIcon: const Icon(Icons.collections),
                label: AppStrings.getText('tabSaved', provider.languageCode),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.settings_outlined),
                activeIcon: const Icon(Icons.settings),
                label: AppStrings.getText('tabSettings', provider.languageCode),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab(AppProvider provider) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 92),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PixelRevive',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.2,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Restore, enhance, unblur and upscale photos with AI.',
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PremiumScreen()),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: AppColors.goldGradient),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, size: 12, color: Colors.white),
                      SizedBox(width: 5),
                      Text(
                        'PRO',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildShowcaseCarousel(provider),
          const SizedBox(height: 16),
          _buildFunEffectsSection(provider),
          const SizedBox(height: 16),
          _buildPhotoPickerCard(provider),
        ],
      ),
    );
  }

  Widget _buildShowcaseCarousel(AppProvider provider) {
    final items = [
      {
        'title': 'Enhance',
        'subtitle': 'Improve photo quality',
        'type': 'restore',
        'featureId': 'auto',
        'desc': AppStrings.getText('showcase1Desc', provider.languageCode),
        'before': 'assets/images/demo_restore_before.webp',
        'after': 'assets/images/demo_restore_after.webp',
      },
      {
        'title': 'HD Upscale',
        'subtitle': 'Make low-res photos sharper',
        'type': 'upscale',
        'featureId': 'upscale',
        'desc': AppStrings.getText('showcase2Desc', provider.languageCode),
        'before': 'assets/images/demo_upscale_before.webp',
        'after': 'assets/images/demo_upscale_after.webp',
      },
      {
        'title': 'Background Blur',
        'subtitle': 'Add portrait-style bokeh',
        'type': 'blur',
        'featureId': 'bg',
        'desc': AppStrings.getText('showcase3Desc', provider.languageCode),
        'before': 'assets/images/demo_blur_before.webp',
        'after': 'assets/images/demo_blur_after.webp',
      },
    ];

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PageView.builder(
            controller: _showcaseController,
            physics: const BouncingScrollPhysics(),
            itemCount: items.length,
            onPageChanged: (index) => setState(() => _showcaseIndex = index),
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _showcaseCard(items[index]),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(items.length, (index) {
            final selected = _showcaseIndex == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: selected ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: selected ? AppColors.accent : Colors.white.withOpacity(0.20),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _showcaseCard(Map<String, String> item) {
    return InkWell(
      borderRadius: BorderRadius.circular(32),
      onTap: () => _chooseSourceAndGo(item['featureId'] ?? 'auto'),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white.withOpacity(0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.32),
              blurRadius: 24,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Row(
                children: [
                  Expanded(child: Image.asset(item['before']!, fit: BoxFit.cover, height: double.infinity)),
                  Container(width: 1.6, color: Colors.white.withOpacity(0.80)),
                  Expanded(child: Image.asset(item['after']!, fit: BoxFit.cover, height: double.infinity)),
                ],
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.20),
                        Colors.transparent,
                        Colors.black.withOpacity(0.76),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 18,
                left: 18,
                child: Text(
                  AppStrings.appName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                  ),
                ),
              ),
              Positioned(
                left: 18,
                right: 18,
                bottom: 22,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item['title']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            item['subtitle']!,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 14)],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Try now',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(width: 5),
                          Icon(Icons.arrow_forward_ios_rounded, color: AppColors.accent, size: 15),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFunEffectsSection(AppProvider provider) {
    final effects = [
      {'id': 'age_progression', 'title': 'Age Progression', 'icon': Icons.elderly_rounded, 'color': AppColors.gold},
      {'id': 'baby_version', 'title': 'Baby Version', 'icon': Icons.child_care_rounded, 'color': AppColors.accentLight},
      {'id': 'background_change', 'title': 'Background Change', 'icon': Icons.landscape_rounded, 'color': AppColors.accent},
      {'id': 'broccoli_haircut', 'title': 'Broccoli Haircut', 'icon': Icons.face_retouching_natural, 'color': AppColors.success},
      {'id': 'cartoon', 'title': 'Cartoonify', 'icon': Icons.brush_rounded, 'color': AppColors.cyan},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fun AI Effects', style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: effects.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 2.55,
          ),
          itemBuilder: (context, index) {
            final effect = effects[index];
            final color = effect['color'] as Color;
            return InkWell(
              onTap: () => _chooseSourceAndGo(effect['id'] as String),
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: color.withOpacity(0.25)),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 12, offset: const Offset(0, 6))],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                      child: Icon(effect['icon'] as IconData, color: color, size: 20),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        effect['title'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.text, fontSize: 12.2, fontWeight: FontWeight.w900, height: 1.1),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPhotoPickerCard(AppProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.add_photo_alternate_outlined, size: 34, color: AppColors.accent),
          const SizedBox(height: 10),
          Text(
            AppStrings.getText('selectPhoto', provider.languageCode),
            style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.getText('importBlurry', provider.languageCode),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _pickAndGo(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(AppStrings.getText('gallery', provider.languageCode)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickAndGo(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(AppStrings.getText('camera', provider.languageCode)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.text,
                    side: BorderSide(color: Colors.white.withOpacity(0.14)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<Map<String, dynamic>?> _chooseAgeGenderOptions(String featureId) async {
    String gender = 'male';
    String ageValue = featureId == 'baby_version' ? 'baby' : 'senior';

    final ageOptions = featureId == 'baby_version'
        ? <Map<String, String>>[
            {'label': 'Baby', 'value': 'baby', 'prompt': 'a cute baby portrait, preserve facial identity, realistic photo'},
            {'label': 'Toddler', 'value': 'toddler', 'prompt': 'a cute toddler portrait, preserve facial identity, realistic photo'},
            {'label': 'Preschool', 'value': 'preschool', 'prompt': 'a cute preschool child portrait, preserve facial identity, realistic photo'},
          ]
        : <Map<String, String>>[
            {'label': 'Teen', 'value': 'teen', 'prompt': 'as a teenager, preserve facial identity, realistic photo'},
            {'label': 'Adult', 'value': 'adult', 'prompt': 'as a 30 year old adult, preserve facial identity, realistic photo'},
            {'label': 'Middle Age', 'value': 'mid', 'prompt': '20 years older, middle aged, preserve facial identity, realistic photo'},
            {'label': 'Senior', 'value': 'senior', 'prompt': '40 years older, senior, preserve facial identity, realistic photo'},
          ];

    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final selected = ageOptions.firstWhere((e) => e['value'] == ageValue);
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(999)))),
                    const SizedBox(height: 18),
                    Text(
                      featureId == 'baby_version' ? 'Baby Version Options' : 'Age Progression Options',
                      style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 16),
                    const Text('Gender', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _optionChip('Male', gender == 'male', () => setSheetState(() => gender = 'male')),
                        const SizedBox(width: 10),
                        _optionChip('Female', gender == 'female', () => setSheetState(() => gender = 'female')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Target age', style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ageOptions.map((item) {
                        final isSelected = item['value'] == ageValue;
                        return InkWell(
                          onTap: () => setSheetState(() => ageValue = item['value']!),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.accent.withOpacity(0.18) : AppColors.primary,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: isSelected ? AppColors.accent : Colors.white10),
                            ),
                            child: Text(
                              item['label']!,
                              style: TextStyle(color: isSelected ? AppColors.accent : AppColors.textMuted, fontWeight: FontWeight.w800),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(sheetContext, {
                          'gender': gender,
                          'age_group': ageValue,
                          'prompt': selected['prompt'],
                        }),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                        child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _optionChip(String text, bool selected, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent.withOpacity(0.18) : AppColors.primary,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AppColors.accent : Colors.white10),
          ),
          child: Text(text, style: TextStyle(color: selected ? AppColors.accent : AppColors.textMuted, fontWeight: FontWeight.w900)),
        ),
      ),
    );
  }

  Future<String?> _chooseBackgroundPrompt() async {
    final options = <Map<String, String>>[
      {'title': 'Beach', 'prompt': 'beautiful beach sunset with palm trees, realistic lighting'},
      {'title': 'Office', 'prompt': 'modern professional office background, realistic lighting'},
      {'title': 'Forest', 'prompt': 'lush green forest background, natural daylight'},
      {'title': 'Studio', 'prompt': 'clean professional studio background, soft lighting'},
      {'title': 'City', 'prompt': 'modern city street background, realistic urban lighting'},
    ];

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(999)))),
              const SizedBox(height: 18),
              const Text('Choose background', style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              ...options.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => Navigator.pop(context, item['prompt']),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white10)),
                        child: Text(item['title']!, style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseSourceAndGo(String featureId) async {
    if (featureId == 'age_progression' || featureId == 'baby_version') {
      final options = await _chooseAgeGenderOptions(featureId);
      if (options == null) return;
      context.read<AppProvider>().setPendingEffectExtraInput(options);
    }

    if (featureId == 'background_change') {
      final prompt = await _chooseBackgroundPrompt();
      if (prompt == null) return;
      context.read<AppProvider>().setBackgroundChangePrompt(prompt);
      context.read<AppProvider>().setPendingEffectExtraInput({'prompt': prompt});
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(999))),
              const SizedBox(height: 18),
              const Text('Select photo source', style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Camera'),
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.text, side: BorderSide(color: Colors.white.withOpacity(0.14)), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null) await _pickAndGo(source, featureId: featureId);
  }

  Future<void> _pickAndGo(ImageSource source, {String? featureId}) async {
    final provider = context.read<AppProvider>();
    await provider.pickImage(source);
    if (!mounted || provider.originalImage == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(initialFeatureId: featureId)),
    );
  }
}
