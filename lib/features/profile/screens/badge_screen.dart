// lib/features/profile/screens/badge_screen.dart
//
// バッジ一覧画面
// ユーザーが獲得したバッジをグリッド形式で表示する。
// 「全バッジ / 獲得済み」をタブで切り替えられる。
// 未獲得のバッジに進捗インジケーター（あとX回など）を表示する。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:yu_map/models/badge.dart';
import 'package:yu_map/providers/badge_provider.dart';
import 'package:yu_map/providers/visit_provider.dart';

part 'badge_screen_sub_widgets.dart';
part 'badge_screen_sections.dart';

class BadgeScreen extends ConsumerStatefulWidget {
  const BadgeScreen({super.key});

  @override
  ConsumerState<BadgeScreen> createState() => _BadgeScreenState();
}

class _BadgeScreenState extends ConsumerState<BadgeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  static final _dateFormat = DateFormat('yyyy/MM/dd');

  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myBadgesAsync = ref.watch(myBadgesProvider);
    final allBadgesAsync = ref.watch(allBadgesProvider);
    final checkInCount = ref.watch(visitCountProvider).valueOrNull ?? 0;

    final myCount = myBadgesAsync.valueOrNull?.length ?? 0;
    final allCount = allBadgesAsync.valueOrNull?.length ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('バッジ'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: '獲得済み${myCount > 0 ? " ($myCount)" : ""}'),
            const Tab(text: '全バッジ'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (allCount > 0)
            _BadgeProgressHeader(
              earned: myCount,
              total: allCount,
              checkInCount: checkInCount,
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                myBadgesAsync.when(
                  data: (badges) => badges.isEmpty
                      ? const _EmptyBadgeView()
                      : _EarnedBadgeGrid(
                          badges: badges,
                          dateFormat: _dateFormat,
                          checkInCount: checkInCount,
                        ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _RetryView(
                    message: 'バッジの取得に失敗しました',
                    onRetry: () => ref.invalidate(myBadgesProvider),
                  ),
                ),

                allBadgesAsync.when(
                  data: (allBadges) {
                    final earnedIds = myBadgesAsync.valueOrNull
                            ?.map((ub) => ub.badge.id)
                            .toSet() ??
                        {};
                    final filtered = _selectedCategory == null
                        ? allBadges
                        : allBadges
                            .where((b) => b.category == _selectedCategory)
                            .toList();
                    return Column(
                      children: [
                        _CategoryFilterBar(
                          allBadges: allBadges,
                          selected: _selectedCategory,
                          onSelected: (cat) =>
                              setState(() => _selectedCategory = cat),
                        ),
                        Expanded(
                          child: _AllBadgeList(
                            allBadges: filtered,
                            earnedIds: earnedIds,
                            checkInCount: checkInCount,
                          ),
                        ),
                      ],
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _RetryView(
                    message: 'バッジ一覧の取得に失敗しました',
                    onRetry: () => ref.invalidate(allBadgesProvider),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
