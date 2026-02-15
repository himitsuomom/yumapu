// lib/services/subscription_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:yu_map/core/config/app_config.dart';

class SubscriptionService {
  static const String _premiumEntitlement = 'premium';
  StreamSubscription<CustomerInfo>? _customerInfoSubscription;
  bool _isInitialized = false;

  /// Whether the service has been successfully initialized.
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final apiKey = Platform.isAndroid
        ? AppConfig.revenueCatAndroidKey
        : AppConfig.revenueCatIosKey;

    if (apiKey.isEmpty) {
      debugPrint(
        'RevenueCat API key not configured. '
        'Provide via --dart-define=REVENUECAT_ANDROID_KEY=... or REVENUECAT_IOS_KEY=...',
      );
      return;
    }

    await Purchases.setLogLevel(LogLevel.debug);
    await Purchases.configure(PurchasesConfiguration(apiKey));
    _isInitialized = true;
  }

  Future<bool> isPremiumUser() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[_premiumEntitlement]?.isActive ?? false;
    } catch (e) {
      debugPrint('SubscriptionService.isPremiumUser error: $e');
      return false;
    }
  }

  Future<bool> purchasePremium() async {
    try {
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.monthly;

      if (package != null) {
        await Purchases.purchasePackage(package);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('SubscriptionService.purchasePremium error: $e');
      return false;
    }
  }

  /// Listens to premium status changes.
  /// Safely cancels any existing listener before creating a new one.
  void listenToPremiumStatus(void Function(bool) callback) {
    // Cancel the previous subscription to prevent memory leaks
    _customerInfoSubscription?.cancel();

    _customerInfoSubscription = Purchases.customerInfoStream.listen(
      (info) {
        callback(info.entitlements.all[_premiumEntitlement]?.isActive ?? false);
      },
      onError: (Object error) {
        debugPrint('SubscriptionService stream error: $error');
        callback(false);
      },
    );
  }

  Stream<bool> get premiumStatusStream {
    return Purchases.customerInfoStream.map(
      (info) => info.entitlements.all[_premiumEntitlement]?.isActive ?? false,
    );
  }

  /// Disposes of all subscriptions and cleans up resources.
  void dispose() {
    _customerInfoSubscription?.cancel();
    _customerInfoSubscription = null;
    _isInitialized = false;
  }
}
