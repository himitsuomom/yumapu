#!/bin/bash
# セッション55 コミットスクリプト
# 実行手順:
#   1. cd /path/to/yu_map
#   2. rm -f .git/index.lock  # 必要な場合のみ
#   3. bash scripts/session55_commit.sh

set -e
echo "=== セッション55 コミット開始 ==="

# --- Bug修正 ---
echo ">>> Bug-52〜56 修正コミット..."
git add lib/providers/visit_provider.dart \
        lib/providers/plan_provider.dart \
        lib/providers/badge_provider.dart \
        lib/services/checkin_service.dart \
        lib/features/profile/screens/badge_screen.dart

git commit -m "fix: Bug-52〜56 — チェックイン後invalidate・件数制限・エラー適切処理

Bug-52: CheckinService.performCheckin()後に visitCountProvider / visitListProvider /
        visitAllProvider を invalidate してプロフィール統計・履歴を即時更新

Bug-53: visitAllProvider に .limit(500) を追加。
        上限なしだと大量チェックイン時にメモリ問題が起きる可能性があった

Bug-54: BadgeScreen のエラー表示を _RetryView(リトライボタン付き)に改善。
        以前は Text('取得エラー: ...') のみでユーザーがリトライできなかった

Bug-55: myPlansProvider / myBadgesProvider / allBadgesProvider の
        catch(_){return [];} を廃止し rethrow に変更。
        エラーを握り潰していたため、ネット障害でも空リストが返っていた

Bug-56: visitCountProvider の catch(_){return 0;} を廃止し rethrow。
        ネット障害時に「0回」と誤表示していた問題を解消"

# --- UX改善 ---
echo ">>> UX-62/65/66 実装コミット..."
git add lib/features/settings/settings_screen.dart \
        lib/services/notification_service.dart \
        lib/features/profile/screens/plans_screen.dart

git commit -m "feat: UX-62/65/66 — 通知設定UI・プラン公開設定・通知再許可導線

UX-62: 設定画面に「通知」セクションを追加。
       ログイン中ユーザーのみ表示。SwitchListTile で通知オン/オフを制御。

UX-65: プラン作成ダイアログに「公開プラン」トグル(SwitchListTile)を追加。
       StatefulBuilder で isPublic をダイアログ内ローカル状態として管理。
       以前は isPublic = false のハードコードのみで UI から変更不可だった。

UX-66: 通知を OS レベルで拒否したユーザーへの再許可導線を追加。
       - denied 時は「設定を開く」ボタンを表示（url_launcher で app-settings://）
       - WidgetsBindingObserver でアプリ復帰時に許可状態を再チェック
       NotificationService に isNotificationEnabled() / isNotificationDenied()
       メソッドを追加（firebase_messaging の getNotificationSettings() を使用）"

echo "=== セッション55 コミット完了 ==="
