#!/bin/bash
# セッション56コミットスクリプト
# Bug-57 / Bug-58 修正 + Feat-25（プランシェア）実装

set -e

cd "$(git rev-parse --show-toplevel)"

# index.lock が残っている場合は削除
rm -f .git/index.lock

# コミット1: Bug-57 通知タップのHomeShellタブ乖離修正
# app_navigator.dart（pendingTabSwitch追加）も含む
git add lib/core/navigation/app_navigator.dart \
        lib/features/home/home_shell.dart \
        lib/services/notification_service.dart

git commit -m "fix: Bug-57 — 通知タップのHomeShellタブ乖離を修正

app_navigator.dart:
  - pendingTabSwitch ValueNotifier<int?> を追加
    通知サービス → HomeShell へタブ切り替え指示を渡す

home_shell.dart:
  - initState に pendingTabSwitch.addListener を追加
  - dispose で removeListener してメモリリーク防止
  - _onPendingTabSwitch(): 受信後に value=null でリセット

notification_service.dart:
  - _tabIndexForData(): like/comment→2(フィード), follow→4(プロフィール)
  - like/comment/follow 通知は pendingTabSwitch 経由のタブ切り替えに変更
  - checkin_badge → /badges は pushNamed のまま維持
  - cold start 時は _pendingTabIndex に保留し drainPendingNavigation で実行"

# コミット2: Bug-58 + Feat-25
git add lib/features/profile/screens/plan_detail_screen.dart \
        scripts/session56_commit.sh

git commit -m "fix/feat: Bug-58修正・Feat-25 プランシェア実装

Bug-58: plan_detail_screen.dart の _openGoogleMaps()
  - catch(_){} → catch(e) + SnackBar でユーザー通知
  - context.mounted 確認後に ScaffoldMessenger を呼ぶ
  - コンテキストをメソッド引数で受け取るよう変更

Feat-25: プランの施設リストをテキストシェア
  - AppBar actions にシェアボタン追加（施設1件以上のとき）
  - _sharePlan(): 施設名・住所を番号付きリスト形式で生成
  - share_plus の Share.share() でネイティブシェアシートを表示
  - #湯マップ #温泉 #湯めぐり ハッシュタグ付き"

echo ""
echo "✅ セッション56 コミット完了（2コミット）"
git log --oneline -4
