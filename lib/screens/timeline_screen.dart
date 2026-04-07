import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yu_map/models/post.dart';
import 'package:yu_map/providers/app_state.dart';
import 'package:yu_map/services/supabase_service.dart';
import 'package:yu_map/widgets/hexagon_logo.dart';
import 'package:yu_map/widgets/safe_network_image.dart';

/// SNSタイムライン画面
class TimelineScreen extends StatefulWidget {
  const TimelineScreen({super.key});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadPosts();
    });
  }

  /// コメント一覧BottomSheetを表示
  void _showCommentSheet(BuildContext context, Post post) {
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: DraggableScrollableSheet(
                initialChildSize: 0.5,
                minChildSize: 0.3,
                maxChildSize: 0.85,
                expand: false,
                builder: (_, scrollController) {
                  return Column(
                    children: [
                      // ハンドルバー
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'コメント (${post.comments.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const Divider(height: 1),

                      // コメント一覧
                      Expanded(
                        child: post.comments.isEmpty
                            ? Center(
                                child: Text(
                                  'まだコメントはありません',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                padding: const EdgeInsets.all(16),
                                itemCount: post.comments.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 12),
                                itemBuilder: (_, i) {
                                  final comment = post.comments[i];
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundImage:
                                            NetworkImage(comment.avatar),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  comment.user,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  comment.time,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey[500],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              comment.text,
                                              style:
                                                  const TextStyle(fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),

                      // コメント入力
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          border: Border(
                            top: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                        child: SafeArea(
                          top: false,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: commentController,
                                  decoration: InputDecoration(
                                    hintText: 'コメントを入力...',
                                    hintStyle:
                                        TextStyle(color: Colors.grey[400]),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: BorderSide.none,
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.send,
                                    color: Colors.orange),
                                onPressed: () async {
                                  final text =
                                      commentController.text.trim();
                                  if (text.isEmpty) return;

                                  final appState =
                                      context.read<AppState>();
                                  final user = appState.currentUser;
                                  final userId =
                                      SupabaseService.getCurrentUserId();

                                  if (userId == null || user == null) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content:
                                            Text('ログインが必要です'),
                                      ),
                                    );
                                    return;
                                  }

                                  final success =
                                      await SupabaseService.addComment(
                                    postId: post.id,
                                    userId: userId,
                                    text: text,
                                    userName: user.name,
                                    userAvatar: user.avatar,
                                  );

                                  if (success) {
                                    // ローカルにも追加
                                    post.comments.add(Comment(
                                      id: DateTime.now()
                                          .millisecondsSinceEpoch
                                          .toString(),
                                      user: user.name,
                                      avatar: user.avatar,
                                      text: text,
                                      time: 'たった今',
                                    ));
                                    commentController.clear();
                                    setSheetState(() {});
                                    // 親も更新
                                    if (mounted) setState(() {});
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  /// シェア
  Future<void> _sharePost(Post post) async {
    final text = '${post.facilityName}の口コミ: ${post.content}';
    final url = Uri.parse(
      'https://twitter.com/intent/tweet?text=${Uri.encodeComponent(text)}',
    );

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      // フォールバック: クリップボードにコピー
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('シェアできませんでした')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'タイムライン',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: HexagonLogo(size: 24),
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          if (appState.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (appState.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    appState.errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('もう一度試す'),
                    onPressed: () => context.read<AppState>().loadPosts(),
                  ),
                ],
              ),
            );
          }

          final posts = appState.posts;

          if (posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.forum_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'まだ投稿はありません',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '施設を訪れて最初の投稿をしましょう！',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<AppState>().loadPosts();
            },
            child: ListView.builder(
              itemCount: posts.length,
              itemBuilder: (context, index) {
                final post = posts[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundImage: NetworkImage(post.avatar),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        post.user,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        post.time,
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: Colors.orange.shade100,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.location_on,
                                            size: 12, color: Colors.orange),
                                        const SizedBox(width: 4),
                                        Text(
                                          post.facilityName,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(post.content),
                        if (post.imageUrl.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SafeNetworkImage(
                              imageUrl: post.imageUrl,
                              width: double.infinity,
                              height: 200,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            TextButton.icon(
                              icon: Icon(
                                post.isLiked
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color:
                                    post.isLiked ? Colors.pink : Colors.grey,
                              ),
                              label: Text(
                                '${post.likes}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              onPressed: () {
                                context
                                    .read<AppState>()
                                    .togglePostLike(post.id);
                              },
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.comment_outlined,
                                  color: Colors.grey),
                              label: Text(
                                '${post.comments.length}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              onPressed: () =>
                                  _showCommentSheet(context, post),
                            ),
                            IconButton(
                              icon: const Icon(Icons.share,
                                  color: Colors.grey),
                              onPressed: () => _sharePost(post),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
