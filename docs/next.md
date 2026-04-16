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

- [x] **問い合わせフォーム統合**（2026-04-14 完了）
  - `lib/features/inquiry/inquiry_screen.dart` を新規作成（Supabase直接アクセス版）
  - 施設詳細画面に「営業時間の変更を報告する」ボタン追加
  - 設定画面に「施設の追加を申請する」リンク追加
  - `app.dart` に `/inquiry` ルートを追加
- [x] **チェックイン後バッジ通知**（2026-04-14 完了）
  - チェックイン直後にDBトリガー処理を待機（800ms）
  - `earned_at >= checkinTime` でクエリして新規バッジを取得
  - バッジ獲得ダイアログを表示
- [x] **施設詳細からプランに追加**（2026-04-14 完了）
  - `lib/models/onsen_plan.dart` 新規作成
  - `lib/providers/plan_provider.dart` 新規作成（一覧取得・作成・施設追加/削除）
  - 施設詳細の「湯めぐりプランに追加」ボタン → ボトムシートで選択・新規作成
- [x] **フィルターバグ修正 + アメニティデータ投入**（2026-04-14 完了）
  - `filter_bar.dart` で `name` → `name_ja` に修正（無言エラーを修正）
  - `filter_bar.dart` で `value_type=number`（温度表示）を除外
  - `facility_types` テーブルに3種類シード（温泉施設・銭湯・サウナ）
  - `facilities.facility_type_id` を全5,231件に自動設定
  - `facility_amenities` に8,715件投入（天然温泉・泉質・露天風呂・宿泊 etc.）
  - `supabase/migrations/20260414000001_seed_facility_types_and_amenity_data.sql` 作成
  - `sync_facility_location` トリガー関数の `search_path` バグを修正
- [x] **バッジ獲得アニメーション**（2026-04-14 完了）
  - `confetti: ^0.7.0` パッケージ追加（`pubspec.yaml`）
  - `_BadgeCelebrationDialog` を新規実装（星型confetti + バッジ一覧 + 「やった！」ボタン）
  - チェックイン後のバッジ通知が confetti ダイアログに変更
- [x] **RPC関数 `get_facilities_in_bounds` を全面修正**（2026-04-14 完了）
  - `SET search_path TO ''` が空でPostGIS関数が見つからない問題を修正
  - `geometry`（PostGIS）→ `latitude/longitude BETWEEN` に変更（安定動作）
  - `facility_types` の INNER JOIN → LEFT JOIN に変更（NULL安全）
  - 戻り値に `latitude, longitude, facility_type_id, address` を追加
  - アメニティフィルターを OR → AND に変更（複数選択で全条件一致）
  - `supabase/migrations/20260414000002_fix_get_facilities_in_bounds.sql` 作成
- [x] **フィルターリセットバグ修正**（2026-04-14 完了）
  - `clearFacilityType: true` を map_screen（2箇所）と search_screen（1箇所）に適用
  - `facilityTypeId: null` を copyWith に渡しても既存値が残るバグを修正
- [x] **施設詳細にアメニティ表示セクションを追加**（2026-04-14 完了）
  - `facilityAmenitiesProvider` を `facility_provider.dart` に追加
  - `_AmenitySection` ConsumerWidget を施設詳細画面に追加
  - カテゴリ別アイコン・カラー付きの Wrap チップ表示
- [x] **施設詳細に営業時間・料金表示を追加**（2026-04-14 完了）
  - `Facility` エンティティに `openingHours` と `price` フィールドを追加
  - `FacilityService.getFacilityById` で `hours, price` カラムを SELECT
  - 詳細画面に時計アイコン・料金アイコン付きで表示
- [x] **posts.comments_count カラム追加 + トリガー**（2026-04-14 完了）
  - フィードのコメント数が常に0になっていたバグを修正
  - `comments_count` INTEGER DEFAULT 0 カラムを追加
  - コメントINSERT/DELETE時に自動更新するトリガーを追加
  - `supabase/migrations/20260414000005_posts_comments_count.sql` 作成
- [x] **施設タイプを日本語表示に統一**（2026-04-14 完了）
  - `Facility` に `facilityTypeJa` プロパティ追加（'onsen'→'温泉施設' 等）
  - `FacilityListTile`・施設詳細・マッププレビューで `facilityTypeJa` を使用
  - `_FacilityTypeIcon` に `public_bath` コードを追加
  - 未使用 `AmenityConfig.dart` を削除（デッドコード）
- [x] **confettiダイアログのレイアウト修正**（2026-04-14 完了）
  - `Stack` 内の `AlertDialog` が上端に配置されるバグを修正
  - `SizedBox.expand + Stack + Center` 構造に変更して画面中央に固定
- [ ] Google Places API でリアルタイム施設詳細表示（写真・口コミ・営業時間）
- [ ] じゃらんnet API 登録・インポート（APIキーが取れ次第）
- [ ] 施設画像を Unsplash プレースホルダーから実画像（Google Places / Supabase Storage）に変更

- [x] **visits テーブルに created_at カラム追加**（2026-04-14 完了）
  - `Visit.fromJson` が `created_at` を要求していたが DB に存在しなかったためクラッシュ → ALTER TABLE で追加
  - `visit_provider.dart` を null 安全に修正（`createdAt` は `visited_at` にフォールバック）
- [x] **visits DELETE ポリシー追加**（2026-04-14 完了）
  - `deleteVisit()` が RLS でブロックされていた → 「自分の訪問のみ削除可能」ポリシーを追加
- [x] **セキュリティ修正**（2026-04-14 完了）
  - `inquiries` INSERT ポリシーを `WITH CHECK (true)` → `user_id IS NULL OR user_id = auth.uid()` に強化
  - Storage SELECT ポリシーを「バケット一覧不可」に変更（avatars / post-images）
  - `handle_new_user` 関数の `SET search_path TO ''` を `= public` に修正
  - `supabase/migrations/20260414000003_security_fixes.sql` 作成

- [x] **ランキング自動更新トリガー実装**（2026-04-14 完了）
  - チェックインしても `user_rankings` が更新されない重大バグを発見・修正
  - `update_ranking_on_visit()` - 訪問時に explorer_points（訪問×100）と称号を更新
  - `update_ranking_on_review()` - レビュー投稿時に social_points 再計算
  - `update_ranking_on_post()` - SNS投稿時に social_points 再計算
  - `calc_social_points()` ヘルパー関数（レビュー×50 + 投稿×30）
  - 称号設定: 初心者→見習い→経験者→中級者→通→愛好家→上級者→マスター→王
  - `supabase/migrations/20260414000004_ranking_triggers.sql` 作成

### 優先度：低

- [ ] Provider → Riverpod 統一（大規模リファクタ）
- [ ] 問い合わせ管理用ダッシュボード（管理者用 Web ページ or Supabase Studio で確認）
- [ ] ソーシャルログイン（Google / Apple）の実装
- [x] **iOS / Android アプリ設定修正**（2026-04-14 完了）
  - `CFBundleDisplayName` を "Yu Map" → "湯マップ" に修正
  - `NSPhotoLibraryAddUsageDescription` を追加（写真保存権限）
  - `CFBundleURLSchemes` を `com.example.yuMap` → `com.yumap.app` に統一
  - Android `android:label` を "yu_map" → "湯マップ" に修正
  - iOS Bundle ID: `com.yumap.app`、Android Package: `com.yumap.app` で統一済み

### App Store 申請前に必要な手動対応

- [ ] **Google Maps API キーを本番用に制限**（Google Cloud Console）
  - iOS: バンドルID `com.yumap.app` に制限
  - Android: 署名キーの SHA-1 fingerprint に制限
- [ ] **AdMob テスト ID を本番 ID に差し替え**
  - iOS: `GADApplicationIdentifier` を本番IDに
  - Android: `com.google.android.gms.ads.APPLICATION_ID` を本番IDに
- [ ] **App Store Connect でアプリ情報を登録**
  - アプリ説明文・スクリーンショット・カテゴリ（旅行/ライフスタイル）・年齢制定（4歳以上）
- [ ] **Apple Developer Portal でプッシュ通知証明書設定**（将来的にプッシュ通知を使う場合）
- [ ] **施設データの泉質情報を外部データソース（国土地理院等）から拡充**
