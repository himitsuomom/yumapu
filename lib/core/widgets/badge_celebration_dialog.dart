// lib/core/widgets/badge_celebration_dialog.dart
//
// チェックイン後にバッジを獲得したとき表示するお祝いダイアログ。
// FacilityDetailScreen と FacilityPreviewSheet の両方で共有する。

import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/models/badge.dart';
import 'package:yu_map/providers/auth_provider.dart';

/// チェックイン後に新規付与されたバッジを取得してダイアログ表示する。
///
/// [since]: チェックイン直前の時刻（この時刻以降に付与されたバッジが対象）
///
/// 使い方:
/// ```dart
/// final checkinTime = DateTime.now().toUtc();
/// await ref.read(visitNotifierProvider.notifier).logVisit(...);
/// await Future<void>.delayed(const Duration(milliseconds: 800));
/// await showNewBadgesIfAny(context: context, ref: ref, since: checkinTime);
/// ```
Future<void> showNewBadgesIfAny({
  required BuildContext context,
  required WidgetRef ref,
  required DateTime since,
}) async {
  final client = ref.read(supabaseClientProvider);
  final userId = ref.read(sessionProvider)?.user.id;
  if (client == null || userId == null || !context.mounted) return;

  try {
    final rows = await client
        .from('user_badges')
        .select('*, badges(*)')
        .eq('user_id', userId)
        .gte('earned_at', since.toIso8601String());

    if (!context.mounted) return;
    final newBadges = (rows as List)
        .map((e) => UserBadge.fromJson(e as Map<String, dynamic>))
        .toList();

    if (newBadges.isEmpty) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => BadgeCelebrationDialog(badges: newBadges),
    );
  } catch (_) {
    // バッジ取得失敗は無視（チェックイン自体は成功している）
  }
}

/// バッジ獲得を祝うダイアログ。上からconfettiが降ってくる演出付き。
class BadgeCelebrationDialog extends StatefulWidget {
  const BadgeCelebrationDialog({super.key, required this.badges});

  final List<UserBadge> badges;

  @override
  State<BadgeCelebrationDialog> createState() => _BadgeCelebrationDialogState();
}

class _BadgeCelebrationDialogState extends State<BadgeCelebrationDialog> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    // ダイアログが開いたらすぐ confetti を開始
    _confettiController.play();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  /// confetti の紙片を描く（星型）
  Path _drawStar(Size size) {
    final path = Path();
    const sides = 5;
    const innerRadiusRatio = 0.4;
    final outerR = size.width / 2;
    final innerR = outerR * innerRadiusRatio;
    final center = Offset(outerR, size.height / 2);

    for (int i = 0; i < sides * 2; i++) {
      final angle = (math.pi / sides) * i - math.pi / 2;
      final r = i.isEven ? outerR : innerR;
      final point = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  Widget build(BuildContext context) {
    // Stack はオーバーレイ全体を覆うため SizedBox.expand で明示する。
    // confetti は上端中央から降り注ぎ、AlertDialog は中央に固定する。
    return SizedBox.expand(
      child: Stack(
        children: [
          // ── confetti（画面上端中央から下方向に発射）──────────────
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: math.pi / 2, // 下方向
              numberOfParticles: 30,
              maxBlastForce: 30,
              minBlastForce: 10,
              emissionFrequency: 0.05,
              gravity: 0.3,
              colors: const [
                Color(0xFFFF6B6B),
                Color(0xFFFFD93D),
                Color(0xFF6BCB77),
                Color(0xFF4D96FF),
                Color(0xFFFF9F43),
              ],
              createParticlePath: _drawStar,
            ),
          ),

          // ── ダイアログ本体（画面中央）────────────────────────────
          Center(
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Column(
                children: [
                  Text(
                    '🏅',
                    style: TextStyle(fontSize: 48),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'バッジを獲得しました！',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.badges
                      .map(
                        (ub) => ListTile(
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              ub.badge.displayIcon,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                          title: Text(
                            ub.badge.nameJa,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: ub.badge.descriptionJa != null
                              ? Text(
                                  ub.badge.descriptionJa!,
                                  style: const TextStyle(fontSize: 12),
                                )
                              : null,
                        ),
                      )
                      .toList(),
                ),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                FilledButton.icon(
                  icon: const Icon(Icons.celebration_outlined),
                  label: const Text('やった！'),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
