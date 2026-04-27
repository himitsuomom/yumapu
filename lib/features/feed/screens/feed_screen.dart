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
import 'package:yu_map/providers/post_provider.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen> {
  final _scrollController = ScrollController();

  /// 施設絞り込みフィルター。null = 絞り込みなし（全件表示）。
  /// 施設タグをタップすると設定され、フィルターチップの × で解除する。
  String? _facilityFilter;

  /// 施設絞り込み中の施設ID（施設詳細へのナビゲーション用）。
  String? _facilityFilterId;

  @override
  void initState() {
    super.initState();
    // スクロールが末尾付近（200px以内）に達したら追加読み込みを実行する
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
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
        // 同じ施設をタップしたら解除
        _facilityFilter = null;
        _facilityFilterId = null;
      } else {
        _facilityFilter = facilityName;
        _facilityFilterId = facilityId;
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
      _facilityFilterId = null;
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
        // 投稿ボタンは FAB だけに統一。AppBar のアイコンは削除。
      ),
      body: feedAsync.when(
        data: (allPosts) {
          // サーバーサイドフィルタリング済みのため、ローカルフィルタリング不要
          final posts = allPosts;

          if (allPosts.isEmpty) {
            return const _EmptyFeedView();
          }
          return Column(
            children: [
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

// ── 投稿カード ────────────────────────────────────────────────────────────────

class _PostCard extends ConsumerWidget {
  const _PostCard({
    required this.post,
    this.activeFacilityFilter,
    this.onFacilityTap,
  });

  final Post post;

  /// 現在アクティブな施設フィルター名。施設タグのハイライト表示に使う。
  final String? activeFacilityFilter;

  /// 施設タグがタップされたときに呼ばれるコールバック（施設名, 施設ID）。
  final void Function(String facilityName, String facilityId)? onFacilityTap;

  static final _dateFormat = DateFormat('yyyy/MM/dd HH:mm');

  /// 削除確認ダイアログを表示し、OKなら投稿を削除する
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('投稿を削除しますか？'),
        content: const Text('この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(postFeedProvider.notifier).deletePost(post.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('削除に失敗しました。もう一度お試しください。')),
        );
      }
    }
  }

  /// 投稿編集ダイアログを表示し、OKなら内容を更新する（C-3対応）
  ///
  /// TextEditingController で現在の投稿テキストを初期値にセットする。
  /// ダイアログ外タップまたは「キャンセル」で変更なし。
  Future<void> _showEditDialog(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: post.content);
    final newContent = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('投稿を編集'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          maxLength: 500,
          autofocus: true,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '内容を入力...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) Navigator.of(ctx).pop(text);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newContent == null || newContent == post.content) return;
    try {
      await ref.read(postFeedProvider.notifier).editPost(post.id, newContent);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('編集に失敗しました。もう一度お試しください。')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final session = ref.watch(sessionProvider);
    // 現在のログインユーザーが投稿者かどうかを確認
    final isMyPost = session != null && session.user.id == post.userId;

    // 施設タグがアクティブフィルターと一致するときハイライト表示する
    final isFacilityFiltered =
        activeFacilityFilter != null &&
        post.facilityName == activeFacilityFilter;

    // 投稿日時をフォーマット（パースできなければ生の文字列を表示）
    String formattedTime;
    try {
      final dt = DateTime.parse(post.time).toLocal();
      formattedTime = _dateFormat.format(dt);
    } catch (_) {
      formattedTime = post.time;
    }

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PostDetailScreen(post: post),
        ),
      ),
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ヘッダー（アバター・名前・日時・削除メニュー） ────────────
          Row(
            children: [
              _PostAvatar(avatarUrl: post.avatar),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      post.user,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      formattedTime,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
              // 自分の投稿だけ「…」メニューを表示（編集・削除）
              if (isMyPost)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert,
                      size: 18, color: Color(0xFF9E9E9E)),
                  tooltip: '操作',
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditDialog(context, ref);
                    } else if (value == 'delete') {
                      _confirmDelete(context, ref);
                    }
                  },
                  itemBuilder: (_) => [
                    // C-3対応: 編集メニューを追加
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('編集'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text('削除', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),

          // ── 施設タグ ────────────────────────────────────────────────
          // タップすると施設絞り込みフィルターを設定する（アクティブ時はハイライト）
          if (post.facilityName.isNotEmpty) ...[
            GestureDetector(
              onTap: post.facilityId.isNotEmpty && onFacilityTap != null
                  ? () => onFacilityTap!(post.facilityName, post.facilityId)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  // アクティブフィルターと一致するときは紫系でハイライト
                  color: isFacilityFiltered
                      ? const Color(0xFFEDE7F6)
                      : const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(12),
                  border: isFacilityFiltered
                      ? Border.all(
                          color: const Color(0xFF7B1FA2), width: 1)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.hot_tub,
                      size: 14,
                      color: isFacilityFiltered
                          ? const Color(0xFF7B1FA2)
                          : const Color(0xFF1565C0),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      post.facilityName,
                      style: TextStyle(
                        fontSize: 12,
                        color: isFacilityFiltered
                            ? const Color(0xFF7B1FA2)
                            : const Color(0xFF1565C0),
                      ),
                    ),
                    if (post.facilityId.isNotEmpty && onFacilityTap != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Icon(
                          isFacilityFiltered
                              ? Icons.filter_alt
                              : Icons.filter_alt_outlined,
                          size: 12,
                          color: isFacilityFiltered
                              ? const Color(0xFF7B1FA2)
                              : const Color(0xFF1565C0),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ── 本文 ────────────────────────────────────────────────────
          Text(post.content),

          // ── 画像 ────────────────────────────────────────────────────
          if (post.imageUrl.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                post.imageUrl,
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],

          const SizedBox(height: 8),

          // ── フッター（いいねボタン・コメント数） ──────────────────────
          Row(
            children: [
              // いいねボタン（ログイン時のみ有効）
              _LikeButton(post: post, isSignedIn: isSignedIn),
              const SizedBox(width: 16),
              // commentsCount は posts.comments_count（DBトリガーで自動更新）
              // UX-V10-1: コメントアイコンをタップすると PostDetailScreen を
              // 開き、コメント入力欄に自動フォーカス（キーボードを即時表示）する。
              // UX-V11-5: 0件でも常にコメントアイコンを表示することで
              // 「コメントできる」ことに気づいてもらう（0件非表示だと見逃しやすい）。
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => PostDetailScreen(
                      post: post,
                      focusComment: true,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.comment_outlined,
                        size: 18, color: Color(0xFF757575)),
                    const SizedBox(width: 4),
                    Text(
                      '${post.commentsCount}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF757575),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      ),
    );
  }
}

// ── いいねボタン ──────────────────────────────────────────────────────────────

class _LikeButton extends ConsumerWidget {
  const _LikeButton({required this.post, required this.isSignedIn});

  final Post post;
  final bool isSignedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: isSignedIn
          ? () {
              if (post.isLiked) {
                ref.read(postFeedProvider.notifier).unlikePost(post.id);
              } else {
                ref.read(postFeedProvider.notifier).likePost(post.id);
              }
            }
          : null,
      child: Row(
        children: [
          Icon(
            post.isLiked ? Icons.favorite : Icons.favorite_border,
            size: 20,
            color: post.isLiked
                ? Colors.redAccent
                : const Color(0xFF757575),
          ),
          const SizedBox(width: 4),
          Text(
            '${post.likes}',
            style: TextStyle(
              fontSize: 13,
              color: post.isLiked
                  ? Colors.redAccent
                  : const Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 投稿アバター ──────────────────────────────────────────────────────────────

class _PostAvatar extends StatelessWidget {
  const _PostAvatar({required this.avatarUrl});

  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    if (avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 20,
        backgroundImage: NetworkImage(avatarUrl),
        backgroundColor: const Color(0xFFE3F2FD),
      );
    }
    return const CircleAvatar(
      radius: 20,
      backgroundColor: Color(0xFFE3F2FD),
      child: Icon(Icons.person, size: 20, color: Color(0xFF1565C0)),
    );
  }
}

// ── 空フィード表示 ─────────────────────────────────────────────────────────────

/// 投稿が0件の場合に表示するウィジェット。
/// RefreshIndicator が機能するには scrollable な子が必要なため
/// ListView でラップしてプルリフレッシュを有効にする（UX-V11-5対応）。
class _EmptyFeedView extends ConsumerWidget {
  const _EmptyFeedView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(postFeedProvider.notifier).load();
      },
      child: ListView(
        // コンテンツが少なくても引っ張って更新できるよう AlwaysScrollableScrollPhysics を指定
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('♨️', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(
                  '投稿がまだありません',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  '温泉の感想を投稿してみましょう！',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: const Color(0xFF757575)),
                ),
                const SizedBox(height: 4),
                Text(
                  '（下に引っ張って更新できます）',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: const Color(0xFF9E9E9E)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 施設絞り込み中・該当投稿なし表示 ─────────────────────────────────────────

/// 施設絞り込み中だが該当する投稿がない場合に表示するウィジェット。
class _FacilityEmptyView extends StatelessWidget {
  const _FacilityEmptyView({
    required this.facilityName,
    required this.onClear,
  });

  final String facilityName;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 48, color: Color(0xFF9E9E9E)),
          const SizedBox(height: 16),
          Text(
            '「$facilityName」の投稿はまだありません',
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.clear),
            label: const Text('絞り込みを解除'),
            onPressed: onClear,
          ),
        ],
      ),
    );
  }
}
