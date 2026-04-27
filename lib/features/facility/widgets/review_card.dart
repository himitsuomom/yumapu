import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:yu_map/domain/entities/review.dart';
import 'package:yu_map/widgets/crown_badge.dart';

/// A card displaying a single [Review] with author avatar, rating, content,
/// and optional likes count.
///
/// Uses [UserAvatarWithCrown] and [PremiumChip] for premium author display.
/// The likes icon is suppressed when [Review.likesCount] == 0.
/// When [onDelete] or [onEdit] is non-null, a "…" menu is shown allowing the
/// owner to edit or delete their review.
class ReviewCard extends StatelessWidget {
  const ReviewCard({
    super.key,
    required this.review,
    this.onLike,
    this.onUnlike,
    this.isLiked = false,
    this.onDelete,
    this.onEdit,
  });

  final Review review;

  /// 未いいね状態でタップされたときに呼ばれる。null で非表示。
  final VoidCallback? onLike;

  /// いいね済み状態でタップされたときに呼ばれる（取り消し）。null で非表示。
  final VoidCallback? onUnlike;

  /// true の場合はいいね済み表示（赤いハート）。false は未いいね表示。
  final bool isLiked;

  /// レビュー削除時に呼ばれる。null の場合はメニューを表示しない（他人のレビュー）。
  final VoidCallback? onDelete;

  /// レビュー編集時に呼ばれる。null の場合は編集メニューを表示しない。
  final VoidCallback? onEdit;

  static final _dateFormat = DateFormat('yyyy/MM/dd', 'ja');

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Author row ───────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatarWithCrown(
                  isPremium: review.authorIsPremium,
                  radius: 20,
                  avatarUrl: review.authorAvatarUrl,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              review.authorDisplayName ?? '匿名ユーザー',
                              style: textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (review.authorIsPremium) ...[
                            const SizedBox(width: 6),
                            const PremiumChip(),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _dateFormat.format(review.createdAt),
                        style: textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF757575),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StarRating(rating: review.rating.toDouble()),
                // ── 編集・削除メニュー（レビュー投稿者本人のみ表示）───────────
                if (onEdit != null || onDelete != null)
                  PopupMenuButton<String>(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    tooltip: 'メニュー',
                    onSelected: (value) async {
                      if (value == 'edit') {
                        // 編集コールバックを呼ぶ（BottomSheetは呼び出し元で開く）
                        onEdit!();
                      } else if (value == 'delete') {
                        // 削除前に確認ダイアログを表示する
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('レビューを削除しますか？'),
                            content: const Text('この操作は取り消せません。'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('キャンセル'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('削除'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          onDelete!();
                        }
                      }
                    },
                    itemBuilder: (_) => [
                      if (onEdit != null)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined,
                                  size: 18),
                              SizedBox(width: 8),
                              Text('編集'),
                            ],
                          ),
                        ),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('削除',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // ── Review content ───────────────────────────────────────────
            Text(review.content, style: textTheme.bodyMedium),
            // ── Likes row ────────────────────────────────────────────────
            // いいね件数 > 0 または ログイン中（onLike/onUnlike が非null）の場合に表示
            if (review.likesCount > 0 || onLike != null || onUnlike != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  // いいね件数（0件でも isLiked の場合は表示）
                  if (review.likesCount > 0 || isLiked) ...[
                    Icon(
                      Icons.favorite,
                      size: 14,
                      color: isLiked ? Colors.red : Colors.grey[400],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${review.likesCount}',
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(width: 12),
                  ],
                  // いいね / いいね取り消しトグルボタン
                  if (onLike != null || onUnlike != null)
                    InkWell(
                      onTap: isLiked ? onUnlike : onLike,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 14,
                              color: isLiked
                                  ? Colors.red
                                  : Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isLiked ? 'いいね済み' : 'いいね',
                              style: textTheme.bodySmall?.copyWith(
                                color: isLiked
                                    ? Colors.red
                                    : Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Star rating ───────────────────────────────────────────────────────────────

/// 星評価ウィジェット。double 型を受け取り半星（Icons.star_half）に対応。
/// 整数の評価値（1〜5）でも問題なく動作する。
/// ヘッダーの平均評価と同一コンポーネントを共有するため double で統一。
class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final starValue = i + 1;
        final IconData icon;
        if (rating >= starValue) {
          icon = Icons.star;
        } else if (rating >= starValue - 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }
        return Icon(icon, size: 14, color: const Color(0xFFFFC107));
      }),
    );
  }
}
