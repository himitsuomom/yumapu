# Yu-Map — 修正内容の説明

## プロジェクト概要
Yu-Mapは、施設情報を地図上に表示するFlutterアプリケーションです。包括的なコードレビューにより19件の問題を発見し、すべて修正しました。

---

## 重大な修正 (Critical) — 4件

### 1. SQLインジェクション脆弱性の修正
**ファイル:** `lib/services/facility_service.dart`, `lib/services/supabase_service.dart`

**問題:** ユーザー入力を直接ILIKEクエリに埋め込んでおり、`%` や `_` などのワイルドカード文字がサニタイズされていませんでした。

**解決策:**
- `lib/core/utils/query_utils.dart` に共通の `sanitizeLikeInput()` 関数を作成
- `%`, `_`, `\` をエスケープして安全なクエリを構築
- 両サービスから共通ユーティリティを参照する形に統一

### 2. Facility.fromJson フィールド名不一致の修正
**ファイル:** `lib/domain/entities/facility.dart`

**問題:** `fromJson` では `json['lat']`/`json['lng']` のみを期待していましたが、サービス層のSELECT句では `latitude`/`longitude` を取得しており、すべての座標が `0.0` になっていました。

**解決策:**
- `latitude`/`longitude` を優先的に読み取り、存在しない場合は `lat`/`lng` にフォールバック
- RPC結果と直接SELECT結果の両方に対応

### 3. app_config.dart のセキュリティ改善
**ファイル:** `lib/core/config/app_config.dart`, `lib/main.dart`

**問題:** デフォルト値に `'https://your-project.supabase.co'` などのプレースホルダーがハードコードされており、本番環境で無効なURLに接続するリスクがありました。

**解決策:**
- デフォルト値を空文字に変更
- 各getterで空チェック → `StateError` をスロー
- `validate()` メソッドで起動時に早期検出
- `main.dart` で設定エラー時にユーザーフレンドリーなエラーUIを表示

### 4. テストファイルの書き直し
**ファイル:** `test/facility_service_test.dart`

**問題:** `SupabaseClient` を手動で `implements` したモックが、Supabase v2のAPI署名と一致せず実行不可能でした。

**解決策:**
- `mocktail` パッケージベースの簡潔なモックに移行
- 全エンティティの `fromJson`/`toJson` ラウンドトリップテストを追加
- レーティングバリデーション（範囲外拒否）のエッジケーステスト追加

---

## 重要な改善 (Major) — 5件

### 5. 全エンティティに toJson()/copyWith() 追加
**ファイル:** `lib/domain/entities/*.dart`

- Facility, Review, User, UserRanking すべてに `toJson()` と `copyWith()` を追加
- データの保存・送信・状態更新が容易に

### 6. SubscriptionService メモリリーク修正
**ファイル:** `lib/services/subscription_service.dart`

- `listenToPremiumStatus()` の呼び出し前に既存リスナーを `cancel()`
- `onError` ハンドラー追加、`isInitialized` フラグ追加
- `purchasePremium()` に戻り値 `bool` を追加

### 7. キャッシュ戦略の改善
**ファイル:** `lib/services/facility_service.dart`

- 検索ごとの全キャッシュ破棄 → 追加的キャッシュに変更
- TTL（10分有効期限）と最大サイズ（200件）制限を実装
- `_CacheEntry` クラスで有効期限を管理

### 8. MapClusteringService の安全化
**ファイル:** `lib/services/map_clustering_service.dart`

- `late ClusterManager` → nullable `ClusterManager?` に変更
- `updateItems()` 呼び出し時の `isInitialized` ガード追加
- `dispose()` メソッド追加

### 9. Review rating バリデーション
**ファイル:** `lib/domain/entities/review.dart`

- `fromJson` で1〜5の範囲チェック、範囲外は `FormatException` をスロー
- コンストラクタに `assert` 追加
- `content` が `null` の場合は空文字にフォールバック

---

## 軽微な改善 (Minor) — 10件

| # | ファイル | 改善内容 |
|---|---------|---------|
| 10 | `ad_service.dart` | 実際のBannerAd/AdWidget実装、ローディングガード、dispose() |
| 11 | `analytics_service.dart` | 全メソッドにtry-catch、logSearch()追加、routeオブザーバー |
| 12 | `app.dart` | Material 3 `colorSchemeSeed`、ダークテーマ対応 |
| 13 | `research_summary.py` | `datetime.utcnow()` → `datetime.now(timezone.utc)` |
| 14 | Edge Functions | Deno std 0.208.0、JWT認証、CORS、入力バリデーション |
| 15 | SQLスキーマ | visits日次重複防止、amenities JSONB列、GIN/GiSTインデックス |
| 16 | SQLスキーマ | RLSポリシー拡張（visits, facility_reports等）、updated_atトリガー |
| 17 | `supabase_service.dart` | 共通sanitizeLikeInput使用、重複コード削除 |
| 18 | `main.dart` | 設定未構成時のエラーUI表示 |
| 19 | `README.md` | 日本語プロジェクトドキュメント作成 |

---

## 技術的な詳細

### 共通ユーティリティ
- `lib/core/utils/query_utils.dart` に `sanitizeLikeInput()` を集約
- `FacilityService` と `SupabaseService` の両方から参照

### キャッシュ管理
- `_CacheEntry<T>` クラスで TTL を管理
- `_evictExpired()` で期限切れエントリを自動除去
- `_enforceCacheLimit()` で最大件数を維持（FIFO方式）

### Supabase統合
- GENERATED ALWAYS列 (`total_points`) への直接書き込みを回避
- `maybeSingle()` を使用してnull安全なクエリを実行
- Edge Functionsで `supabase.auth.getUser(token)` によるJWT検証

### データベース設計
- PostGIS `GEOGRAPHY(POINT, 4326)` で正確な地理計算
- `latitude`/`longitude` を GENERATED ALWAYS列として自動計算
- `pg_trgm` による名前の部分一致検索の高速化
