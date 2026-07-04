import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/constants/app_strings.dart';
import 'package:pixel_revive/providers/app_provider.dart';
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

  List<Widget> _buildTabs(AppProvider provider) => [
        _buildMainMenu(provider),
        const AiLabTab(),
        const SavedImagesTab(),
        const SettingsTab(),
      ];

  Widget _buildMainMenu(AppProvider provider) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 120),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: AppColors.brandGradient),
                borderRadius: BorderRadius.circular(32),
                boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.35), blurRadius: 28, offset: const Offset(0, 14))],
              ),
              child: const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 54),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.appName,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.text, fontSize: 34, fontWeight: FontWeight.w900, letterSpacing: -1.0),
            ),
            const SizedBox(height: 10),
            const Text(
              'Restore, enhance, unblur and upscale photos with AI.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 14, height: 1.45, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () => setState(() => _currentIndex = 1),
                icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
                label: const Text('Open AI Lab', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton.icon(
                onPressed: () => setState(() => _currentIndex = 2),
                icon: const Icon(Icons.collections_rounded),
                label: const Text('My Creations', style: TextStyle(fontWeight: FontWeight.w800)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.text,
                  side: BorderSide(color: Colors.white.withOpacity(0.14)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, size: 10, color: Colors.white),
                            SizedBox(width: 4),
                            Text('PRO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
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
            )
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
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
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
}