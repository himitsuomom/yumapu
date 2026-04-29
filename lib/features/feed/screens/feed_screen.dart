// lib/features/feed/screens/feed_screen.dart
//
// 投稿フィード画面
// ユーザーの投稿（温泉レポート）を新しい順で表示する。
// いいね・プルリフレッシュ・新規投稿ボタンを提供する。
//
// 施設絞り込み機能（UX-V15-2）:
//   施設タグをタップするとその施設の投稿だけ絞り込み表示する。
//   絞り込み中はヘッダーにフィルターチップを表示し、タップで解除できる。

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:yu_map/features/feed/screens/create_post_screen.dart';
import 'package:yu_map/features/feed/screens/post_detail_screen.dart';
import 'package:yu_map/models/post.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/follow_provider.dart';
import 'package:yu_map/providers/post_provider.dart';

part 'feed_screen_sub_widgets.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with TickerProviderStateMixin {
  final _scrollController = ScrollController();

  /// タブコントローラー（「すべて」「フォロー中」の2タブ）。
  /// TickerProviderStateMixin = タブアニメーションを動かすための仕組み。
  late final TabController _tabController;

  /// 施設絞り込みフィルター。null = 絞り込みなし（全件表示）。
  /// 施設タグをタップすると設定され、フィルターチップの × で解除する。
  String? _facilityFilter;

  /// 現在のソート順（新しい順 / 人気順）。
  PostFeedSortBy _sortBy = PostFeedSortBy.newest;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // タブが切り替わったときにフォロー中フィルターを更新する
    _tabController.addListener(_onTabChanged);
    // スクロールが末尾付近（200px以内）に達したら追加読み込みを実行する
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// タブ切り替え時の処理
  ///
  /// index 0 = すべて（フォロー中フィルターOFF）
  /// index 1 = フォロー中（フォロー中フィルターON）
  /// ただし index 1 はログイン済みのみ有効。未ログイン時はタブを戻す。
  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;
    final isSignedIn = ref.read(isSignedInProvider);
    if (_tabController.index == 1 && !isSignedIn) {
      // 未ログイン時は「すべて」タブに戻してログイン促進
      _tabController.animateTo(0);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('フォロー中の投稿を見るにはログインが必要です'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    ref.read(postFeedProvider.notifier).setFollowingOnlyFilter(
          _tabController.index == 1,
        );
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxExtent = _scrollController.position.maxScrollExtent;
    final current = _scrollController.offset;
    // 末尾まで200px以内になったら次ページを取得
    if (current >= maxExtent - 200) {
      ref.read(postFeedProvider.notifier).loadMore();
    }
  }

  /// 施設絞り込みを設定する。すでに同じ施設なら解除する（トグル）。
  /// サーバーサイドフィルタリングに変更済み: setFacilityFilter() を呼んで
  /// DB クエリ自体に facility_id フィルターを追加する。
  void _setFacilityFilter(String facilityName, String facilityId) {
    final isSame = _facilityFilter == facilityName;
    setState(() {
      if (isSame) {
        _facilityFilter = null;
      } else {
        _facilityFilter = facilityName;
      }
    });
    // サーバーサイドで絞り込み（null の場合は全件表示に戻る）
    ref.read(postFeedProvider.notifier).setFacilityFilter(
          isSame ? null : facilityId,
        );
  }

  /// 施設絞り込みを解除する。
  void _clearFacilityFilter() {
    setState(() {
      _facilityFilter = null;
    });
    // サーバーサイドフィルターを解除して全件再取得
    ref.read(postFeedProvider.notifier).setFacilityFilter(null);
  }

  @override
  Widget build(BuildContext context) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final feedAsync = ref.watch(postFeedProvider);
    final notifier = ref.watch(postFeedProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('フィード'),
        // 「すべて」「フォロー中」のタブをAppBar下部に配置する。
        // TabBar = 画面上部でコンテンツを切り替えるタブUI。
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'すべて'),
            Tab(text: 'フォロー中'),
          ],
        ),
      ),
      body: feedAsync.when(
        data: (allPosts) {
          // サーバーサイドフィルタリング済みのため、ローカルフィルタリング不要
          final posts = allPosts;
          final isFollowingTab = notifier.showFollowingOnly;

          if (allPosts.isEmpty) {
            return isFollowingTab
                ? const _EmptyFollowingFeedView()
                : const _EmptyFeedView();
          }
          return Column(
            children: [
              // ── ソートバー（新しい順 / 人気順）────────────────────────────
              _SortBar(
                current: _sortBy,
                onChanged: (sortBy) {
                  setState(() => _sortBy = sortBy);
                  ref.read(postFeedProvider.notifier).setSortOrder(sortBy);
                },
              ),

              // ── 施設絞り込みチップ（絞り込み中のみ表示）──────────────────
              if (_facilityFilter != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  color: const Color(0xFFF3E5F5),
                  child: Row(
                    children: [
                      const Icon(Icons.hot_tub,
                          size: 14, color: Color(0xFF7B1FA2)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$_facilityFilter の投稿を表示中',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7B1FA2),
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: _clearFacilityFilter,
                        child: const Icon(Icons.close,
                            size: 16, color: Color(0xFF7B1FA2)),
                      ),
                    ],
                  ),
                ),

              // ── 投稿リスト ────────────────────────────────────────────
              Expanded(
                child: posts.isEmpty
                    ? _FacilityEmptyView(
                        facilityName: _facilityFilter ?? '',
                        onClear: _clearFacilityFilter,
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          ref.read(postFeedProvider.notifier).load();
                        },
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          // 絞り込みなし + hasMore=true なら末尾にローディング行を追加
                          itemCount: posts.length +
                              (_facilityFilter == null && notifier.hasMore
                                  ? 1
                                  : 0),
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            if (index == posts.length) {
                              // 末尾ローディングインジケーター
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child:
                                    Center(child: CircularProgressIndicator()),
                              );
                            }
                            return _PostCard(
                              post: posts[index],
                              activeFacilityFilter: _facilityFilter,
                              onFacilityTap: _setFacilityFilter,
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: Color(0xFF757575)),
              const SizedBox(height: 8),
              Text('読み込みエラー: $e'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () =>
                    ref.read(postFeedProvider.notifier).load(),
                child: const Text('再試行'),
              ),
            ],
          ),
        ),
      ),
      // ログインしていれば投稿ボタンをフローティング表示
      floatingActionButton: isSignedIn
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CreatePostScreen(),
                ),
              ),
              tooltip: '投稿する',
              child: const Icon(Icons.edit_outlined),
            )
          : null,
    );
  }
}

