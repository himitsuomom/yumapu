import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/services/subscription_service.dart';

/// Singleton SubscriptionService instance.
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});

/// Whether the current user has an active premium subscription.
final isPremiumProvider = FutureProvider.autoDispose<bool>((ref) async {
  final service = ref.read(subscriptionServiceProvider);
  return service.isPremiumUser();
});
