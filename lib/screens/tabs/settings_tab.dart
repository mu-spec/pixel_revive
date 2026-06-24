import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/providers/app_provider.dart';
import 'package:pixel_revive/screens/language_screen.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // 1. Language Row
            _buildSettingsRow(
              context: context,
              icon: Icons.g_translate,
              iconColor: AppColors.success,
              title: 'App Language',
              subtitle: provider.languageCode.toUpperCase(),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LanguageScreen(isFromSettings: true)),
                );
              },
            ),
            const SizedBox(height: 14),

            // 2. Share App Row
            _buildSettingsRow(
              context: context,
              icon: Icons.share,
              iconColor: AppColors.accent,
              title: 'Share with Friends',
              subtitle: 'Spread the word about PixelRevive',
              onTap: () {
                provider.shareImage();
              },
            ),
            const SizedBox(height: 14),

            // 3. Rate Us Row
            _buildSettingsRow(
              context: context,
              icon: Icons.thumb_up_alt_outlined,
              iconColor: AppColors.gold,
              title: 'Rate Us',
              subtitle: 'Support us on the Play Store',
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Thank you! Real Play Store page connection is coming soon.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
            ),
            const SizedBox(height: 14),

            // 4. Terms of Service Row
            _buildSettingsRow(
              context: context,
              icon: Icons.gavel,
              iconColor: Colors.blueAccent,
              title: 'Terms of Service',
              subtitle: 'Read our legal guidelines',
              onTap: () => _launchURL('https://clinquant-bombolone-e37a29.netlify.app/'),
            ),
            const SizedBox(height: 14),

            // 5. Privacy Policy Row
            _buildSettingsRow(
              context: context,
              icon: Icons.privacy_tip_outlined,
              iconColor: Colors.purpleAccent,
              title: 'Privacy Policy',
              subtitle: 'Read our data handling rules',
              onTap: () => _launchURL('https://earnest-liger-072f0b.netlify.app/'),
            ),
            
            const SizedBox(height: 60),

            // 6. App Version Details
            Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                      )
                    ]
                  ),
                  child: const Icon(Icons.auto_fix_high, color: AppColors.accent, size: 28),
                ),
                const SizedBox(height: 14),
                const Text(
                  'PixelRevive AI Photo Studio',
                  style: TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Version 1.0.0 (Build 1)',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsRow({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.black.withOpacity(0.04),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppColors.text,
                        fontSize: 14.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.textMuted, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}