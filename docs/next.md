# 次回やること（セッション44完了後）

## セッション44 完了内容
- フォロー機能実装（HIGH課題）✅
  - Supabase migration: `user_follows` テーブル + RLS + 3つのRPC関数
  - `lib/providers/follow_provider.dart` 新規作成
  - `lib/providers/post_provider.dart`: フォロー中フィルター追加
  - `lib/features/feed/screens/feed_screen.dart`: タブ分割（すべて/フォロー中）+ フォローボタン
  - `lib/features/ranking/screens/ranking_screen.dart`: フォローボタン追加
  - `lib/providers/ranking_provider.dart`: userId ゲッター追加

## セッション43完了内容（フォロー前）
- 地図画面右下に施設タイプ凡例カード追加 ✅
- 地図画面にフィルター/検索ヒット件数バナー追加 ✅
- フィード投稿者アバター・名前タップで著者プロフィールシート表示 ✅
- 検索画面⋮メニューに「お気に入りに追加/解除」追加 ✅
- バッジ未獲得カードにbadge.requirementTextを表示 ✅
- プロフィール画面アバターにカメラアイコン重ね、タップで編集画面へ遷移 ✅
- 設定画面テーマセクションのラベルを「外観」に変更 ✅

---

## ユーザーによる手動対応が必要（優先度高）

1. **git commit を手動実行** 🔴最優先
   ```bash
   cd yu_map
   git add -A
   git commit -m "feat: セッション43-44 フォロー機能・UX改善13件"
   git push origin main
   ```
   > ⚠️ git lock ファイルが原因でスクリプトからコミットできない状態。
   > macOS Finderまたはターミナルから `rm yu_map/.git/index.lock` を実行後にコミット。

2. **Supabase migration を適用** 🔴必須
   Supabase Dashboard → SQL Editor で以下を実行：
   - `supabase/migrations/20260428000001_trending_facilities_rpc.sql`
   - `supabase/migrations/20260429000001_user_follows.sql` ← 今回追加

3. **`flutter pub get` を実行** 🔴必須
   ```bash
   flutter pub get
   ```

4. **スプラッシュ画面を生成** 🟡中
   ```bash
   flutter pub run flutter_native_splash:create
   ```

5. **GitHub Pages 有効化** 🟡中
   git push後、リポジトリ Settings → Pages → Source: docs/
   プライバシーポリシーURL: `https://<username>.github.io/<repo>/legal/privacy.html`

---

## 次の自動タスク候補

### HIGH
- なし（フォロー機能実装でHIGH課題は全て解決）

### MEDIUM（次セッションの候補）
1. **プッシュ通知** — いいね・コメント・フォロー時の通知（Firebase Cloud Messaging）
2. **ランキング 都道府県別フィルター** — 地域絞り込み機能
3. **施設詳細画面のリファクタリング** — 1506行の大ファイルを分割

### リリース関連（ユーザー作業）
詳細は `RELEASE_CHECKLIST.md` を参照。
- App Store Connect でアプリ登録（Bundle ID: com.yumap.app）
- Google Play Console でアプリ登録
