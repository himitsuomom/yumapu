// lib/presentation/screens/leaderboard/leaderboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/providers/user_providers.dart';

class LeaderboardScreen extends ConsumerWidget {
  const LeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leaderboardAsync = ref.watch(leaderboardProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ランキング')),
      body: leaderboardAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('ランキングデータがありません'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final rank = index + 1;
              final user = entry['users'] as Map<String, dynamic>?;
              final displayName =
                  user?['display_name'] ?? user?['username'] ?? '匿名';
              final avatarUrl = user?['avatar_url'] as String?;
              final totalPoints = entry['total_points'] as int? ?? 0;
              final title = entry['current_title'] as String? ?? '';

              return Card(
                color: rank <= 3
                    ? _podiumColor(rank, context)
                    : null,
                child: ListTile(
                  leading: SizedBox(
                    width: 48,
                    child: rank <= 3
                        ? _PodiumIcon(rank: rank)
                        : CircleAvatar(
                            backgroundImage: avatarUrl != null
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: avatarUrl == null
                                ? Text('$rank')
                                : null,
                          ),
                  ),
                  title: Text(
                    displayName as String,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(title),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$totalPoints pt',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        '#$rank',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color? _podiumColor(int rank, BuildContext context) {
    switch (rank) {
      case 1:
        return Colors.amber.shade50;
      case 2:
        return Colors.grey.shade100;
      case 3:
        return Colors.brown.shade50;
      default:
        return null;
    }
  }
}

class _PodiumIcon extends StatelessWidget {
  final int rank;

  const _PodiumIcon({required this.rank});

  @override
  Widget build(BuildContext context) {
    final colors = {1: Colors.amber, 2: Colors.grey, 3: Colors.brown};
    return CircleAvatar(
      backgroundColor: colors[rank],
      child: const Icon(Icons.emoji_events, color: Colors.white, size: 24),
    );
  }
}
