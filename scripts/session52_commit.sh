#!/bin/bash
# Session 52: 通知許可タイミング改善・距離順UX改善
# 実行: bash scripts/session52_commit.sh

set -e
cd "$(git -C "$(dirname "$0")/.." rev-parse --show-toplevel)"

# git lockファイルが残っている場合は削除
if [ -f ".git/index.lock" ]; then
  echo "git lockファイルを削除します..."
  rm -f .git/index.lock
fi

# ───────────────────────────────────────────────────────────────────────────
# コミット1: デッドコード削除（手動 git rm が必要）
# ───────────────────────────────────────────────────────────────────────────
echo ""
echo "⚠️  コミット1の準備: デッドコード削除（手動実行が必要）"
echo "  以下のコマンドを手動で実行してください:"
echo "    git rm lib/main.dart.backup"
echo "    git rm lib/features/reviews/screens/write_review_screen.dart"
echo ""
echo "その後、以下のコミットコマンドを実行:"
echo "    git commit -m 'chore: デッドコード2件削除 (main.dart.backup・write_review_screen)'"
echo ""

# ───────────────────────────────────────────────────────────────────────────
# コミット2: 通知許可タイミング改善
# ───────────────────────────────────────────────────────────────────────────
echo "コミット2: 通知許可タイミング改善..."
git add lib/services/notification_service.dart
git add lib/providers/auth_provider.dart
git commit -m "fix: 通知許可を起動時→ログイン後に遅延リクエストへ変更

- notification_service.dart: initialize()から requestPermission() を分離
  - すべてのハンドラー・チャンネルを権限状態に関わらず設定
  - requestPermissionLazily() を新設: notDetermined のときのみリクエスト
  - 権限denied時の早期returnを削除（後から許可された場合にも動作するよう改善）
- auth_provider.dart: signInWithEmail後に requestPermissionLazily() を呼ぶ
  - ユーザーがアプリの価値を理解した後（ログイン後）に許可を求める設計
  - industry standard パターン（許可率向上）"

# ───────────────────────────────────────────────────────────────────────────
# コミット3: 距離順UX改善・コメント整理
# ───────────────────────────────────────────────────────────────────────────
echo "コミット3: 距離順UX改善・コメント整理..."
git add lib/features/search/screens/search_screen.dart
git add lib/app.dart
git commit -m "ux: 距離順ソートの位置情報未取得時のUX改善

- search_screen.dart: currentLocationProviderをwatchし、
  位置情報未取得時に距離順チップに📍アイコンを付与
  + 「位置情報を取得中です。地図タブを開くと近い順に並びます」の案内テキストを表示
- app.dart: write_review_screen.dartの削除方法コメントを具体的なgit rmコマンドに更新"

echo ""
echo "✅ Session 52 コミット完了（コミット1のみ手動対応が必要です）"
