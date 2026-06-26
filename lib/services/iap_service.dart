import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:in_app_purchase/in_app_purchase.dart';

/// =============================================
/// IN-APP PURCHASE SERVICE
/// =============================================
/// Real Google Play / App Store billing for Premium subscriptions.
///
/// HOW IT WORKS:
/// 1. `init()` connects to the store, listens to the purchase stream, and
///    loads product details.
/// 2. `buyProduct(id)` opens the native Google Play purchase sheet.
/// 3. Verified purchases flip the user to Premium via `onEntitlementChanged`.
/// 4. `restorePurchases()` re-grants Premium on reinstall (policy-required).
///
/// PRODUCT IDS must match EXACTLY what you create later in Play Console:
///   Monetize → Products → Subscriptions  → "premium_weekly", "premium_yearly"
///   Monetize → Products → In-app products → "premium_lifetime"
///
/// Until those products exist (no $25 Play account yet), the app runs in
/// TEST MODE: it shows fallback prices and never contacts the store.
/// No code change is needed when the products go live — `queryProductDetails`
/// will simply find them.
/// =============================================

typedef EntitlementCallback = void Function(bool isPremium);

class IapService {
  IapService._();
  static final IapService instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  // ── PRODUCT IDS ─────────────────────────────────────
  static const String weeklyId = 'premium_weekly';
  static const String yearlyId = 'premium_yearly';
  static const String lifetimeId = 'premium_lifetime';

  /// Subscriptions (auto-renewing). Queried separately per store rules.
  static const Set<String> subscriptionIds = {weeklyId, yearlyId};

  /// One-time, non-consumable purchase (pay once, own forever).
  static const Set<String> nonConsumableIds = {lifetimeId};

  // ── STATE ───────────────────────────────────────────
  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _available = false;
  bool _initialized = false;
  EntitlementCallback? onEntitlementChanged;

  /// Loaded real product details from the store. Empty until Play products exist.
  final Map<String, ProductDetails> _products = {};

  /// Human-readable status messages for the UI ("Purchase canceled", etc.).
  final ValueNotifier<String?> statusMessage = ValueNotifier(null);

  // ── FALLBACK PRICES (used in TEST MODE, before Play products exist) ──
  static const Map<String, _Fallback> _fallbacks = {
    weeklyId: _Fallback(price: '\$2.99', title: 'Weekly'),
    yearlyId: _Fallback(price: '\$19.99', title: 'Yearly Premium'),
    lifetimeId: _Fallback(price: '\$39.99', title: 'Lifetime Ultra'),
  };

  // ── PUBLIC GETTERS ──────────────────────────────────
  /// Is the platform billing store reachable at all?
  bool get isStoreAvailable => _available;

  /// Have real Play Console products been loaded yet?
  bool get hasRealProducts => _products.isNotEmpty;

  /// True when running without configured products (test/dev mode).
  bool get isTestMode => !hasRealProducts;

  Map<String, ProductDetails> get products => _products;

  /// Real store price if available, otherwise the PRD fallback price.
  String priceFor(String id) =>
      _products[id]?.price ?? _fallbacks[id]?.price ?? '';

  /// Display title for a plan (real store title or fallback).
  String titleFor(String id) =>
      _products[id]?.title.split('(').first.trim() ??
      _fallbacks[id]?.title ??
      id;

  // ── INITIALIZATION ──────────────────────────────────
  Future<void> init({
    required EntitlementCallback onEntitlementChanged,
  }) async {
    if (_initialized) return;
    _initialized = true;
    this.onEntitlementChanged = onEntitlementChanged;

    _available = await _iap.isAvailable();
    debugPrint('🛒 IAP store available: $_available');

    _sub = _iap.purchaseStream.listen(
      _onPurchaseUpdated,
      onError: (Object e) => debugPrint('🛒 IAP stream error: $e'),
    );

    if (_available) {
      await _loadProducts();
      // Re-grant entitlement for returning users on every launch.
      await restorePurchases();
    } else {
      _message('Store not connected — running in test mode.');
    }
  }

  Future<void> _loadProducts() async {
    _products.clear();
    final subsResponse = await _iap.queryProductDetails(subscriptionIds);
    final oneTimeResponse = await _iap.queryProductDetails(nonConsumableIds);
    // Convert List<ProductDetails> to Map<String, ProductDetails>
    for (final product in subsResponse.productDetails) {
      _products[product.id] = product;
    }
    for (final product in oneTimeResponse.productDetails) {
      _products[product.id] = product;
    }

    if (subsResponse.notFoundIDs.isNotEmpty ||
        oneTimeResponse.notFoundIDs.isNotEmpty) {
      debugPrint(
        '🛒 Products not yet configured: '
        '${subsResponse.notFoundIDs} ${oneTimeResponse.notFoundIDs}. '
        'Create them in Play Console (premium_weekly/premium_yearly/premium_lifetime).',
      );
    }
    debugPrint('🛒 Loaded ${_products.length} real product(s): ${_products.keys}');
  }

  // ── PURCHASE STREAM ─────────────────────────────────
  void _onPurchaseUpdated(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      _handlePurchase(purchase);
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    switch (purchase.status) {
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        if (_isVerified(purchase)) {
          onEntitlementChanged?.call(true);
          _message(purchase.status == PurchaseStatus.restored
              ? 'Premium restored. Welcome back!'
              : 'Premium activated. Thank you! 🎉');
        } else {
          _message('Purchase could not be verified.');
        }
        break;
      case PurchaseStatus.error:
        _message(purchase.error?.message ?? 'Purchase failed.');
        debugPrint('🛒 purchase error: ${purchase.error?.message}');
        break;
      case PurchaseStatus.canceled:
        _message('Purchase canceled.');
        break;
      case PurchaseStatus.pending:
        _message('Purchase pending…');
        break;
    }

    // ALWAYS finish the purchase so it is not stuck pending in the store.
    if (purchase.pendingCompletePurchase) {
      try {
        await _iap.completePurchase(purchase);
      } catch (e) {
        debugPrint('🛒 completePurchase failed: $e');
      }
    }
  }

  /// Basic verification. For full production security, forward
  /// `purchase.verificationData.serverVerificationData` to your backend and
  /// validate against Google Play Developer API before granting entitlement.
  bool _isVerified(PurchaseDetails purchase) {
    final data = purchase.verificationData;
    if (data == null) return true; // sandbox / test purchases
    final server = data.serverVerificationData;
    return server.isNotEmpty;
  }

  // ── ACTIONS ─────────────────────────────────────────
  /// Initiates a real purchase for the given plan id.
  /// Returns true if the Play sheet was shown; the final outcome arrives via
  /// the purchase stream (and updates Premium through the provider).
  Future<bool> buyProduct(String productId) async {
    if (!_available) {
      _message('Store not available. Connect Google Play Billing to buy.');
      return false;
    }
    final details = _products[productId];
    if (details == null) {
      _message(
        'Plan not found in the store yet. Create "$productId" in Play Console, '
        'or use the dev Premium toggle to test.',
      );
      return false;
    }

    final purchaseParam = PurchaseParam(productDetails: details);
    try {
      // Subscriptions and one-time non-consumables are both bought this way;
      // the store treats them according to their configured type.
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } on InAppPurchaseException catch (e) {
      _message(e.message ?? 'Purchase failed.');
      debugPrint('🛒 buyProduct error: ${e.message}');
      return false;
    } catch (e) {
      _message('Unexpected purchase error: $e');
      debugPrint('🛒 buyProduct error: $e');
      return false;
    }
  }

  /// Re-queries prior purchases and re-grants entitlement. Required by Google.
  Future<void> restorePurchases() async {
    if (!_available) {
      _message('Store not available.');
      return;
    }
    await _iap.restorePurchases();
    debugPrint('🛒 restorePurchases called');
  }

  void _message(String msg) {
    statusMessage.value = msg;
    debugPrint('🛒 $msg');
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }
}

class _Fallback {
  final String price;
  final String title;
  const _Fallback({required this.price, required this.title});
}