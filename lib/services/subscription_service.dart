import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:yu_map/core/config/app_config.dart';

/// Manages RevenueCat subscriptions.
///
/// All methods are no-ops when [AppConfig.isRevenueCatConfigured] is false,
/// so the app never shows broken purchase UI.
class SubscriptionService {
  static const String _premiumEntitlement = 'premium';

  /// Initialise the RevenueCat SDK. Call once at app startup.
  Future<void> initialize() async {
    if (!AppConfig.isRevenueCatConfigured) return;

    await Purchases.setLogLevel(
      kDebugMode ? LogLevel.debug : LogLevel.error,
    );

    final apiKey = defaultTargetPlatform == TargetPlatform.iOS
        ? AppConfig.revenueCatKeyIos
        : AppConfig.revenueCatKeyAndroid;

    await Purchases.configure(PurchasesConfiguration(apiKey));
  }

  /// Returns true if the current user has an active premium entitlement.
  Future<bool> isPremiumUser() async {
    if (!AppConfig.isRevenueCatConfigured) return false;
    try {
      final info = await Purchases.getCustomerInfo();
      return info.entitlements.all[_premiumEntitlement]?.isActive ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Purchases the current offering's monthly package.
  /// No-op when RevenueCat is not configured or purchase is cancelled.
  Future<void> purchaseMonthly() async {
    if (!AppConfig.isRevenueCatConfigured) return;
    try {
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.monthly;
      if (package != null) {
        await Purchases.purchase(PurchaseParams.package(package));
      }
    } catch (_) {
      // Purchase cancelled or failed — caller handles UI feedback.
    }
  }

  /// Restores previous purchases.
  Future<bool> restorePurchases() async {
    if (!AppConfig.isRevenueCatConfigured) return false;
    try {
      final info = await Purchases.restorePurchases();
      return info.entitlements.all[_premiumEntitlement]?.isActive ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Registers [callback] to be called whenever the customer's premium
  /// status changes (e.g. subscription renewed or expired).
  void listenToPremiumStatus(void Function(bool isPremium) callback) {
    if (!AppConfig.isRevenueCatConfigured) return;
    Purchases.addCustomerInfoUpdateListener((info) {
      callback(info.entitlements.all[_premiumEntitlement]?.isActive ?? false);
    });
  }
}
