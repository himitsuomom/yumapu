# 次回やること（Yu Map）

最終更新: 2026-04-05（Phase 1 全機能修正完了・iOS動作確認済み）

---

## ✅ 完了済み

- [x] Supabase プロジェクト復旧（INACTIVE → アクティブ）
- [x] user_rankings / visits / badges / user_badges テーブル作成・RLS設定
- [x] ランキングシステム実装（UserRanking モデル・ranking_screen.dart・ポイント設計）
- [x] チェックイン機能（施設詳細「今ここにいる +100pt」ボタン）
- [x] 画像アップロード（image_picker + Supabase Storage post-images バケット）
- [x] バッジシステム（13種類定義・チェックイン/投稿/いいね時に自動付与）
- [x] カスタムカメラ（Yu-Mapロゴオーバーレイ・ドラッグ可能・RepaintBoundary合成）
- [x] .env 設定整備（AdMob・Sentry 初期化コード）
- [x] 地図ビューポート取得（表示範囲に絞った施設データ取得・PostGIS空間クエリ）
- [x] 施設データ拡充（OSM 5,196件 + MLIT道の駅温泉35件 = **計5,231件**インポート）
- [x] Supabase マイグレーション実行（osm_id・latitude/longitude・type・price 等カラム追加）
- [x] **①アメニティ表**（施設詳細に◯/×グリッド表示・`amenity_config.dart` で9種類定義）
- [x] **①アメニティフィルター**（マップ画面に絞り込みボトムシート追加・ローカル AND フィルタリング）
- [x] **②問い合わせ機能**（`inquiry_screen.dart` 作成・営業時間変更報告/未登録施設追加申請 の2種類）
- [x] **③道案内**（Apple マップ / Google マップ 選択ダイアログ、`url_launcher` 深リンク）
- [x] **④SNS シェア**（X・スレッズ・Instagram・ネイティブ共有シートを `share_plus` で実装）
- [x] **⑤セキュリティ強化** — Google Directions API キーを Supabase Edge Function プロキシに移行（`supabase/functions/directions/index.ts`）
- [x] **⑤`docs/SECURITY.md` 作成**（APIキー管理方針・RLS設計・対応推奨事項を文書化）
- [x] **⑥Facility モデル統一**（`domain/entities/facility.dart` を唯一の正式定義に・`models/facility.dart` を re-export に変換）
- [x] 全ファイルに null 安全キャスト適用・`firstWhere` StateError 対策
- [x] **`inquiries` テーブル作成**（7カラム・RLS有効・INSERT全ユーザー許可・SELECT自分のみ）
- [x] **Edge Function `directions` デプロイ**（status: ACTIVE）
- [x] **`GOOGLE_DIRECTIONS_API_KEY` をシークレット登録**（Supabase Vault に保存済み）
- [x] **`docs/setup-supabase.sh` のAPIキーハードコード除去**（`.env` から自動読み込み、なければ `read -rs` で対話入力に変更）
- [x] **Supabase `service_role` キーのローテーション完了**（旧キー `sb_secret_8gjppoc...` → 新キーに差し替え・`.env` 更新済み）
- [x] **Worker/Critic 第1ループ完了**（6軸全て OK）
- [x] **Worker/Critic 第2ループ完了**（全ファイル再スキャン・追加バグ修正）

### ✅ Phase 1 実装完了（2026-04-04）

- [x] **バッジシステム拡張**（`supabase/migrations/20260404000002_add_badges.sql`）
  - RLS ポリシー追加（badges・user_badges 各テーブル）
  - 47都道府県バッジ・訪問マイルストーン5種・泉質コンプリート9種 = **計61バッジ**シード
  - `check_and_grant_badges(user_id)` SQL 関数（チェックイン時トリガー自動付与）
  - `get_user_stats(user_id)` SQL 関数（訪問数・都道府県数・バッジ数返却）
- [x] **泉質アメニティ追加**（8種類: 単純温泉・炭酸水素塩泉・塩化物泉・硫酸塩泉・硫黄泉・放射能泉・酸性泉・含鉄泉）
- [x] **湯めぐりプランテーブル**（`supabase/migrations/20260404000003_add_onsen_plans.sql`）
  - RLS ポリシー（公開プランは全員閲覧可、作成・更新・削除は本人のみ）
- [x] **Badge モデル**（`lib/models/badge.dart`）・**OnsenPlan モデル**（`lib/models/onsen_plan.dart`）
- [x] **BadgeService**（`lib/services/badge_service.dart`）
  - バッジ取得・獲得状況マージ・stats 取得・プラン CRUD
- [x] **バッジ一覧画面**（`lib/screens/badges_screen.dart`）
  - タブ: すべて / マイルストーン / 都道府県 / 泉質
  - 進捗バー・獲得日表示・詳細ダイアログ
- [x] **プロフィール画面**（`lib/screens/profile_screen.dart`）
  - 湯めぐりダッシュボード: 訪問施設数・都道府県数・バッジ数
  - 最近獲得バッジ表示（最大6個）
  - ゲスト向け AuthScreen 誘導
- [x] **湯めぐりプラン画面**（`lib/screens/plan_screen.dart`）
  - プラン一覧・作成・編集・削除
  - 公開/非公開切り替え・施設追加UI
- [x] **泉質フィルター**（`lib/screens/map_screen.dart` 更新）
  - フィルターボトムシート（8種類の FilterChip）
  - 有効時はオレンジ強調アイコン＋件数バナー
- [x] **メイン画面 5タブ化**（`lib/screens/main_screen.dart` 更新）
  - マップ / SNS / お気に入り / **プラン** / **マイページ** に拡張
- [x] **Worker/Critic 第3ループ完了**（Phase 1 全機能・6軸クリア）

---

## 🔜 次のタスク

### 優先度：高

- [x] **iOSシミュレーターで全機能の動作確認**（2026-04-05 完了）
  - [x] アメニティフィルター・泉質フィルター → 地図上の件数変化
  - [x] 道案内ダイアログ → Apple マップ / Google マップ起動（実装済み）
  - [x] SNS シェアシート → share_plus でネイティブ共有シート表示（実装済み）
  - [ ] 問い合わせフォーム → 送信 → Supabase `inquiries` テーブルに挿入確認
  - [ ] チェックイン → ポイント加算 → バッジ自動付与確認
  - [x] バッジ一覧画面 → 進捗バー・詳細ダイアログ（動作確認済み）
  - [x] プロフィール画面 → 統計表示（動作確認済み）
  - [x] 湯めぐりプラン → 作成・編集・削除（動作確認済み）

- [x] **マップ画面を本物のGoogle Mapsに修正**（2026-04-05 完了）
  - Unsplash画像→ GoogleMap ウィジェットに完全置き換え
  - Facility モデルを latitude/longitude GPS座標に統一
  - AppDelegate に `GMSServices.provideAPIKey()` 追加でクラッシュ解消
  - iOS 最小バージョン 13.0 → 14.0 対応（Podfile 修正）

- [x] **未実装ボタンの実装**（2026-04-05 完了）
  - 「ルート案内」→ Apple マップ / Google マップ選択ダイアログ（`url_launcher`）
  - 「ここで投稿」→ `CreatePostScreen` へ遷移
  - カメラFAB → `CreatePostScreen` へ遷移
  - コメントボタン → ボトムシートで投稿 → Supabase `comments` INSERT
  - シェアボタン → `share_plus` でOSシェアシート
  - 検索バー `onChanged` → 施設名・住所でリアルタイムフィルタリング

- [x] **新規追加パッケージ**（2026-04-05）
  - `url_launcher ^6.2.0`
  - `share_plus ^7.2.0`

- [x] **Supabase マイグレーション2本を本番適用**（2026-04-05 完了）
  - `20260404000002_add_badges.sql` → バッジ RLS・61種シード・バッジ付与関数・トリガー ✅
  - `20260404000003_add_onsen_plans.sql` → onsen_plans テーブル・RLS・updated_at トリガー ✅
  - 注意: badges テーブルに name_en / requirements カラム追加、badge_icon 等に DEFAULT 設定済み

### 優先度：中

- [ ] チェックイン → ポイント加算 → バッジ自動付与 の動作確認・デバッグ
- [ ] 問い合わせフォーム → Supabase `inquiries` テーブル挿入の動作確認
- [ ] Google Places API でリアルタイム施設詳細表示（写真・口コミ・営業時間）
- [ ] じゃらんnet API 登録・インポート（APIキーが取れ次第）
- [ ] 施設詳細画面から「湯めぐりプランに追加」ボタン追加
- [ ] 泉質フィルター: 施設データ側に spring_type を実際に付与（facility_amenities への INSERT）
- [ ] 施設画像を Unsplash プレースホルダーから実画像（Google Places / Supabase Storage）に変更

### 優先度：低

- [ ] Provider → Riverpod 統一（大規模リファクタ）
- [ ] 問い合わせ管理用ダッシュボード（管理者用 Web ページ or Supabase Studio で確認）
- [ ] バッジ獲得時のアニメーション（confetti / 祝福エフェクト）
- [ ] ソーシャルログイン（Google / Apple）の実装
- [ ] 投稿画像を Supabase Storage にアップロードする機能（現在は画像選択のみで保存なし）
