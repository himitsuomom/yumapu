#!/bin/bash
# セッション54 コミットスクリプト
# 実行手順:
#   1. cd /path/to/yu_map
#   2. rm -f .git/index.lock  # ← 必要な場合のみ
#   3. bash scripts/session54_commit.sh

set -e

echo "=== セッション54 コミット開始 ==="

# --- デッドコード削除 ---
echo ">>> デッドコード削除..."
git rm --cached lib/main.dart.backup 2>/dev/null || true
rm -f lib/main.dart.backup

git rm --cached lib/features/reviews/screens/write_review_screen.dart 2>/dev/null || true
rm -f lib/features/reviews/screens/write_review_screen.dart

git rm --cached lib/screens/subscription_screen.dart 2>/dev/null || true
rm -f lib/screens/subscription_screen.dart

# lib/screens/ が空なら削除
rmdir lib/screens 2>/dev/null || true

git add -A

git commit -m "chore: デッドコード削除（main.dart.backup / write_review_screen / 旧subscription_screen）

- lib/main.dart.backup: 編集ミス防止のためのバックアップファイル。不要なため削除
- lib/features/reviews/screens/write_review_screen.dart: ReviewBottomSheetに移行済みのデッドコード
- lib/screens/subscription_screen.dart: lib/features/subscription/screens/ に移動済みの旧ファイル
- lib/screens/: 上記削除により空になったため削除"

# --- オンボーディングUX改善 ---
echo ">>> オンボーディングUX改善コミット..."
git add lib/features/auth/screens/onboarding_screen.dart
git commit -m "ux: オンボーディング改善 — プラン説明をわかりやすく・位置情報の事前説明追加

- 4枚目スライドのタイトルを「湯めぐりプランを作ろう」→「行きたい施設を旅のしおりにまとめよう」に変更
  初見ユーザーが「プラン」という言葉にピンとこない問題（v28指摘）に対応
- _OnboardingPage に note フィールドを追加
- 4枚目スライドに位置情報使用の説明ノートを表示
  「📍 近くの施設を探すために現在地の使用許可をお願いします」
  地図起動時に突然ダイアログが出る問題（v28指摘）の文脈説明として機能する"

# --- 投稿作成ダイアログ UX改善 ---
echo ">>> 投稿作成ダイアログ改善コミット..."
git add lib/features/feed/screens/create_post_screen.dart
git commit -m "ux: 投稿作成ダイアログに「最近訪問した施設」ショートカット追加

検索ボックスが空の状態で施設ピッカーを開いたとき、
直近チェックイン履歴から重複なし最大5件の施設を「最近訪問した施設」として表示する。
タップで即選択できるため、毎回施設名を検索する手間が省ける。

- CreatePostScreen._openFacilityPicker: visitAllProvider から直近5件取得
- _FacilitySearchDialog: recentFacilities パラメータを追加
- _RecentFacilitiesList: 履歴セクションの新規ウィジェット
- visitAllProvider が空の場合は従来の検索プロンプトにフォールバック"

echo ""
echo "=== セッション54 コミット完了 ==="
echo ""
echo "次のステップ:"
echo "  1. git push origin main"
echo "  2. GitHub Pages でプライバシーポリシーを公開（docs/ フォルダ → Pages設定）"
echo "  3. App Store Connect / Google Play Console でアプリ登録"
echo "  4. OSMインポートスクリプト実行: python scripts/import_osm_facilities.py"
