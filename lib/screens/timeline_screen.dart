import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:yu_map/providers/app_state.dart';
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
    // 初回表示時に投稿データを読み込み
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().loadPosts();
    });
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
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (appState.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.grey[400],
                  ),
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
                    onPressed: () {
                      context.read<AppState>().loadPosts();
                    },
                  ),
                ],
              ),
            );
          }

          final posts = appState.posts;

          if (posts.isEmpty) {
            return const Center(
              child: Text('No posts yet'),
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
                                      )
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
                                        const Icon(
                                          Icons.location_on,
                                          size: 12,
                                          color: Colors.orange,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          post.facilityName,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.orange,
                                          ),
                                        )
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            )
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(post.content),
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
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            TextButton.icon(
                              icon: Icon(
                                post.isLiked ? Icons.favorite : Icons.favorite_border,
                                color: post.isLiked ? Colors.pink : Colors.grey,
                              ),
                              label: Text('${post.likes}', style: const TextStyle(color: Colors.grey)),
                              onPressed: () {
                                context.read<AppState>().togglePostLike(post.id);
                              },
                            ),
                            TextButton.icon(
                              icon: const Icon(
                                Icons.comment_outlined,
                                color: Colors.grey,
                              ),
                              label: Text(
                                '${post.comments.length}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                              onPressed: () {},
                            ),
                            IconButton(
                              icon: const Icon(Icons.share, color: Colors.grey),
                              onPressed: () {},
                            ),
                          ],
                        )
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
