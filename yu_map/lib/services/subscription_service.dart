// lib/services/subscription_service.dart
import 'dart:io';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter/foundation.dart';

class SubscriptionService {
  static const String _premiumEntitlement = 'premium';
  static const String _proEntitlement = 'pro';
  
  final Map<String, EntitlementInfo> _cachedEntitlements = {};
  bool _initialized = false;

  Future<void> initialize() async {
    try {
      await Purchases.setLogLevel(LogLevel.debug);
      await Purchases.setDebugLogsEnabled(kDebugMode);

      String apiKey = Platform.isAndroid
          ? String.fromEnvironment('REVENUECAT_ANDROID_API_KEY', defaultValue: 'revenuecat_android_key')
          : String.fromEnvironment('REVENUECAT_IOS_API_KEY', defaultValue: 'revenuecat_ios_key');

      PurchasesConfiguration configuration = PurchasesConfiguration(apiKey);

      await Purchases.configure(configuration);
      
      // Set up customer info listener for updates
      Purchases.addCustomerInfoUpdateListener(_handleCustomerInfoUpdate);
      
      // Load initial customer info
      await _loadCustomerInfo();
      
      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing subscription service: $e');
      // Continue with basic functionality even if RevenueCat fails
    }
  }

  Future<void> _loadCustomerInfo() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _updateCachedEntitlements(customerInfo.entitlements);
    } catch (e) {
      debugPrint('Error loading customer info: $e');
    }
  }

  void _handleCustomerInfoUpdate(CustomerInfo customerInfo) {
    _updateCachedEntitlements(customerInfo.entitlements);
  }

  void _updateCachedEntitlements(EntitlementInfos entitlements) {
    _cachedEntitlements.clear();
    for (final entry in entitlements.all.entries) {
      _cachedEntitlements[entry.key] = entry.value;
    }
  }

  Future<bool> isPremiumUser() async {
    if (!_initialized) return false;
    
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _updateCachedEntitlements(customerInfo.entitlements);
      return customerInfo.entitlements.all[_premiumEntitlement]?.isActive ?? false;
    } catch (e) {
      debugPrint('Error checking premium status: $e');
      return false;
    }
  }

  bool isProUserSync() {
    final entitlement = _cachedEntitlements[_proEntitlement];
    return entitlement?.isActive == true;
  }

  bool hasPremiumSync() {
    final entitlement = _cachedEntitlements[_premiumEntitlement];
    return entitlement?.isActive == true;
  }

  Future<void> purchasePremium() async {
    if (!_initialized) {
      debugPrint('Subscription service not initialized');
      return;
    }
    
    try {
      final offerings = await Purchases.getOfferings();
      final package = offerings.current?.monthly;

      if (package != null) {
        final purchasedCustomerInfo = await Purchases.purchasePackage(package);
        _updateCachedEntitlements(purchasedCustomerInfo.entitlements);
      }
    } catch (e) {
      if (!e.toString().contains('purchase_cancelled')) {
        debugPrint('Error during purchase: $e');
      }
    }
  }

  Future<String?> getExpirationDate() async {
    if (!_initialized) return null;
    
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlement = customerInfo.entitlements.all[_premiumEntitlement];
      return entitlement?.expirationDate?.toString();
    } catch (e) {
      debugPrint('Error getting expiration date: $e');
      return null;
    }
  }

  Stream<bool> get premiumStatusStream {
    if (!_initialized) {
      // Return stream that emits false if not initialized
      return Stream<bool>.value(false);
    }
    
    return Purchases.customerInfoStream.map(
      (info) {
        _updateCachedEntitlements(info.entitlements);
        return info.entitlements.all[_premiumEntitlement]?.isActive ?? false;
      },
    );
  }
  
  Future<void> restorePurchases() async {
    if (!_initialized) return;
    
    try {
      final customerInfo = await Purchases.restorePurchases();
      _updateCachedEntitlements(customerInfo.entitlements);
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
    }
  }
  
  Future<List<String>> getActiveSubscriptions() async {
    if (!_initialized) return [];
    
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final activeSubscriptions = <String>[];
      
      for (final entry in customerInfo.entitlements.all.entries) {
        if (entry.value.isActive) {
          activeSubscriptions.add(entry.key);
        }
      }
      
      return activeSubscriptions;
    } catch (e) {
      debugPrint('Error getting active subscriptions: $e');
      return [];
    }
  }
}
