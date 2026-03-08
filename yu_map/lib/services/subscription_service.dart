// lib/services/subscription_service.dart
import 'dart:io';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:yu_map/core/config/app_config.dart';

class SubscriptionService {
  static const String _premiumEntitlement = 'premium';

  Future<void> initialize() async {
    if (!AppConfig.isRevenueCatConfigured) return;

    await Purchases.setLogLevel(LogLevel.debug);

    final apiKey = Platform.isAndroid
        ? AppConfig.revenueCatKeyAndroid
        : AppConfig.revenueCatKeyIos;

    final configuration = PurchasesConfiguration(apiKey);
    await Purchases.configure(configuration);
  }

  Future<bool> isPremiumUser() async {
    if (!AppConfig.isRevenueCatConfigured) return false;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[_premiumEntitlement]?.isActive ??
          false;
    } catch (e) {
      return false;
    }
  }

  Future<void> purchasePremium() async {
    if (!AppConfig.isRevenueCatConfigured) return;
    try {
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.monthly;
      if (package != null) {
        await Purchases.purchasePackage(package);
      }
    } catch (_) {
      // Purchase cancelled or failed — handled by caller.
    }
  }

  /// Listen for premium status changes via RevenueCat listener callback.
  void listenToPremiumStatus(void Function(bool) callback) {
    if (!AppConfig.isRevenueCatConfigured) return;
    Purchases.addCustomerInfoUpdateListener((info) {
      callback(
        info.entitlements.all[_premiumEntitlement]?.isActive ?? false,
      );
    });
  }
}
