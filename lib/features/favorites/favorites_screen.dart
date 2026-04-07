import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/core/widgets/empty_widget.dart';
import 'package:yu_map/core/widgets/error_widget.dart';
import 'package:yu_map/core/widgets/loading_widget.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/features/search/widgets/facility_list_tile.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/favorites_provider.dart';

// ── Local provider — fetches full Facility objects for all favorite IDs ───────

final _favoriteFacilitiesProvider =
    FutureProvider.autoDispose<List<Facility>>((ref) async {
  final ids = ref.watch(favoritesProvider).valueOrNull;
  if (ids == null || ids.isEmpty) return [];
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return [];
  final rows = await client
      .from('facilities')
      .select(
        'id, name, name_kana, latitude, longitude, address, phone, '
        'website, prefecture_id, facility_type_id, '
        'business_hours, price_info, data_source, data_quality_score',
      )
      .inFilter('id', ids.toList()) as List;
  return rows
      .map((r) => Facility.fromJson(r as Map<String, dynamic>))
      .toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);

    // Prompt login when not authenticated
    if (!isSignedIn) {
      return Scaffold(
        appBar: AppBar(title: const Text('お気に入り')),
        body: EmptyWidget(
          icon: Icons.favorite_border,
          message: 'お気に入りを見るにはログインしてください',
          action: ElevatedButton(
            onPressed: () => Navigator.of(context).pushNamed('/login'),
            child: const Text('ログイン'),
          ),
        ),
      );
    }

    final facilitiesAsync = ref.watch(_favoriteFacilitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('お気に入り')),
      body: facilitiesAsync.when(
        data: (facilities) {
          if (facilities.isEmpty) {
            return const EmptyWidget(
              icon: Icons.favorite_border,
              message: 'お気に入りはまだありません\n施設を探してお気に入りに追加しましょう',
            );
          }
          return ListView.separated(
            itemCount: facilities.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final facility = facilities[i];
              return Dismissible(
                key: Key(facility.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red.shade400,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  ref.read(favoritesProvider.notifier).toggle(facility.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${facility.name}をお気に入りから削除しました'),
                      action: SnackBarAction(
                        label: '元に戻す',
                        onPressed: () =>
                            ref.read(favoritesProvider.notifier).toggle(facility.id),
                      ),
                    ),
                  );
                },
                child: FacilityListTile(
                  facility: facility,
                  onTap: () => Navigator.of(context).pushNamed(
                    '/facility',
                    arguments: facility.id,
                  ),
                ),
              );
            },
          );
        },
        loading: () => const LoadingWidget(),
        error: (e, _) => AppErrorWidget(
          message: e.toString(),
          onRetry: () => ref.invalidate(_favoriteFacilitiesProvider),
        ),
      ),
    );
  }
}
