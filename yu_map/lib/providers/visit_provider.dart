import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/providers/auth_provider.dart';

/// Visit (check-in) record.
class Visit {
  final String id;
  final String facilityId;
  final String userId;
  final DateTime visitedAt;

  const Visit({
    required this.id,
    required this.facilityId,
    required this.userId,
    required this.visitedAt,
  });

  factory Visit.fromJson(Map<String, dynamic> json) {
    return Visit(
      id: json['id'] as String,
      facilityId: json['facility_id'] as String,
      userId: json['user_id'] as String,
      visitedAt: DateTime.parse(json['visited_at'] as String),
    );
  }
}

/// All visits for the current user.
final userVisitsProvider =
    FutureProvider.autoDispose<List<Visit>>((ref) async {
  final session = ref.watch(sessionProvider);
  if (session == null) return [];
  final client = ref.read(supabaseClientProvider);
  final data = await client
      .from('visits')
      .select()
      .eq('user_id', session.user.id)
      .order('visited_at', ascending: false);
  return (data as List).map((r) => Visit.fromJson(r)).toList();
});

/// Set of facility IDs the user has visited.
final visitedFacilityIdsProvider =
    FutureProvider.autoDispose<Set<String>>((ref) async {
  final visits = await ref.watch(userVisitsProvider.future);
  return visits.map((v) => v.facilityId).toSet();
});

/// Check-in action.
class CheckInNotifier extends StateNotifier<AsyncValue<void>> {
  CheckInNotifier(this._ref) : super(const AsyncData(null));
  final Ref _ref;

  Future<bool> checkIn(String facilityId) async {
    final session = _ref.read(sessionProvider);
    if (session == null) {
      state = AsyncError('ログインが必要です', StackTrace.current);
      return false;
    }
    state = const AsyncLoading();
    try {
      final client = _ref.read(supabaseClientProvider);
      await client.from('visits').insert({
        'user_id': session.user.id,
        'facility_id': facilityId,
      });
      _ref.invalidate(userVisitsProvider);
      _ref.invalidate(visitedFacilityIdsProvider);
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final checkInProvider =
    StateNotifierProvider<CheckInNotifier, AsyncValue<void>>((ref) {
  return CheckInNotifier(ref);
});
