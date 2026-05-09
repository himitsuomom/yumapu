#!/bin/bash
# セッション53 コミットスクリプト
# 実行方法: bash scripts/session53_commit.sh
# 前提: .git/index.lock が存在する場合は先に削除 → rm -f .git/index.lock

set -e
cd "$(dirname "$0")/.."

echo "=== YuMap セッション51〜53 コミットスクリプト ==="
echo ""

# index.lock チェック
if [ -f .git/index.lock ]; then
  echo "⚠️  .git/index.lock が存在します。削除してから再実行してください:"
  echo "    rm -f .git/index.lock"
  exit 1
fi

# ── コミット1: セッション51 — confetti・検索履歴・警告文改善 ─────────────────
echo "📦 コミット1: confetti・検索履歴・距離警告改善（セッション51）"
git add lib/services/checkin_service.dart
git add lib/features/search/screens/search_screen.dart
git -c user.email=yumap@local -c user.name=yumap \
  commit -m "feat: confetti演出・検索履歴・距離警告フレーミング改善

- checkin_service.dart: チェックイン成功時にconfetti紙吹雪アニメーション追加
  (温泉=朱赤/銭湯=青/サウナ=深緑, 2秒後自動dispose)
- search_screen.dart: 直近5件の検索履歴をflutter_secure_storageで永続化
  フォーカス時+テキスト未入力時に_RecentSearchesPanelを表示
- 距離警告ダイアログ: タイトル・ボタンをポジティブフレーミングに変更
  (「施設から離れています」→「少し遠いですが、チェックインしますか？」)"

# ── コミット2: セッション52 — 通知許可タイミング改善・距離順UX ───────────────
echo "📦 コミット2: 通知許可タイミング改善（セッション52）"
git add lib/services/notification_service.dart
git add lib/providers/auth_provider.dart
git -c user.email=yumap@local -c user.name=yumap \
  commit -m "fix: 通知許可リクエストをログイン後に遅延実行

- notification_service.dart: requestPermissionLazily()追加
  (notDetermined時のみ許可ダイアログ, denied時は早期returnせずハンドラー設定)
- auth_provider.dart: signInWithEmail成功後にrequestPermissionLazily()を呼ぶ
  アプリ起動直後でなくログイン後=価値理解後に求めるindustry standard パターン"

# ── コミット3: セッション53 — UX改善5件・コード整理 ─────────────────────────
echo "📦 コミット3: UX改善5件・コード整理（セッション53）"
git add lib/app.dart
git add lib/features/subscription/
git add lib/features/favorites/favorites_screen.dart
git add lib/features/feed/screens/create_post_screen.dart
git add lib/features/ranking/screens/ranking_screen.dart
git add lib/providers/ranking_provider.dart
git -c user.email=yumap@local -c user.name=yumap \
  commit -m "feat(ux): UX改善5件・subscription_screen移動・コード整理

- favorites_screen.dart: 未ログイン空状態にベネフィット訴求テキスト追加
  「行きたい温泉を♥で保存すれば次からすぐに見つかる」+ FilledButtonで強調
- create_post_screen.dart: 施設タグ未選択時にソフトナッジ表示
  「施設を選ぶと地図からも見つけてもらえます」
- ranking_provider.dart: RankingSortByにshortLabel getter追加
  「合計PT（総合）」「探索PT（訪問）」「社交PT（投稿）」の括弧付き説明
- ranking_screen.dart: ChoiceChipをoption.shortLabelに変更
- app.dart: subscription_screen importを features/subscription/ に更新
- lib/features/subscription/screens/subscription_screen.dart: 新規配置
  lib/screens/から正しいfeatures/配下に移動"

echo ""
echo "✅ 全コミット完了！"
echo ""
echo "次のステップ:"
echo "1. git push origin main（またはブランチ名）"
echo "2. 手動で必要な git rm を実行:"
echo "   git rm lib/features/reviews/screens/write_review_screen.dart"
echo "   git rm lib/main.dart.backup"
echo "   git rm lib/screens/subscription_screen.dart"
echo "   git commit -m 'chore: デッドコード・旧ファイル削除'"
