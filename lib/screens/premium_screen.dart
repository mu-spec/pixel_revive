import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/constants/app_strings.dart';
import 'package:pixel_revive/providers/app_provider.dart';
import 'package:pixel_revive/screens/model_download_screen.dart';
import 'package:pixel_revive/screens/benchmark_screen.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  int _selectedPlanIndex = 1; // Default to Yearly (Best Value)
  late TextEditingController _tokenController;

  @override
  void initState() {
    super.initState();
    final provider = context.read<AppProvider>();
    _tokenController = TextEditingController(text: provider.falToken);
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch $urlString');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    // Plans list with localized translations
    final List<Map<String, dynamic>> plans = [
      {
        'title': AppStrings.getText('weekly', provider.languageCode),
        'price': '\$2.99',
        'period': 'week',
        'tag': null,
        'sub': AppStrings.getText('autoRenews', provider.languageCode),
      },
      {
        'title': AppStrings.getText('yearly', provider.languageCode),
        'price': '\$19.99',
        'period': 'year',
        'tag': AppStrings.getText('bestValue', provider.languageCode),
        'sub': AppStrings.getText('autoRenews', provider.languageCode),
      },
      {
        'title': AppStrings.getText('lifetime', provider.languageCode),
        'price': '\$39.99',
        'period': 'one-time',
        'tag': AppStrings.getText('forever', provider.languageCode),
        'sub': AppStrings.getText('payOnce', provider.languageCode),
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(
          AppStrings.getText('premiumTitle', provider.languageCode),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppColors.goldGradient,
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.gold.withOpacity(0.35),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -24,
                    bottom: -24,
                    child: Icon(
                      Icons.workspace_premium,
                      size: 130,
                      color: Colors.white.withOpacity(0.12),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.star, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'PixelRevive PRO',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                  
                  // AI Model Downloader Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ModelDownloadScreen()),
                        );
                      },
                      icon: const Icon(Icons.download, size: 20),
                      label: const Text('Download AI Models (Offline)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        side: BorderSide(color: AppColors.accent.withOpacity(0.6)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                      Text(
                        AppStrings.getText('subTagline', provider.languageCode),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(
              AppStrings.getText('proBenefitTitle', provider.languageCode),
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 16),
                  
                  // AI Model Downloader Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ModelDownloadScreen()),
                        );
                      },
                      icon: const Icon(Icons.download, size: 20),
                      label: const Text('Download AI Models (Offline)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        side: BorderSide(color: AppColors.accent.withOpacity(0.6)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
            _benefit(Icons.hd, AppStrings.getText('benefit1', provider.languageCode)),
            _benefit(Icons.water_drop_outlined, AppStrings.getText('benefit2', provider.languageCode)),
            _benefit(Icons.all_inclusive, AppStrings.getText('benefit3', provider.languageCode)),
            _benefit(Icons.speed, AppStrings.getText('benefit4', provider.languageCode)),
            _benefit(Icons.photo_library_outlined, AppStrings.getText('benefit5', provider.languageCode)),

            const SizedBox(height: 28),
            Text(
              AppStrings.getText('devSettings', provider.languageCode),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BenchmarkScreen()),
                  );
                },
                icon: const Icon(Icons.speed),
                label: const Text("Performance Benchmark"),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_queue, color: AppColors.success, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        AppStrings.getText('enableCloud', provider.languageCode),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      Switch.adaptive(
                        value: provider.useCloudAi,
                        activeColor: AppColors.success,
                        onChanged: (v) {
                          if (v && provider.falToken.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter your Fal.ai API Token first!'),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            return;
                          }
                          provider.setUseCloudAi(v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    AppStrings.getText('apiDesc', provider.languageCode),
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  
                  // AI Model Downloader Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ModelDownloadScreen()),
                        );
                      },
                      icon: const Icon(Icons.download, size: 20),
                      label: const Text('Download AI Models (Offline)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        side: BorderSide(color: AppColors.accent.withOpacity(0.6)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  TextField(
                    controller: _tokenController,
                    decoration: InputDecoration(
                      hintText: AppStrings.getText('apiHint', provider.languageCode),
                      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                      filled: true,
                      fillColor: AppColors.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'monospace'),
                    obscureText: true,
                    onChanged: (val) {
                      provider.setFalToken(val.trim());
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            Text(
              AppStrings.getText('selectPlan', provider.languageCode),
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 14),

            // Plan list
            ...List.generate(plans.length, (index) {
              final plan = plans[index];
              final isSelected = _selectedPlanIndex == index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedPlanIndex = index);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.surface
                          : AppColors.surface.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.gold
                            : Colors.white.withOpacity(0.06),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: isSelected ? AppColors.gold : AppColors.textMuted,
                          size: 20,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    plan['title'],
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: isSelected
                                          ? FontWeight.w800
                                          : FontWeight.bold,
                                    ),
                                  ),
                                  if (plan['tag'] != null) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: AppColors.gold.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        plan['tag'],
                                        style: const TextStyle(
                                          color: AppColors.gold,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                plan['sub'],
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              plan['price'],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '/${plan['period']}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 16),
                  
                  // AI Model Downloader Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ModelDownloadScreen()),
                        );
                      },
                      icon: const Icon(Icons.download, size: 20),
                      label: const Text('Download AI Models (Offline)'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        side: BorderSide(color: AppColors.accent.withOpacity(0.6)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: provider.isPremium
                    ? null
                    : () => _unlockPremium(provider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.black,
                  disabledBackgroundColor: AppColors.card,
                  disabledForegroundColor: AppColors.textMuted,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  provider.isPremium
                      ? AppStrings.getText('premiumActive', provider.languageCode)
                      : AppStrings.getText('unlockPremium', provider.languageCode),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (provider.isPremium)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => provider.setPremium(false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: BorderSide(color: Colors.white.withOpacity(0.1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Restore Free (For Testing)'),
                ),
              ),
            const SizedBox(height: 24),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  AppStrings.getText('billingNotice', provider.languageCode),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 🌐 Clickable Play Store-compliant Terms and Privacy Links
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => _launchURL('https://clinquant-bombolone-e37a29.netlify.app/'),
                  child: const Text(
                    'Terms of Service',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Text('|', style: TextStyle(color: AppColors.card, fontSize: 11)),
                const SizedBox(width: 16),
                GestureDetector(
                  onTap: () => _launchURL('https://earnest-liger-072f0b.netlify.app/'),
                  child: const Text(
                    'Privacy Policy',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _benefit(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.check, color: AppColors.gold, size: 16),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _unlockPremium(AppProvider provider) {
    provider.setPremium(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.workspace_premium, color: AppColors.gold),
            const SizedBox(width: 12),
            Text(AppStrings.getText('localUnlockSnack', provider.languageCode)),
          ],
        ),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}