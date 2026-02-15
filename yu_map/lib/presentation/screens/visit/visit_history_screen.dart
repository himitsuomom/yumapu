// lib/presentation/screens/visit/visit_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:yu_map/providers/service_providers.dart';

/// Provider for the current user's visit history.
final _visitHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final visitService = ref.watch(visitServiceProvider);
  return visitService.getVisitHistory();
});

class VisitHistoryScreen extends ConsumerWidget {
  const VisitHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_visitHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('訪問履歴')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (visits) {
          if (visits.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.place_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'まだ訪問記録がありません',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '施設でチェックインしてみましょう!',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: visits.length,
            itemBuilder: (context, index) {
              final visit = visits[index];
              final facility =
                  visit['facilities'] as Map<String, dynamic>? ?? {};
              final facilityName = facility['name'] as String? ?? '不明な施設';
              final facilityId = facility['id'] as String?;
              final address = facility['address'] as String?;
              final visitedAt = visit['visited_at'] as String?;
              final verified = visit['verified'] as bool? ?? false;

              String dateStr = '';
              if (visitedAt != null) {
                dateStr = DateFormat('yyyy/MM/dd HH:mm')
                    .format(DateTime.parse(visitedAt).toLocal());
              }

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: verified
                        ? Colors.green.shade100
                        : Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      verified ? Icons.verified : Icons.hot_tub,
                      color: verified ? Colors.green : null,
                    ),
                  ),
                  title: Text(facilityName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (address != null)
                        Text(
                          address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: facilityId != null
                      ? () => context.push('/facility/$facilityId')
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
