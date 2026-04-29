#!/bin/bash
# セッション51 コミットスクリプト
# 実行方法: bash scripts/session51_commit.sh
#
# 変更内容:
#   1. checkin_service.dart: confetti演出追加・距離警告文言改善
#   2. search_screen.dart: 検索履歴機能追加（直近5件）

set -e

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

# index.lock が残っている場合は削除
if [ -f .git/index.lock ]; then
  echo "⚠️  .git/index.lock を削除します"
  rm -f .git/index.lock
fi

echo "📦 コミット1: チェックイン改善（confetti演出・距離警告文言）"
git add lib/services/checkin_service.dart
git commit -m "feat: チェックイン成功時にconfetti演出追加・距離警告文言をポジティブに改善

- checkin_service.dart: チェックイン成功時にOverlayでconfettiアニメーション表示
- 距離警告ダイアログのタイトルを「施設から離れています」→「少し遠いですが、チェックインしますか？」
- ボタンテキストを「チェックイン」→「チェックイン！」に変更
- キャンセルボタンを「キャンセル」→「やめておく」に変更"

echo "📦 コミット2: 検索履歴機能追加"
git add lib/features/search/screens/search_screen.dart
git commit -m "feat: 検索画面に検索履歴機能追加（直近5件）

- flutter_secure_storageで永続化（アプリ再起動後も保持）
- 検索バーフォーカス時＋テキスト未入力時に履歴パネルを表示
- 履歴タップで再検索、×ボタンで個別削除
- Enterキー確定時・履歴タップ時に自動保存"

echo "✅ セッション51 コミット完了"
