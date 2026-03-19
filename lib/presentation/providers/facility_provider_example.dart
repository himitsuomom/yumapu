// lib/presentation/providers/facility_provider_example.dart
// Example of how to use Result<T> pattern in state providers

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/services/analytics_service.dart';
import 'package:yu_map/core/result/result.dart';
import 'package:yu_map/core/logger/app_logger.dart';

/// Facility service provider
/// TODO: Initialize with actual Supabase client from your main.dart or app setup
// final facilityServiceProvider = Provider((ref) {
//   return FacilityService(ref.watch(supabaseClientProvider));
// });

/// Analytics service provider
final analyticsServiceProvider = Provider((ref) {
  return AnalyticsService();
});

/// Example: Async provider that uses Result<T> pattern
/// NOTE: This is commented out because facilityServiceProvider is not fully initialized
/// Uncomment and implement the facilityServiceProvider above to use this
// final facilitiesAsyncProvider = FutureProvider.autoDispose
//     .family<List<Facility>?, String?>((ref, searchQuery) async {
//   final facilityService = ref.watch(facilityServiceProvider);
//   
//   final result = await facilityService.searchFacilities(
//     searchQuery: searchQuery,
//   );
//
//   // Pattern matching to extract data or throw error
//   return switch (result) {
//     Success(:final data) => data,
//     Failure(:final exception) => throw exception,
//   };
// });

/// Example: Method calling service with Result<T>
Future<void> logFacilityView(
  WidgetRef ref,
  String facilityId,
  String facilityName,
) async {
  final analytics = ref.read(analyticsServiceProvider);

  final result = await analytics.logFacilityView(
    facilityId: facilityId,
    facilityName: facilityName,
    facilityType: 'onsen',
    viewDuration: const Duration(seconds: 30),
  );

  // Handle Result type
  switch (result) {
    case Success():
      AppLogger.info('Facility view logged', tag: 'Analytics');
    case Failure(:final exception):
      AppLogger.error('Failed to log facility view', tag: 'Analytics', error: exception);
  }
}

/// Example: Combining multiple service calls
/// NOTE: This is commented out because subscriptionServiceProvider is not fully initialized
// final premiumStatusProvider = FutureProvider.autoDispose((ref) async {
//   final subscriptionService = ref.watch(subscriptionServiceProvider);
//   
//   final result = await subscriptionService.isPremiumUser();
//
//   return switch (result) {
//     Success(:final data) => data,
//     Failure(:final exception) => throw exception,
//   };
// });

/// Subscription service provider
/// TODO: Initialize with actual SubscriptionService instance
// final subscriptionServiceProvider = Provider((ref) {
//   return SubscriptionService();
// });
