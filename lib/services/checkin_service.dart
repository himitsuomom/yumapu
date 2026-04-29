// lib/services/checkin_service.dart
//
// チェックイン処理の共通ロジック。
//
// 背景: FacilityPreviewSheet と FacilityDetailScreen で全く同じチェックインロジックが
// コピーされていた（距離チェック・2段階ダイアログ・バッジ通知）。
// このファイルに抽出することで修正や機能追加を1か所に集約する。
//
// 使い方:
//   await CheckinService.performCheckin(
//     context: context,
//     ref: ref,
//     facility: facility,
//     setCheckingIn: (v) => setState(() => _isCheckingIn = v),
//   );

import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/core/widgets/badge_celebration_dialog.dart';
import 'package:yu_map/core/widgets/guest_restriction_dialog.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/location_provider.dart';
import 'package:yu_map/providers/visit_provider.dart';

/// チェックイン処理をまとめた静的ユーティリティクラス。
///
/// Widget のライフサイクル外で状態を保持しないため、
/// テストしやすいシンプルな設計にしている。
abstract final class CheckinService {
  /// チェックイン処理を実行する。
  ///
  /// [context] - ダイアログ・SnackBar 表示用
  /// [ref]     - Riverpod プロバイダー参照用
  /// [facility]        - チェックイン対象施設
  /// [setCheckingIn]   - 処理中フラグのコールバック（Widget の setState 内で更新）
  ///
  /// 処理フロー:
  ///   1. ログイン確認 → 未ログインは SnackBar 案内で終了
  ///   2. 距離チェック (500m) → 遠い場合は警告ダイアログ（確認も兼ねる）
  ///   3. 近い場合のみ通常確認ダイアログ
  ///   4. logVisit() で DB に記録
  ///   5. 成功 SnackBar → バッジ通知
  static Future<void> performCheckin({
    required BuildContext context,
    required WidgetRef ref,
    required Facility facility,
    required void Function(bool) setCheckingIn,
  }) async {
    // 1. ログイン確認
    final session = ref.read(sessionProvider);
    if (session == null) {
      if (!context.mounted) return;
      final goLogin = await GuestRestrictionDialog.show(
        context,
        featureName: 'チェックイン',
      );
      if (goLogin == true && context.mounted) {
        Navigator.of(context).pushNamed('/login');
      }
      return;
    }

    // 2. 距離チェック（500m以上離れている場合は警告ダイアログ＝確認ダイアログ兼用）
    bool alreadyConfirmed = false;
    final currentLoc = ref.read(currentLocationProvider);
    if (currentLoc != null) {
      final distKm = computeDistanceKm(
        lat1: currentLoc.lat,
        lon1: currentLoc.lng,
        lat2: facility.latitude,
        lon2: facility.longitude,
      );
      if (distKm != null && distKm > 0.5) {
        if (!context.mounted) return;
        final distStr = formatDistanceKm(distKm);
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('少し遠いですが、チェックインしますか？'),
            content: Text(
              '現在地から$distStr離れています。\n思い出に${facility.name}へチェックインできます。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('やめておく'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style:
                    FilledButton.styleFrom(backgroundColor: Colors.orange),
                child: const Text('チェックイン！'),
              ),
            ],
          ),
        );
        if (proceed != true || !context.mounted) return;
        alreadyConfirmed = true; // 警告ダイアログで確認済み
      }
    }

    // 3. 近い施設の場合のみ通常確認ダイアログ
    if (!alreadyConfirmed) {
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('チェックイン'),
          content: Text('${facility.name}にチェックインしますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('キャンセル'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('チェックイン'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    // 4. チェックイン処理
    setCheckingIn(true);
    try {
      final checkinTime = DateTime.now().toUtc();

      await ref
          .read(visitNotifierProvider.notifier)
          .logVisit(facilityId: facility.id);

      if (!context.mounted) return;

      final visitState = ref.read(visitNotifierProvider);
      if (visitState is AsyncError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(visitState.error.toString()),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('チェックインしました 🎉')),
      );

      // confetti を画面上から降り注ぐ演出として表示する。
      // ConfettiController をここで生成し、オーバーレイに乗せて再生後に dispose。
      _showCheckinConfetti(context);

      // 5. DBトリガーがバッジを付与するまで少し待ってからバッジ通知
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (!context.mounted) return;
      await showNewBadgesIfAny(
          context: context, ref: ref, since: checkinTime);
    } finally {
      if (context.mounted) setCheckingIn(false);
    }
  }

  /// チェックイン成功時に confetti を画面上から降り注がせる。
  ///
  /// OverlayEntry を使ってウィジェットツリーの最前面に confetti を配置し、
  /// 2秒後に自動で除去する。呼び出し元をブロックしない（fire-and-forget）。
  static void _showCheckinConfetti(BuildContext context) {
    final overlay = Overlay.of(context);
    final controller =
        ConfettiController(duration: const Duration(seconds: 2));

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: controller,
            blastDirection: pi / 2, // 真下に向かって発射
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            maxBlastForce: 30,
            minBlastForce: 10,
            gravity: 0.3,
            colors: const [
              Color(0xFFE53935), // 朱赤（温泉）
              Color(0xFF1976D2), // 青（銭湯）
              Color(0xFF2E7D32), // 深緑（サウナ）
              Color(0xFFFF9800), // オレンジ
              Color(0xFFFFEB3B), // 黄
            ],
          ),
        ),
      ),
    );

    overlay.insert(entry);
    controller.play();

    // 2秒後にクリーンアップ
    Future<void>.delayed(const Duration(seconds: 2), () {
      controller.stop();
      controller.dispose();
      entry.remove();
    });
  }
}
