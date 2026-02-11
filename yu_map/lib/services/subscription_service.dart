// lib/services/subscription_service.dart
import 'dart:io';
import 'package:purchases_flutter/purchases_flutter.dart';

class SubscriptionService {
  static const String _premiumEntitlement = 'premium';
  StreamSubscription<CustomerInfo>? _customerInfoSubscription;

  Future<void> initialize() async {
    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration configuration;
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration('revenuecat_android_key');
    } else {
      configuration = PurchasesConfiguration('revenuecat_ios_key');
    }

    await Purchases.configure(configuration);
  }

  Future<bool> isPremiumUser() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[_premiumEntitlement]?.isActive ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> purchasePremium() async {
    try {
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.monthly;

      if (package != null) {
        await Purchases.purchasePackage(package);
      }
    } catch (e) {
      // Handle error
    }
  }

  Stream<bool> get premiumStatusStream {
    return Purchases.customerInfoStream.map(
      (info) => info.entitlements.all[_premiumEntitlement]?.isActive ?? false,
    );
  }
  
  // Dispose method to properly remove customer info listener and prevent memory leaks
  void dispose() {
    _customerInfoSubscription?.cancel();
    _customerInfoSubscription = null;
  }
}
