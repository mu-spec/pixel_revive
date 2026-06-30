import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/constants/app_strings.dart';
import 'package:pixel_revive/providers/app_provider.dart';
import 'package:pixel_revive/screens/language_screen.dart';
import 'package:pixel_revive/services/ump_consent_service.dart';

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
    final lang = provider.languageCode;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: Text(
          AppStrings.getText('settingsTitle', lang),
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.appBackgroundGradient),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
          child: Column(
          children: [
            // 1. Language Row
            _buildSettingsRow(
              context: context,
              icon: Icons.g_translate,
              iconColor: AppColors.success,
              title: AppStrings.getText('appLanguage', lang),
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
              title: AppStrings.getText('shareFriends', lang),
              subtitle: AppStrings.getText('shareFriendsSub', lang),
              onTap: () {
                Share.share(
                  'Check out PixelRevive - AI Photo Restore & Enhance! Restore your old and faded photos instantly completely offline.\n\nDownload now: https://play.google.com/store/apps/details?id=com.pixelrevive.app',
                  subject: 'PixelRevive AI Photo Studio',
                );
              },
            ),
            const SizedBox(height: 14),

            // 3. Rate Us Row
            _buildSettingsRow(
              context: context,
              icon: Icons.thumb_up_alt_outlined,
              iconColor: AppColors.gold,
              title: AppStrings.getText('rateUs', lang),
              subtitle: AppStrings.getText('rateUsSub', lang),
              onTap: () => _launchURL('https://play.google.com/store/apps/details?id=com.pixelrevive.app'),
            ),
            const SizedBox(height: 14),

            // 4. Terms of Service Row
            _buildSettingsRow(
              context: context,
              icon: Icons.gavel,
              iconColor: Colors.blueAccent,
              title: AppStrings.getText('terms', lang),
              subtitle: AppStrings.getText('termsSub', lang),
              onTap: () => _launchURL('https://stately-bienenstitch-ece6f1.netlify.app/'),
            ),
            const SizedBox(height: 14),

            // 5. Privacy Policy Row
            _buildSettingsRow(
              context: context,
              icon: Icons.privacy_tip_outlined,
              iconColor: Colors.purpleAccent,
              title: AppStrings.getText('privacy', lang),
              subtitle: AppStrings.getText('privacySub', lang),
              onTap: () => _launchURL('https://luminous-daifuku-28d714.netlify.app/'),
            ),
            if (UmpConsentService.privacyOptionsRequired) ...[
              const SizedBox(height: 14),
              _buildSettingsRow(
                context: context,
                icon: Icons.admin_panel_settings_outlined,
                iconColor: AppColors.success,
                title: 'Ad privacy choices',
                subtitle: 'Manage personalized ads consent',
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final success = await UmpConsentService.showPrivacyOptionsForm();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Ad privacy choices updated'
                            : 'Ad privacy choices are not available right now',
                      ),
                    ),
                  );
                },
              ),
            ],
            
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
                Text(
                  AppStrings.getText('appNameFull', lang),
                  style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.bold),
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
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.10), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 18,
            offset: const Offset(0, 10),
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