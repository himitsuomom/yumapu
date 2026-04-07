#!/usr/bin/env bash
# docs/setup-supabase.sh
#
# yu_map — Supabase セットアップスクリプト
# このスクリプトをローカルの Terminal で実行してください。
#
# 前提条件:
#   - supabase CLI がインストール済み（https://supabase.com/docs/guides/cli）
#   - このスクリプトは yu_map プロジェクトのルートから実行する
#
# 使い方:
#   chmod +x docs/setup-supabase.sh
#   ./docs/setup-supabase.sh

set -e

PROJECT_REF="fgggkfpxqxudtpouvpfh"

# ────────────────────────────────────────────
# Google Directions API キーの読み込み
# ① .env に GOOGLE_DIRECTIONS_API_KEY が書いてあれば自動読み込み
# ② なければ対話的に入力を求める（ターミナルに値が残らないよう -s フラグを使用）
# ────────────────────────────────────────────
if [ -f ".env" ] && grep -q "^GOOGLE_DIRECTIONS_API_KEY=" .env; then
  GOOGLE_DIRECTIONS_API_KEY="$(grep '^GOOGLE_DIRECTIONS_API_KEY=' .env | cut -d'=' -f2-)"
  echo "✅ .env から GOOGLE_DIRECTIONS_API_KEY を読み込みました"
else
  echo ""
  echo "GOOGLE_DIRECTIONS_API_KEY が .env に見つかりません。"
  printf "Google Directions API キーを入力してください（入力は非表示）: "
  read -rs GOOGLE_DIRECTIONS_API_KEY
  echo ""
  if [ -z "$GOOGLE_DIRECTIONS_API_KEY" ]; then
    echo "❌ APIキーが入力されませんでした。スクリプトを終了します。"
    exit 1
  fi
fi

echo "========================================"
echo " yu_map Supabase セットアップ"
echo "========================================"

# ────────────────────────────────────────────
# STEP 1: supabase CLI の確認
# ────────────────────────────────────────────
echo ""
echo "[STEP 1] supabase CLI を確認中..."

if ! command -v supabase &> /dev/null; then
  echo ""
  echo "⚠️  supabase CLI が見つかりません。以下でインストールしてください："
  echo ""
  echo "  macOS (Homebrew):"
  echo "    brew install supabase/tap/supabase"
  echo ""
  echo "  npm:"
  echo "    npm install -g supabase"
  echo ""
  echo "インストール後、このスクリプトを再実行してください。"
  exit 1
fi

echo "✅ supabase CLI: $(supabase --version)"

# ────────────────────────────────────────────
# STEP 2: Supabase プロジェクトにリンク
# ────────────────────────────────────────────
echo ""
echo "[STEP 2] Supabase プロジェクトにリンク中 (project_ref: ${PROJECT_REF})..."
echo "  ※ アクセストークンの入力を求められた場合は Supabase Dashboard → Account → Access Tokens で発行してください"
echo ""

supabase link --project-ref "$PROJECT_REF" || {
  echo "⚠️  リンクに失敗しました。"
  echo "  以下のコマンドでアクセストークンを使ってログインしてください："
  echo "    supabase login"
  echo "その後 ./docs/setup-supabase.sh を再実行してください。"
  exit 1
}

echo "✅ プロジェクトにリンクしました"

# ────────────────────────────────────────────
# STEP 3: inquiries テーブル マイグレーション実行
# ────────────────────────────────────────────
echo ""
echo "[STEP 3] inquiries テーブルを作成中..."

supabase db push --linked

echo "✅ マイグレーション完了（supabase/migrations/ を参照）"

# ────────────────────────────────────────────
# STEP 4: Directions Edge Function をデプロイ
# ────────────────────────────────────────────
echo ""
echo "[STEP 4] Edge Function 'directions' をデプロイ中..."

supabase functions deploy directions --project-ref "$PROJECT_REF"

echo "✅ Edge Function デプロイ完了"

# ────────────────────────────────────────────
# STEP 5: Google Directions API キーをシークレットに登録
# ────────────────────────────────────────────
echo ""
echo "[STEP 5] GOOGLE_DIRECTIONS_API_KEY をシークレットに登録中..."

supabase secrets set GOOGLE_DIRECTIONS_API_KEY="$GOOGLE_DIRECTIONS_API_KEY" \
  --project-ref "$PROJECT_REF"

echo "✅ シークレット登録完了"

# ────────────────────────────────────────────
# 完了
# ────────────────────────────────────────────
echo ""
echo "========================================"
echo "✅ セットアップ完了！"
echo "========================================"
echo ""
echo "確認事項:"
echo "  1. Supabase Dashboard > Table Editor > inquiries テーブルが存在するか確認"
echo "  2. Dashboard > Edge Functions > directions が表示されるか確認"
echo "  3. Dashboard > Settings > Secrets > GOOGLE_DIRECTIONS_API_KEY が登録されているか確認"
echo ""
