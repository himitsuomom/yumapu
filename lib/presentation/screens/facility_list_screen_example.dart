// lib/presentation/screens/facility_list_screen_example.dart
// This is an example of how to implement a screen using the refactored services
// All code is commented out and needs proper setup to use

// Example provider for facility list state management
// NOTE: This is currently commented out because facilityServiceProvider throws UnimplementedError
// Implement proper initialization in your main.dart or app setup to use this
// final facilityListProvider = StateNotifierProvider.autoDispose<
//     FacilityListNotifier,
//     FacilityListState>((ref) {
//   final facilityService = ref.watch(facilityServiceProvider);
//   return FacilityListNotifier(facilityService);
// });

// Facility service provider - needs implementation
// final facilityServiceProvider = Provider((ref) {
//   // Replace with actual Supabase client initialization
//   throw UnimplementedError('Initialize with your SupabaseClient');
// });

// NOTE: The following classes are commented out and need proper imports to function
// Uncomment and implement when you're ready to use this example
/*
class FacilityListState {
  final bool isLoading;
  final String? errorMessage;
  final List<Facility>? facilities;

  FacilityListState({
    this.isLoading = false,
    this.errorMessage,
    this.facilities,
  });

  FacilityListState copyWith({
    bool? isLoading,
    String? errorMessage,
    List<Facility>? facilities,
  }) {
    return FacilityListState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      facilities: facilities ?? this.facilities,
    );
  }
}

class FacilityListNotifier extends StateNotifier<FacilityListState> {
  final FacilityService _facilityService;

  FacilityListNotifier(this._facilityService)
      : super(FacilityListState());

  Future<void> searchFacilities({String? query}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    
    // Using Result<T> pattern with runCatching
    final result = await _facilityService.searchFacilities(
      searchQuery: query,
    );

    // Pattern matching on Result type
    switch (result) {
      case Success(:final data):
        AppLogger.info('Facilities loaded: ${data.length} items', tag: 'FacilityListNotifier');
        state = state.copyWith(
          isLoading: false,
          facilities: data,
          errorMessage: null,
        );
      case Failure(:final exception):
        AppLogger.error('Failed to load facilities', tag: 'FacilityListNotifier', error: exception);
        state = state.copyWith(
          isLoading: false,
          errorMessage: exception.message,
        );
    }
  }

  Future<void> retry() => searchFacilities();
}

/// Example screen implementation
class FacilityListScreen extends ConsumerWidget {
  const FacilityListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(facilityListProvider);
    final notifier = ref.read(facilityListProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Yu-Map'),
      ),
      body: AsyncStateView<List<Facility>>(
        isLoading: state.isLoading,
        errorMessage: state.errorMessage,
        data: state.facilities,
        isEmpty: state.facilities?.isEmpty ?? true,
        builder: (context, facilities) {
          return ListView.builder(
            itemCount: facilities.length,
            itemBuilder: (context, index) {
              final facility = facilities[index];
              return FacilityListItem(facility: facility);
            },
          );
        },
        onRetry: notifier.retry,
      ),
    );
  }
}

class FacilityListItem extends StatelessWidget {
  final Facility facility;

  const FacilityListItem({super.key, required this.facility});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        title: Text(facility.name),
        subtitle: Text('${facility.latitude}, ${facility.longitude}'),
      ),
    );
  }
}
*/

