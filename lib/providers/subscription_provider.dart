import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/services/subscription_service.dart';

// ── State ────────────────────────────────────────────────────────────────────

class SubscriptionState {
  final bool isPremium;
  final bool isLoading;
  final String? error;

  const SubscriptionState({
    this.isPremium = false,
    this.isLoading = false,
    this.error,
  });

  SubscriptionState copyWith({
    bool? isPremium,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return SubscriptionState(
      isPremium: isPremium ?? this.isPremium,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  SubscriptionNotifier(this._service) : super(const SubscriptionState()) {
    _init();
  }

  final SubscriptionService _service;

  Future<void> _init() async {
    if (!mounted) return;
    state = state.copyWith(isLoading: true);
    final isPremium = await _service.isPremiumUser();
    if (!mounted) return;
    state = state.copyWith(isPremium: isPremium, isLoading: false);

    _service.listenToPremiumStatus((isPremium) {
      if (mounted) state = state.copyWith(isPremium: isPremium);
    });
  }

  Future<void> purchaseMonthly() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _service.purchaseMonthly();
      final isPremium = await _service.isPremiumUser();
      if (mounted) {
        state = state.copyWith(isPremium: isPremium, isLoading: false);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  Future<void> restorePurchases() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final isPremium = await _service.restorePurchases();
      if (mounted) {
        state = state.copyWith(isPremium: isPremium, isLoading: false);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }
}

// ── Providers ────────────────────────────────────────────────────────────────

final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});

final subscriptionProvider =
    StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier(ref.read(subscriptionServiceProvider));
});
