// lib/presentation/screens/badge/badge_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/providers/service_providers.dart';

/// Provider for all badges with the user's earned status.
final _userBadgesProvider = FutureProvider<_BadgeData>((ref) async {
  final badgeService = ref.watch(badgeServiceProvider);
  final allBadges = await badgeService.getAllBadges();
  final userBadges = await badgeService.getUserBadges(
    ref.read(supabaseClientProvider).auth.currentUser!.id,
  );

  final earnedCodes = <String>{};
  for (final ub in userBadges) {
    final badge = ub['badges'] as Map<String, dynamic>?;
    if (badge != null) earnedCodes.add(badge['code'] as String);
  }

  return _BadgeData(allBadges: allBadges, earnedCodes: earnedCodes);
});

class _BadgeData {
  final List<Map<String, dynamic>> allBadges;
  final Set<String> earnedCodes;
  _BadgeData({required this.allBadges, required this.earnedCodes});
}

class BadgeScreen extends ConsumerWidget {
  const BadgeScreen({super.key});

  static const _categoryIcons = {
    'explorer': Icons.explore,
    'social': Icons.people,
    'special': Icons.emoji_events,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(_userBadgesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('バッジ一覧')),
      body: dataAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (data) {
          if (data.allBadges.isEmpty) {
            return const Center(child: Text('バッジがまだありません'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: data.allBadges.length,
            itemBuilder: (context, index) {
              final badge = data.allBadges[index];
              final code = badge['code'] as String;
              final isEarned = data.earnedCodes.contains(code);
              final category = badge['category'] as String? ?? 'explorer';

              return Card(
                color: isEarned
                    ? null
                    : Theme.of(context).disabledColor.withAlpha(13), // ~5% opacity
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isEarned
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.shade300,
                    child: Icon(
                      _categoryIcons[category] ?? Icons.star,
                      color: isEarned ? Colors.white : Colors.grey,
                    ),
                  ),
                  title: Text(
                    badge['name_ja'] as String? ?? code,
                    style: TextStyle(
                      fontWeight: isEarned ? FontWeight.bold : FontWeight.normal,
                      color: isEarned ? null : Colors.grey,
                    ),
                  ),
                  subtitle: Text(
                    badge['description_ja'] as String? ?? '',
                    style: TextStyle(
                      color: isEarned ? null : Colors.grey,
                    ),
                  ),
                  trailing: isEarned
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : const Icon(Icons.lock_outline, color: Colors.grey),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
