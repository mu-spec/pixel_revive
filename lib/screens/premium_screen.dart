import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pixel_revive/constants/app_colors.dart';
import 'package:pixel_revive/constants/app_strings.dart';
import 'package:pixel_revive/providers/app_provider.dart';
import 'package:pixel_revive/services/cloud_api_config.dart';
import 'package:pixel_revive/services/iap_service.dart';
import 'package:pixel_revive/services/ad_mob_service.dart';
import 'package:pixel_revive/services/app_telemetry_service.dart';
import 'package:pixel_revive/screens/batch_process_screen.dart';

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
        'sub': AppStrings.getText('autoRenews', provider.languageCode),
      },
      {
        'id': IapService.yearlyId,
        'title': AppStrings.getText('yearly', provider.languageCode),
        'period': 'year',
        'sub': AppStrings.getText('autoRenews', provider.languageCode),
      },
      {
        'id': IapService.lifetimeId,
        'title': AppStrings.getText('lifetime', provider.languageCode),
        'period': 'one-time',
        'sub': AppStrings.getText('payOnce', provider.languageCode),
      },
    ];

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        title: const Text('PixelRevive PRO', style: TextStyle(fontWeight: FontWeight.w900)),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.appBackgroundGradient),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _simpleHero(provider),
              const SizedBox(height: 18),
              _simpleBenefits(),
              const SizedBox(height: 18),
              _simpleCloudControls(context, provider),
              const SizedBox(height: 18),
              _buildPremiumBatchCard(context, provider),
              const SizedBox(height: 22),
              if (!provider.isPremium) ...[
                const Text(
                  'Choose your plan',
                  style: TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                ...List.generate(plans.length, (index) => _simplePlanCard(plans[index], index)),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: provider.isPremium || _isPurchasing
                      ? null
                      : () => _onUnlockPressed(provider, plans),
                  icon: Icon(provider.isPremium ? Icons.check_circle : Icons.workspace_premium),
                  label: Text(
                    provider.isPremium ? 'Premium Active' : 'Unlock Premium',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.success.withOpacity(0.20),
                    disabledForegroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton.icon(
                  onPressed: _isPurchasing ? null : () => IapService.instance.restorePurchases(),
                  icon: const Icon(Icons.restore, size: 18, color: AppColors.textMuted),
                  label: Text(
                    AppStrings.getText('restorePurchases', provider.languageCode),
                    style: const TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (IapService.instance.isTestMode && !provider.isPremium) ...[
                const SizedBox(height: 8),
                _testingHint(),
              ],
              if (_showDevSettings) ...[
                const SizedBox(height: 18),
                _buildDevSettings(provider),
              ],
              const SizedBox(height: 18),
              Center(
                child: Text(
                  IapService.instance.hasRealProducts
                      ? AppStrings.getText('paymentTerms', provider.languageCode)
                      : AppStrings.getText('billingNotice', provider.languageCode),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _simpleHero(AppProvider provider) {
    return GestureDetector(
      onTap: () {
        _devModeTapCount++;
        if (_devModeTapCount == 5) {
          _devModeTapCount = 0;
          setState(() => _showDevSettings = true);
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
              content: Text('🔒 ${5 - _devModeTapCount} more taps'),
              duration: const Duration(milliseconds: 650),
            ),
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.goldGradient,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.gold.withOpacity(0.28),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), shape: BoxShape.circle),
                  child: const Icon(Icons.workspace_premium, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    provider.isPremium ? 'Premium Active' : 'Unlock Premium',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'No watermark, HD export, 4x upscale, batch AI and premium cloud models.',
              style: TextStyle(color: Colors.white, fontSize: 14, height: 1.45, fontWeight: FontWeight.w600),
            ),
            if (provider.isPremium) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(999)),
                child: const Text('✓ All premium tools unlocked', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _simpleBenefits() {
    const benefits = [
      ['No watermark', Icons.water_drop_outlined],
      ['Save HD with premium AI', Icons.hd_rounded],
      ['4x upscale unlocked', Icons.zoom_out_map_rounded],
      ['Premium colorize model', Icons.palette_outlined],
      ['Batch AI processing', Icons.collections_outlined],
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('What you get', style: TextStyle(color: AppColors.text, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          ...benefits.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.13), borderRadius: BorderRadius.circular(10)),
                      child: Icon(item[1] as IconData, color: AppColors.gold, size: 17),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(item[0] as String, style: const TextStyle(color: AppColors.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _simpleCloudControls(BuildContext context, AppProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.success.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(provider.useCloudAi ? Icons.cloud_done_rounded : Icons.phone_android_rounded,
                  color: provider.useCloudAi ? AppColors.success : AppColors.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  provider.useCloudAi ? 'Cloud AI is ON' : 'Offline mode is ON',
                  style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w900),
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
          if (!provider.isPremium && !CloudApiConfig.cloudAiPremiumOnly) ...[
            const SizedBox(height: 10),
            Text(
              '${provider.remainingCloudCreditsToday} cloud credits left today',
              style: const TextStyle(color: AppColors.gold, fontSize: 12, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: AdMobService.rewardedAdsAvailable
                  ? () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final earned = await AdMobService.showRewardedForCloudCredit();
                      if (earned) {
                        await provider.addRewardedCloudCredit();
                        await AppTelemetryService.logEvent('rewarded_cloud_credit_earned');
                        messenger.showSnackBar(const SnackBar(content: Text('+1 cloud credit added')));
                      } else {
                        AdMobService.preloadRewarded();
                        messenger.showSnackBar(const SnackBar(content: Text('Rewarded ad is not ready yet. Try again soon.')));
                      }
                    }
                  : null,
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: const Text('Watch ad for +1 cloud credit'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gold,
                side: const BorderSide(color: AppColors.gold),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _simplePlanCard(Map<String, dynamic> plan, int index) {
    final isSelected = _selectedPlanIndex == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => setState(() => _selectedPlanIndex = index),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.gold.withOpacity(0.12) : AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: isSelected ? AppColors.gold : Colors.white.withOpacity(0.08), width: isSelected ? 2 : 1),
          ),
          child: Row(
            children: [
              Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? AppColors.gold : AppColors.textMuted),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan['title'], style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w900, fontSize: 14.5)),
                    const SizedBox(height: 3),
                    Text(plan['sub'], style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(IapService.instance.priceFor(plan['id']), style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w900)),
                  Text('/${plan['period']}', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _testingHint() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withOpacity(0.25)),
      ),
      child: const Text(
        'Testing note: tap “PixelRevive PRO” at the top 5 times to reveal the Premium test switch.',
        style: TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.35),
      ),
    );
  }

  Widget _buildPremiumBatchCard(BuildContext context, AppProvider provider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.gold.withOpacity(0.34), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.22), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.gold.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.photo_library_outlined, color: AppColors.gold, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppStrings.getText('batchTitle', provider.languageCode),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w900),
                      ),
                    ),
                    const Icon(Icons.workspace_premium, color: AppColors.gold, size: 16),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  AppStrings.getText('premiumBatchSub', provider.languageCode),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: provider.isPremium
                ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BatchProcessScreen()))
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.white,
              disabledBackgroundColor: AppColors.card,
              disabledForegroundColor: AppColors.textMuted,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Open', style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
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