import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/config/app_config.dart';

/// Manages subscription state via RevenueCat.
///
/// Safe no-op when RevenueCat keys are not configured.
class SubscriptionProvider extends ChangeNotifier {
  bool _isPremium = false;
  bool _isLoading = false;
  String? _errorMessage;

  bool get isPremium => _isPremium;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isConfigured => AppConfig.isRevenueCatConfigured;

  static const String _entitlement = '湯マップ Pro';

  /// Configure RevenueCat and fetch initial premium status.
  Future<void> initialize() async {
    if (!isConfigured) return;

    _isLoading = true;
    notifyListeners();

    try {
      final apiKey = Platform.isAndroid
          ? AppConfig.revenueCatKeyAndroid
          : AppConfig.revenueCatKeyIos;

      if (apiKey.isEmpty) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      await Purchases.configure(PurchasesConfiguration(apiKey));

      final customerInfo = await Purchases.getCustomerInfo();
      _isPremium =
          customerInfo.entitlements.all[_entitlement]?.isActive ?? false;

      Purchases.addCustomerInfoUpdateListener((info) {
        _isPremium =
            info.entitlements.all[_entitlement]?.isActive ?? false;
        notifyListeners();
      });
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Purchase the monthly plan (product: "monthly").
  Future<void> purchaseMonthly() async {
    await _purchase(isMonthly: true);
  }

  /// Purchase the yearly plan (product: "yearly").
  Future<void> purchaseYearly() async {
    await _purchase(isMonthly: false);
  }

  Future<void> _purchase({required bool isMonthly}) async {
    if (!isConfigured) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final offerings = await Purchases.getOfferings();
      final package =
          isMonthly ? offerings.current?.monthly : offerings.current?.annual;

      if (package == null) {
        _errorMessage = 'プランが見つかりませんでした';
        _isLoading = false;
        notifyListeners();
        return;
      }

      await Purchases.purchasePackage(package);

      final customerInfo = await Purchases.getCustomerInfo();
      _isPremium =
          customerInfo.entitlements.all[_entitlement]?.isActive ?? false;

      if (_isPremium) {
        await _updateSupabasePremiumStatus(true);
      }
    } on PlatformException catch (e) {
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {
        _errorMessage = '購入に失敗しました: ${e.message}';
      }
    } catch (e) {
      _errorMessage = '購入に失敗しました: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Restore previous purchases.
  Future<void> restorePurchases() async {
    if (!isConfigured) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final customerInfo = await Purchases.restorePurchases();
      _isPremium =
          customerInfo.entitlements.all[_entitlement]?.isActive ?? false;

      if (_isPremium) {
        await _updateSupabasePremiumStatus(true);
      }
    } catch (e) {
      _errorMessage = '復元に失敗しました: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear the current error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Sync premium flag to Supabase profiles table.
  Future<void> _updateSupabasePremiumStatus(bool isPremium) async {
    if (!AppConfig.isSupabaseConfigured) return;
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;
      await client
          .from('profiles')
          .update({'is_premium': isPremium}).eq('id', userId);
    } catch (_) {
      // Best-effort sync — don't block purchase flow.
    }
  }
}

/// Riverpod provider for the subscription ChangeNotifier.
final subscriptionProvider =
    ChangeNotifierProvider<SubscriptionProvider>((ref) {
  return SubscriptionProvider();
});

/// Convenience provider — whether the current user has premium.
final isPremiumProvider = Provider<bool>((ref) {
  return ref.watch(subscriptionProvider).isPremium;
});
