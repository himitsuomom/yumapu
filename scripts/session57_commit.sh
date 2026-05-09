#!/bin/bash
# セッション57コミットスクリプト
# Feat-26: ランキング期間フィルター（週次/月次/累計）実装

set -e
cd "$(git rev-parse --show-toplevel)"

# index.lock が残っている場合は削除
rm -f .git/index.lock
rm -f .git/HEAD.lock

# まず未コミットのセッション56変更があればコミット
STAGED=$(git diff --cached --name-only 2>/dev/null)
if echo "$STAGED" | grep -q "plan_detail_screen\|session56_commit"; then
  git commit -m "fix/feat: Bug-58修正・Feat-25 プランシェア実装

Bug-58: plan_detail_screen.dart の _openGoogleMaps()
  - catch(_){} → catch(e) + SnackBar でユーザー通知
  - context.mounted 確認後に ScaffoldMessenger を呼ぶ

Feat-25: プランの施設リストをテキストシェア
  - AppBar actions にシェアボタン追加（施設1件以上のとき）
  - Share.share() でネイティブシェアシートを表示
  - #湯マップ #温泉 #湯めぐり ハッシュタグ付き"
fi

# セッション57: Feat-26 期間フィルター
git add \
  lib/providers/ranking_provider.dart \
  lib/features/ranking/screens/ranking_screen.dart \
  supabase/migrations/20260430000005_period_ranking_rpc.sql \
  scripts/session57_commit.sh

git commit -m "feat: Feat-26 — ランキング期間フィルター（累計/今月/今週）実装

ranking_provider.dart:
  - RankingPeriod enum 追加（allTime / monthly / weekly）
  - rankingPeriodProvider StateProvider 追加
  - rankingListProvider を期間対応に拡張
    * allTime: 既存 user_rankings テーブルを使用（高速・変更なし）
    * monthly / weekly: get_period_rankings RPC を呼び出し
  - safeInt() ヘルパーで BIGINT の安全パースを実装

ranking_screen.dart:
  - 期間フィルター行（累計 / 今月 / 今週 ChoiceChip）を追加
  - セクションヘッダーに期間ラベルを追加（例: TOP 50 — 今週 / 合計PT順）
  - period 変数を build() で watch

supabase/migrations/20260430000005_period_ranking_rpc.sql:
  - get_period_rankings(p_days_ago, p_sort_col, p_limit) RPC 追加
  - visits.visited_at / reviews.created_at を期間フィルター
  - 期間内の visit_count × 100 = explorer_points で集計
  - ORDER BY を p_sort_col で動的切り替え
  - SECURITY DEFINER + GRANT で認証済み/匿名ユーザーに実行権限付与"

echo ""
echo "✅ セッション57 コミット完了"
git log --oneline -5
