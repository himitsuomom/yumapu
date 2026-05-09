part of 'badge_screen.dart';

// ── バッジタイル（グリッドの1マス） ─────────────────────────────────────────────

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.badge,
    required this.earnedAt,
    required this.dateFormat,
    required this.isEarned,
    required this.checkInCount,
  });

  final AppBadge badge;
  final DateTime? earnedAt;
  final DateFormat? dateFormat;
  final bool isEarned;
  final int checkInCount;

  @override
  Widget build(BuildContext context) {
    final progressInfo = _computeProgress();

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: AnimatedOpacity(
        opacity: isEarned ? 1.0 : 0.55,
        duration: const Duration(milliseconds: 200),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _BadgeIcon(badge: badge, size: 36),
                const SizedBox(height: 4),
                Text(
                  badge.nameJa,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (isEarned && earnedAt != null && dateFormat != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    dateFormat!.format(earnedAt!),
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
                if (!isEarned && progressInfo != null) ...[
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: progressInfo.progressRatio.clamp(0.0, 1.0),
                    backgroundColor: Colors.grey.shade200,
                    color: const Color(0xFF1565C0),
                    minHeight: 3,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    progressInfo.remainText,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF1565C0),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
                if (!isEarned && progressInfo == null) ...[
                  const SizedBox(height: 4),
                  Text(
                    badge.requirementText,
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF757575),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  _ProgressInfo? _computeProgress() {
    if (isEarned) return null;
    final type = badge.requirements['type'] as String?;
    if (type != 'visit_count') return null;
    final required = (badge.requirements['count'] as num?)?.toInt() ?? 0;
    if (required <= 0) return null;

    final current = checkInCount.clamp(0, required);
    final remain = required - current;
    return _ProgressInfo(
      current: current,
      total: required,
      progressRatio: current / required,
      remainText: remain > 0 ? 'あと$remain回' : 'もうすぐ！',
    );
  }

  void _showDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            _BadgeIcon(badge: badge, size: 32),
            const SizedBox(width: 8),
            Expanded(child: Text(badge.nameJa)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (badge.descriptionJa != null && badge.descriptionJa!.isNotEmpty) ...[
              Text(badge.descriptionJa!),
              const SizedBox(height: 8),
            ],
            Text(
              '📋 獲得条件: ${badge.requirementText}',
              style: const TextStyle(fontSize: 13),
            ),
            if (!isEarned) ...[
              (() {
                final info = _computeProgress();
                if (info == null) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: info.progressRatio.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey.shade200,
                      color: const Color(0xFF1565C0),
                      minHeight: 6,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '現在: ${info.current} / ${info.total} 回 (${info.remainText})',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1565C0),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                );
              })(),
            ],
            const SizedBox(height: 8),
            Text(
              'カテゴリ: ${badge.categoryLabel}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF757575),
              ),
            ),
            if (isEarned && earnedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                '取得日: ${dateFormat?.format(earnedAt!) ?? ''}',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF1565C0),
                ),
              ),
            ] else if (!isEarned) ...[
              const SizedBox(height: 4),
              const Text(
                '🔒 まだ獲得していません',
                style: TextStyle(fontSize: 12, color: Color(0xFF757575)),
              ),
            ],
          ],
        ),
        actions: [
          if (isEarned)
            TextButton.icon(
              icon: const Icon(Icons.share_outlined, size: 16),
              label: const Text('シェア'),
              onPressed: () {
                final msg = '湯マップで「${badge.nameJa}」バッジを獲得しました！\n'
                    '${badge.descriptionJa != null && badge.descriptionJa!.isNotEmpty ? badge.descriptionJa! : badge.requirementText}\n'
                    '#湯マップ #温泉 #サウナ';
                Share.share(msg);
              },
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
}

// ── 進捗情報 ──────────────────────────────────────────────────────────────────

class _ProgressInfo {
  const _ProgressInfo({
    required this.current,
    required this.total,
    required this.progressRatio,
    required this.remainText,
  });

  final int current;
  final int total;
  final double progressRatio;
  final String remainText;
}
