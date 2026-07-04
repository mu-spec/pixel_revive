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

  final List<Widget> _tabs = const [
    AiLabTab(),
    SavedImagesTab(),
    SettingsTab(),
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
            children: _tabs,
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
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: [
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
