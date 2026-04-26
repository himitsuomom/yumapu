#!/bin/bash
# 湯マップ iOSシミュレーター起動スクリプト
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
echo "📍 プロジェクトパス: $SCRIPT_DIR"
cd "$SCRIPT_DIR"

# Flutterを探す
if ! command -v flutter &>/dev/null; then
  # 一般的な場所を検索
  for p in \
    "$HOME/development/flutter/bin" \
    "$HOME/flutter/bin" \
    "/usr/local/bin" \
    "$HOME/.pub-cache/bin" \
    "/opt/homebrew/bin" \
    "$HOME/fvm/default/bin"; do
    if [ -f "$p/flutter" ]; then
      export PATH="$p:$PATH"
      break
    fi
  done
fi

if ! command -v flutter &>/dev/null; then
  echo "❌ Flutter が見つかりません。PATHを確認してください。"
  read -n 1 -s -r -p "何かキーを押して終了..."
  exit 1
fi

echo "✅ Flutter: $(which flutter)"
echo "📱 利用可能デバイス:"
flutter devices

echo ""
echo "🚀 iOSシミュレーターで起動します..."
flutter run -d "iPhone 16" --dart-define=SUPABASE_URL="${SUPABASE_URL:-}" --dart-define=SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"
