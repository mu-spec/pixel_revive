import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/constants/app_strings.dart';
import 'package:pixel_revive/providers/app_provider.dart';
import 'package:pixel_revive/services/cloud_api_config.dart';
import 'package:pixel_revive/services/iap_service.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  int _selectedPlanIndex = 1;
  int _devModeTapCount = 0; // Hidden dev settings: tap title 5 times
  bool _showDevSettings = false;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    // Show IAP status messages (success / canceled / errors) as snackbars.
    IapService.instance.statusMessage.addListener(_onIapStatus);
  }

  @override
  void dispose() {
    IapService.instance.statusMessage.removeListener(_onIapStatus);
    super.dispose();
  }

  void _onIapStatus() {
    final msg = IapService.instance.statusMessage.value;
    if (msg == null || msg.isEmpty || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppColors.surface,
            behavior: SnackBarBehavior.floating,
          ),
        );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();

    final List<Map<String, dynamic>> plans = [
      {
        'id': IapService.weeklyId,
        'title': AppStrings.getText('weekly', provider.languageCode),
        'period': 'week',
        'tag': null,
        'sub': AppStrings.getText('autoRenews', provider.languageCode),
      },
      {
        'id': IapService.yearlyId,
        'title': AppStrings.getText('yearly', provider.languageCode),
        'period': 'year',
        'tag': null,
        'sub': AppStrings.getText('autoRenews', provider.languageCode),
      },
      {
        'id': IapService.lifetimeId,
        'title': AppStrings.getText('lifetime', provider.languageCode),
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
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.appBackgroundGradient),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(22, 10, 22, 30),
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
                                setState(() {
                                  _showDevSettings = true;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(AppStrings.getText('devUnlocked', provider.languageCode)),
                                    backgroundColor: AppColors.accent,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              } else if (_devModeTapCount > 2) {
                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('🔒 ${5 - _devModeTapCount} ${AppStrings.getText('devMoreTaps', provider.languageCode)}'),
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

            // ── TEST MODE BANNER (when Play products aren't live yet) ──
            if (IapService.instance.isTestMode)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.gold.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gold.withOpacity(0.4), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.science_outlined, color: AppColors.gold, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          AppStrings.getText('testModeBilling', provider.languageCode),
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Google Play products aren\'t configured yet. After your \$25 Play Developer '
                      'account, create products premium_weekly, premium_yearly, premium_lifetime — '
                      'real billing activates with no code change. To test Premium now, use the '
                      'dev toggle (tap "PixelRevive PRO" 5×).',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),

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
                              ? AppStrings.getText('cloudAiConnected', provider.languageCode)
                              : AppStrings.getText('onDeviceProcessing', provider.languageCode),
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
                            : (CloudApiConfig.cloudAiPremiumOnly
                                ? '☁️ Cloud AI is available for Premium users only. Free users continue with local on-device processing.'
                                : '⚡ Free: ${CloudApiConfig.freeDailyCloudLimit} cloud AI enhancements/day. Upgrade for unlimited!'))
                        : 'All processing runs locally on your device. No internet needed — fast & private!',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  if (CloudApiConfig.isCloudAvailable && !provider.isPremium && !CloudApiConfig.cloudAiPremiumOnly) ...[
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

                  // ── USER-FACING PROCESSING MODE SELECTOR ──────────────
                  // Lets every user clearly choose Offline (on-device) or
                  // Cloud AI. If cloud isn't configured, only offline applies.
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white12, height: 1),
                  const SizedBox(height: 14),
                  Text(
                    AppStrings.getText('processingMode', provider.languageCode),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      // Offline option
                      Expanded(
                        child: _modeOption(
                          context: context,
                          icon: Icons.phone_android_rounded,
                          title: AppStrings.getText('useOffline', provider.languageCode),
                          subtitle: AppStrings.getText('offlineModeDesc', provider.languageCode),
                          selected: !provider.useCloudAi,
                          onTap: () => provider.setUseCloudAi(false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Cloud option
                      Expanded(
                        child: _modeOption(
                          context: context,
                          icon: Icons.cloud_done_rounded,
                          title: AppStrings.getText('useCloudAi', provider.languageCode),
                          subtitle: AppStrings.getText('cloudModeDesc', provider.languageCode),
                          selected: provider.useCloudAi,
                          enabled: CloudApiConfig.isCloudAvailable || provider.devOverrideToken.isNotEmpty,
                          onTap: () {
                            if (!CloudApiConfig.isCloudAvailable && provider.devOverrideToken.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(AppStrings.getText('cloudNotAvailable', provider.languageCode)),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                              return;
                            }
                            provider.setUseCloudAi(true);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.textMuted, size: 15),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppStrings.getText('modeHelp', provider.languageCode),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Text(
                    'Cloud speed / quality',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _modeOption(
                          context: context,
                          icon: Icons.flash_on_rounded,
                          title: 'Fast',
                          subtitle: 'Instant local preview',
                          selected: provider.processingQuality == 'fast',
                          onTap: () => provider.setProcessingQuality('fast'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _modeOption(
                          context: context,
                          icon: Icons.balance_rounded,
                          title: 'Balanced',
                          subtitle: 'Cloud quality • slower',
                          selected: provider.processingQuality == 'balanced',
                          onTap: () => provider.setProcessingQuality('balanced'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _modeOption(
                          context: context,
                          icon: Icons.hd_rounded,
                          title: 'HD',
                          subtitle: provider.isPremium ? 'Best quality • slowest' : 'Premium only',
                          selected: provider.processingQuality == 'hd',
                          enabled: provider.isPremium,
                          onTap: () {
                            if (!provider.isPremium) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('HD quality is a Premium feature.')),
                              );
                              return;
                            }
                            provider.setProcessingQuality('hd');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Text(
                      'Fast mode = instant local Auto/Denoise/Unblur. Balanced/HD = cloud quality and may take 15–60 seconds.',
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10.8,
                        height: 1.35,
                      ),
                    ),
                  ),
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
            if (_showDevSettings)
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
                      gradient: isSelected ? const LinearGradient(colors: [Color(0x3322D3EE), Color(0x227C3AED)]) : AppColors.cardGradient,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.gold
                            : Colors.white.withOpacity(0.10),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected ? AppColors.gold.withOpacity(0.18) : Colors.black.withOpacity(0.18),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
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
                              IapService.instance.priceFor(plan['id']),
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
                onPressed: provider.isPremium || _isPurchasing
                    ? null
                    : () => _onUnlockPressed(provider, plans),
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
                child: _isPurchasing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
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
            // Restore Purchases — required by Google Play policy.
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton.icon(
                onPressed: _isPurchasing ? null : () => IapService.instance.restorePurchases(),
                icon: const Icon(Icons.restore, size: 18, color: AppColors.textMuted),
                label: Text(
                  AppStrings.getText('restorePurchases', provider.languageCode),
                  style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  IapService.instance.hasRealProducts
                      ? AppStrings.getText('paymentTerms', provider.languageCode)
                      : AppStrings.getText('billingNotice', provider.languageCode),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
          ),
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
              // Dev Premium override — test the premium experience without billing.
              Row(
                children: [
                  const Icon(Icons.workspace_premium, color: AppColors.gold, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Premium (dev test)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: provider.isPremium,
                    activeColor: AppColors.gold,
                    onChanged: (v) => provider.setPremium(v),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                'Manually grants Premium for testing. This is NOT a real purchase — '
                'real billing is wired and activates when Play products go live.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              const SizedBox(height: 16),

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
                        CloudApiConfig.useBackendProxy
                            ? 'Provider: ${CloudApiConfig.useReplicate ? "Replicate" : "Fal.ai"} via secure backend proxy'
                            : 'Provider: ${CloudApiConfig.useReplicate ? "Replicate" : "Fal.ai"} direct token fallback',
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
                      CloudApiConfig.useBackendProxy
                          ? 'Backend proxy: ✅ Configured securely'
                          : (CloudApiConfig.isCloudAvailable
                              ? 'Direct token: ✅ Active (${CloudApiConfig.activeToken.substring(0, 8)}...)'
                              : 'Cloud AI: ❌ Not configured. Deploy backend proxy first.'),
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
                          SnackBar(
                            content: Text(AppStrings.getText('noBackendConfigured', provider.languageCode)),
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
                'Override Token (dev testing only):',
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
                '⚠️ Hidden developer-only testing area. Do not rely on direct tokens for production API security.',
                style: TextStyle(color: AppColors.gold, fontSize: 10, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// A tappable card used in the Processing Mode selector (Offline vs Cloud).
  Widget _modeOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool selected,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final Color accent = selected ? AppColors.success : Colors.white24;
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.success.withOpacity(0.12)
                : Colors.white.withOpacity(0.03),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: accent, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon,
                      color: selected ? AppColors.success : Colors.white54,
                      size: 20),
                  const Spacer(),
                  if (selected)
                    const Icon(Icons.check_circle,
                        color: AppColors.success, size: 18),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10.5,
                  height: 1.3,
                ),
              ),
            ],
          ),
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

  Future<void> _onUnlockPressed(
    AppProvider provider,
    List<Map<String, dynamic>> plans,
  ) async {
    final planId = plans[_selectedPlanIndex]['id'] as String;

    setState(() => _isPurchasing = true);

    // Real Google Play billing path.
    final initiated = await IapService.instance.buyProduct(planId);

    if (!initiated && IapService.instance.isTestMode) {
      // No Play products yet: guide the user to the dev toggle for testing.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '🧪 Billing is in test mode. Open Developer settings (tap '
            '"PixelRevive PRO" 5×) to test Premium manually.',
          ),
          backgroundColor: AppColors.surface,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    // Success / cancellation messages arrive via the IAP statusMessage listener.

    if (mounted) setState(() => _isPurchasing = false);
  }
}