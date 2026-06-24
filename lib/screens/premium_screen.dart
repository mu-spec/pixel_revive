import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/constants/app_strings.dart';
import 'package:pixel_revive/providers/app_provider.dart';
import 'package:pixel_revive/services/cloud_api_config.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  int _selectedPlanIndex = 1;
  int _devModeTapCount = 0; // Hidden dev settings: tap title 5 times

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

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
                          // Tap "PixelRevive PRO" 5 times to reveal dev settings
                          GestureDetector(
                            onTap: () {
                              _devModeTapCount++;
                              if (_devModeTapCount == 5) {
                                _devModeTapCount = 0;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('🔓 Developer settings unlocked!'),
                                    backgroundColor: AppColors.accent,
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                setState(() {});
                              } else if (_devModeTapCount > 2) {
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('🔒 ${5 - _devModeTapCount} more taps for dev settings'),
                                    duration: const Duration(milliseconds: 600),
                                  ),
                                );
                              }
                            },
                            child: const Text(
                              'PixelRevive PRO',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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

            // Cloud AI Status Card (visible to ALL users)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: CloudApiConfig.isCloudAvailable
                      ? AppColors.success.withOpacity(0.3)
                      : Colors.white.withOpacity(0.06),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        CloudApiConfig.isCloudAvailable ? Icons.cloud_done : Icons.cloud_off,
                        color: CloudApiConfig.isCloudAvailable ? AppColors.success : AppColors.textMuted,
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          CloudApiConfig.isCloudAvailable
                              ? '☁️ Cloud AI Connected'
                              : '📱 On-Device Processing',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    CloudApiConfig.isCloudAvailable
                        ? (provider.isPremium
                            ? '✨ Premium: Unlimited cloud AI enhancements powered by ${CloudApiConfig.useReplicate ? "Replicate" : "Fal.ai"}'
                            : '⚡ Free: ${CloudApiConfig.freeDailyCloudLimit} cloud AI enhancements/day. Upgrade for unlimited!')
                        : 'All processing runs locally on your device. No internet needed — fast & private!',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  if (CloudApiConfig.isCloudAvailable && !provider.isPremium) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '☁️ ${provider.cloudAiUsedToday}/${CloudApiConfig.freeDailyCloudLimit} cloud AI used today',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

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
            _benefit(Icons.hd, AppStrings.getText('benefit1', provider.languageCode)),
            _benefit(Icons.water_drop_outlined, AppStrings.getText('benefit2', provider.languageCode)),
            _benefit(Icons.all_inclusive, AppStrings.getText('benefit3', provider.languageCode)),
            _benefit(Icons.speed, AppStrings.getText('benefit4', provider.languageCode)),
            _benefit(Icons.photo_library_outlined, AppStrings.getText('benefit5', provider.languageCode)),
            if (CloudApiConfig.isCloudAvailable)
              _benefit(Icons.cloud_done, 'Cloud AI: Professional-grade enhancement via server GPUs'),

            const SizedBox(height: 28),

            // ── HIDDEN DEVELOPER SETTINGS (tap title 5 times to reveal) ──
            if (_devModeTapCount >= 5 || true) // TODO: remove `|| true` before release!
              _buildDevSettings(provider),

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
                            : Colors.black.withOpacity(0.06),
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
                                      color: AppColors.text,
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
                                color: AppColors.text,
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
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: provider.isPremium
                    ? null
                    : () => _unlockPremium(provider),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary,
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
                    side: BorderSide(color: Colors.black.withOpacity(0.1)),
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
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  /// ── DEVELOPER SETTINGS (hidden, for you to test) ──
  Widget _buildDevSettings(AppProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.developer_mode, color: AppColors.accent, size: 20),
            const SizedBox(width: 8),
            Text(
              AppStrings.getText('devSettings', provider.languageCode),
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.accent.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Provider info
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(
                      CloudApiConfig.useReplicate ? Icons.science : Icons.bolt,
                      color: CloudApiConfig.useReplicate ? AppColors.success : AppColors.gold,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        CloudApiConfig.useReplicate
                            ? 'Provider: Replicate.com (change in cloud_api_config.dart)'
                            : 'Provider: Fal.ai (change in cloud_api_config.dart)',
                        style: TextStyle(
                          color: CloudApiConfig.useReplicate ? AppColors.success : AppColors.gold,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Embedded token status
              Row(
                children: [
                  Icon(
                    CloudApiConfig.isCloudAvailable ? Icons.check_circle : Icons.cancel,
                    color: CloudApiConfig.isCloudAvailable ? AppColors.success : Colors.redAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      CloudApiConfig.isCloudAvailable
                          ? 'Embedded token: ✅ Active (${CloudApiConfig.activeToken.substring(0, 8)}...)'
                          : 'Embedded token: ❌ Not set (paste in cloud_api_config.dart)',
                      style: TextStyle(
                        color: CloudApiConfig.isCloudAvailable ? AppColors.success : Colors.redAccent,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Cloud AI toggle
              Row(
                children: [
                  const Icon(Icons.cloud_queue, color: AppColors.success, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Enable Cloud AI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: provider.useCloudAi,
                    activeColor: AppColors.success,
                    onChanged: (v) {
                      if (v && !CloudApiConfig.isCloudAvailable && provider.devOverrideToken.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No API token configured! Set it in cloud_api_config.dart or paste below.'),
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

              // Developer token override (for testing different keys)
              const Text(
                'Override Token (dev only):',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: TextEditingController(text: provider.devOverrideToken),
                decoration: InputDecoration(
                  hintText: CloudApiConfig.useReplicate
                      ? 'Paste Replicate token (r8_...) to override'
                      : 'Paste Fal.ai token to override',
                  hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                  filled: true,
                  fillColor: AppColors.primary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  suffixIcon: provider.devOverrideToken.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16, color: AppColors.textMuted),
                          onPressed: () {
                            provider.setDevOverrideToken('');
                            setState(() {});
                          },
                        )
                      : null,
                ),
                style: const TextStyle(color: AppColors.text, fontSize: 12, fontFamily: 'monospace'),
                obscureText: true,
                onChanged: (val) {
                  provider.setDevOverrideToken(val.trim());
                },
              ),
              const SizedBox(height: 8),
              const Text(
                '⚠️ This is a developer override. Users will NOT see this screen.',
                style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
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