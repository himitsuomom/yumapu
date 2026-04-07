# Yu Map — セキュリティドキュメント

最終更新: 2026-04-04

---

## 1. APIキー管理方針

### Google Directions API キー（最重要）

**問題（修正済み）:**
旧実装ではクライアントから `https://maps.googleapis.com/maps/api/directions/json?key=<APIキー>` を直接呼び出していた。
モバイル通信をプロキシで傍受すると APIキーが平文で抽出できた。

**対策（2026-04-04 実装済み）:**
Supabase Edge Function を中間プロキシとして配置。クライアントは APIキーを一切持たない。

```
クライアント (Flutter)
    │  POST /functions/v1/directions
    │  Authorization: Bearer <SUPABASE_ANON_KEY>
    ▼
Supabase Edge Function (supabase/functions/directions/index.ts)
    │  Deno.env.get('GOOGLE_DIRECTIONS_API_KEY')
    │  → Google Directions API へプロキシ
    ▼
Google Maps Platform
```

**設定手順（Supabase ダッシュボード）:**
1. `Settings > Secrets` を開く
2. `GOOGLE_DIRECTIONS_API_KEY` を追加し、Directions API 専用キーを貼り付ける
3. Deploy: `supabase functions deploy directions`

---

### Google Maps SDK キー（地図表示用）

| キー | 用途 | 制限設定（推奨） |
|------|------|----------------|
| `GOOGLE_MAPS_KEY_IOS` | iOS マップ表示 | Bundl ID 制限 |
| `GOOGLE_MAPS_KEY_ANDROID` | Android マップ表示 | パッケージ名 + SHA-1 制限 |

これらのキーはネイティブ SDKに組み込まれるため完全な秘匿は難しいが、
Google Cloud Console の **アプリケーション制限** を設定することで
不正利用（他アプリからの使用）を防止できる。

**重要:** Directions API とは異なるキーを使うこと。用途ごとにキーを分離することで
万が一漏洩した場合の影響範囲を最小化できる。

---

### Supabase キー

| キー | 公開可否 | 用途 |
|------|---------|------|
| `SUPABASE_ANON_KEY` | クライアントに含めてよい | 匿名アクセス（RLS で制御） |
| `SUPABASE_SERVICE_ROLE_KEY` | **絶対に公開しない** | RLS をバイパスする管理者操作 |

`service_role` キーはセッション内でチャットに露出した可能性があるため、
ローテーション（再生成）を推奨する。

---

## 2. Row Level Security (RLS) 設定

Supabase のテーブルはすべて RLS を有効にすること。

| テーブル | SELECT | INSERT | UPDATE | DELETE |
|---------|--------|--------|--------|--------|
| `facilities` | 全ユーザー | 管理者のみ | 管理者のみ | 管理者のみ |
| `posts` | 全ユーザー | ログインユーザー（自分のみ） | 自分のみ | 自分のみ |
| `favorites` | 自分のみ | ログインユーザー（自分のみ） | — | 自分のみ |
| `visits` | 自分のみ | ログインユーザー（自分のみ） | — | — |
| `user_rankings` | 全ユーザー | — | DB トリガーのみ | — |
| `inquiries` | 管理者のみ | 全ユーザー | 管理者のみ | 管理者のみ |
| `user_badges` | 自分のみ | DB トリガーのみ | — | — |

---

## 3. 環境変数（.env）の管理

`.env` ファイルはリポジトリに **絶対にコミットしない**。

```
# .gitignore に必ず含めること
.env
.env.*
```

CI/CD（GitHub Actions 等）では Secrets に環境変数を登録し、
ビルド時にインジェクションする。

---

## 4. 今後の対応推奨事項

| 優先度 | 対応内容 |
|--------|---------|
| 🔴 高 | Supabase `service_role` キーのローテーション |
| 🔴 高 | `GOOGLE_DIRECTIONS_API_KEY` を Supabase Secrets に登録して Edge Function をデプロイ |
| 🟡 中 | Google Maps SDK キーに Bundl ID / パッケージ名制限を設定 |
| 🟡 中 | Directions API 専用キーを別途発行（Maps SDK とは分離する） |
| 🟢 低 | Sentry でエラーログを監視し、APIキー漏洩の早期検知 |
