// lib/services/subscription_service.dart
import 'dart:async';
import 'dart:io';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:yu_map/core/result/result.dart';
import 'package:yu_map/core/result/run_catching.dart';

class SubscriptionService {
  static const String _premiumEntitlement = 'premium';
  StreamSubscription<CustomerInfo>? _customerInfoSubscription;

  Future<void> initialize() async {
    await Purchases.setLogLevel(LogLevel.info);

    PurchasesConfiguration configuration;
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration('revenuecat_android_key');
    } else {
      configuration = PurchasesConfiguration('revenuecat_ios_key');
    }

    await Purchases.configure(configuration);
  }

  Future<Result<bool>> isPremiumUser() async {
    return runCatching(() async {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[_premiumEntitlement]?.isActive ?? false;
    });
  }

  Future<Result<void>> purchasePremium() async {
    return runCatching(() async {
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.monthly;

      if (package != null) {
        await Purchases.purchase(PurchaseParams.package(package));
      }
    });
  }

  // Properly assign listener to _customerInfoSubscription field to prevent memory leaks
  // Note: customerInfoStream is not available in this version of purchases_flutter
  // For real-time updates, poll isPremiumUser() or use platform-specific listeners
  // void listenToPremiumStatus(void Function(bool) callback) {
  //   _customerInfoSubscription = Purchases.customerInfoStream.listen(
  //     (info) {
  //       callback(info.entitlements.all[_premiumEntitlement]?.isActive ?? false);
  //     },
  //   );
  // }

  // Stream<bool> get premiumStatusStream {
  //   return Purchases.customerInfoStream.map(
  //     (info) => info.entitlements.all[_premiumEntitlement]?.isActive ?? false,
  //   );
  // }

  // Dispose the subscription to prevent memory leaks
  void dispose() {
    _customerInfoSubscription?.cancel();
    _customerInfoSubscription = null;
  }
}
