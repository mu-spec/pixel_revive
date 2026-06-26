import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/constants/app_strings.dart';
import 'package:pixel_revive/providers/app_provider.dart';
import 'package:pixel_revive/screens/onboarding_screen.dart';
import 'package:pixel_revive/screens/home_screen.dart';

class LanguageScreen extends StatefulWidget {
  final bool isFromSettings;

  const LanguageScreen({super.key, this.isFromSettings = false});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  String _selectedLangCode = 'en';
  String _searchQuery = '';

  final List<Map<String, String>> _languages = [
    {'name': 'English', 'nativeName': 'English', 'code': 'en', 'flag': '🇬🇧'},
    {'name': 'Spanish', 'nativeName': 'Español', 'code': 'es', 'flag': '🇪🇸'},
    {'name': 'French', 'nativeName': 'Français', 'code': 'fr', 'flag': '🇫🇷'},
    {'name': 'German', 'nativeName': 'Deutsch', 'code': 'de', 'flag': '🇩🇪'},
    {'name': 'Urdu', 'nativeName': 'اردو', 'code': 'ur', 'flag': '🇵🇰'},
    {'name': 'Arabic', 'nativeName': 'العربية', 'code': 'ar', 'flag': '🇸🇦'},
  ];

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    _selectedLangCode = provider.languageCode;
  }

  Future<void> _onConfirm() async {
    final provider = context.read<AppProvider>();
    provider.setLanguageCode(_selectedLangCode);

    if (widget.isFromSettings) {
      Navigator.pop(context);
    } else {
      // If first launch, route to onboarding next!
      final prefs = await SharedPreferences.getInstance();
      final bool isFirstLaunch = prefs.getBool('is_first_launch') ?? true;

      if (mounted) {
        if (isFirstLaunch) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    // Filtered languages based on search query
    final filteredLanguages = _languages.where((lang) {
      final name = lang['name']!.toLowerCase();
      final native = lang['nativeName']!.toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || native.contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(
          AppStrings.getText('chooseLanguage', provider.languageCode),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        elevation: 0,
        automaticallyImplyLeading: widget.isFromSettings,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: TextField(
                onChanged: (val) {
                  setState(() => _searchQuery = val);
                },
                decoration: InputDecoration(
                  hintText: AppStrings.getText('searchLanguage', provider.languageCode),
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),

            Expanded(
              child: filteredLanguages.isEmpty
                  ? Center(
                      child: Text(
                        AppStrings.getText('noLanguagesFound', provider.languageCode),
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 1.35,
                      ),
                      itemCount: filteredLanguages.length,
                      itemBuilder: (context, index) {
                        final lang = filteredLanguages[index];
                        final isSelected = _selectedLangCode == lang['code'];

                        return GestureDetector(
                          onTap: () {
                            setState(() => _selectedLangCode = lang['code']!);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.surface
                                  : AppColors.surface.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.accent
                                    : Colors.white.withOpacity(0.05),
                                width: isSelected ? 2 : 1.2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppColors.accent.withOpacity(0.15),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : [],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      lang['flag']!,
                                      style: const TextStyle(fontSize: 22),
                                    ),
                                    if (isSelected)
                                      const Icon(
                                        Icons.check_circle,
                                        color: AppColors.accent,
                                        size: 18,
                                      ),
                                  ],
                                ),
                                const Spacer(),
                                Text(
                                  lang['nativeName']!,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lang['name']!,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Confirm Button
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.brandGradient,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      AppStrings.getText('confirm', provider.languageCode),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}