import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/core/widgets/empty_widget.dart';
import 'package:yu_map/core/widgets/error_widget.dart';
import 'package:yu_map/core/widgets/loading_widget.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/favorites_provider.dart';
import 'package:yu_map/features/facility/screens/facility_detail_screen.dart';
import 'package:yu_map/features/search/widgets/facility_list_tile.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);
    if (!isSignedIn) {
      return const EmptyWidget(
        message: 'ログインするとお気に入りを保存できます',
        icon: Icons.favorite_outline,
      );
    }

    final facilitiesAsync = ref.watch(favoriteFacilitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('お気に入り')),
      body: facilitiesAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => AppErrorWidget(
          message: 'お気に入りの取得に失敗しました',
          onRetry: () => ref.invalidate(favoriteFacilitiesProvider),
        ),
        data: (facilities) {
          if (facilities.isEmpty) {
            return const EmptyWidget(
              message: 'お気に入りの施設はまだありません\n施設をお気に入りに追加してみましょう',
              icon: Icons.favorite_outline,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: facilities.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final facility = facilities[i];
              return Dismissible(
                key: Key(facility.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: Colors.red,
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  ref.read(favoritesProvider.notifier).toggle(facility.id);
                },
                child: FacilityListTile(
                  facility: facility,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            FacilityDetailScreen(facilityId: facility.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
