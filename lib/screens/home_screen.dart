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
      appBar: _currentIndex == 0
          ? AppBar(
              centerTitle: true,
              title: Text(
                AppStrings.appName,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              actions: [
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PremiumScreen()),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: AppColors.goldGradient),
                          borderRadius: BorderRadius.circular(12),
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
                            Icon(Icons.star, size: 10, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'PRO',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : null,
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
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
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
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 116),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Text(
                  AppStrings.appName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.text,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Restore, enhance, unblur and upscale photos with AI.',
                  textAlign: TextAlign.center,
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
          const SizedBox(height: 20),
          _buildShowcaseCarousel(provider),
          const SizedBox(height: 24),
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
        'desc': AppStrings.getText('showcase1Desc', provider.languageCode),
        'before': 'assets/images/demo_restore_before.webp',
        'after': 'assets/images/demo_restore_after.webp',
      },
      {
        'title': 'HD Upscale',
        'subtitle': 'Make low-res photos sharper',
        'type': 'upscale',
        'desc': AppStrings.getText('showcase2Desc', provider.languageCode),
        'before': 'assets/images/demo_upscale_before.webp',
        'after': 'assets/images/demo_upscale_after.webp',
      },
      {
        'title': 'Background Blur',
        'subtitle': 'Add portrait-style bokeh',
        'type': 'blur',
        'desc': AppStrings.getText('showcase3Desc', provider.languageCode),
        'before': 'assets/images/demo_blur_before.webp',
        'after': 'assets/images/demo_blur_after.webp',
      },
    ];

    return Column(
      children: [
        SizedBox(
          height: 430,
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
        const SizedBox(height: 12),
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
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.0,
                  ),
                ),
              ),
              Positioned(
                top: 18,
                right: 18,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF2563EB)]),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 12)],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 16),
                      SizedBox(width: 5),
                      Text('PRO', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                    ],
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
                              fontSize: 28,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                              fontSize: 15,
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

  Widget _buildPhotoPickerCard(AppProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
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
          const Icon(Icons.add_photo_alternate_outlined, size: 44, color: AppColors.accent),
          const SizedBox(height: 14),
          Text(
            AppStrings.getText('selectPhoto', provider.languageCode),
            style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            AppStrings.getText('importBlurry', provider.languageCode),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 22),
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
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _currentIndex = 1),
            child: Text(
              'Open AI Lab to choose a feature',
              style: TextStyle(color: AppColors.cyan.withOpacity(0.95), fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndGo(ImageSource source) async {
    final provider = context.read<AppProvider>();
    await provider.pickImage(source);
    if (!mounted || provider.originalImage == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditorScreen()),
    );
  }
}