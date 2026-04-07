# Yu-Map（湯マップ）設計書

> フルリライト用設計書。実装前の合意文書として使用する。
> 作成日: 2026-04-07

---

## 1. 画面一覧（13画面）

| # | ファイル名 | 画面名 | 役割 | 使用Provider |
|---|-----------|--------|------|-------------|
| 1 | `auth_screen.dart` | ログイン画面 | メール・パスワードでログイン。未ログイン時のルートガード先。 | `authNotifierProvider` / `isSignedInProvider` |
| 2 | `sign_up_screen.dart` | 新規登録画面 | メール・パスワードで新規アカウント作成。 | `authNotifierProvider` |
| 3 | `main_screen.dart` | メイン（ボトムタブ） | ボトムナビゲーション。タブ: マップ・タイムライン・お気に入り・プロフィール | なし（ルーティングのみ） |
| 4 | `map_screen.dart` | マップ画面 | Google Mapsで施設をピン表示・クラスタリング。アメニティフィルター。タップで施設詳細へ。 | `facilitySearchProvider` / `supabaseClientProvider` |
| 5 | `facility_screen.dart` | 施設詳細画面 | 施設情報・アメニティ・レビュー一覧・チェックイン・お気に入り登録。AdMobバナー広告表示。 | `facilityDetailProvider` / `facilityReviewsProvider` / `favoritesProvider` / `checkInProvider` / `isPremiumProvider` |
| 6 | ~~`timeline_screen.dart`~~ | ~~タイムライン画面~~ | **今回のリライト対象外** | — |
| 7 | `profile_screen.dart` | プロフィール画面 | ユーザー情報・訪問統計・獲得バッジ・サブスクリプション状態。設定へのナビゲーション。 | `currentUserProfileProvider` / `userVisitsProvider` / `subscriptionProvider` |
| 8 | ~~`ranking_screen.dart`~~ | ~~ランキング画面~~ | **今回のリライト対象外** | — |
| 9 | `favorites_screen.dart` | お気に入り画面 | お気に入り登録した施設の一覧。施設詳細へのナビゲーション。 | `favoritesProvider` / `favoriteFacilitiesProvider` |
| 10 | `camera_screen.dart` | カメラ画面 | 施設投稿用の写真撮影。撮影後に `create_post_screen` へ遷移。 | なし（`camera` パッケージ直接使用） |
| 11 | `create_post_screen.dart` | 投稿作成画面 | レビュー本文・星評価・写真を入力してSupabaseに投稿。 | `reviewSubmitProvider` / `currentUserProfileProvider` |
| 12 | `inquiry_screen.dart` | お問い合わせ画面 | アプリへの問い合わせフォーム。Supabase `inquiries` テーブルに送信。 | `currentUserProfileProvider` |
| 13 | `route_screen.dart` | 経路案内画面 | 施設までのルートをGoogle Maps上に表示。`DirectionsService` で取得。 | `facilityDetailProvider` |

---

## 2. Provider一覧

すべてRiverpodで実装する。`ChangeNotifier`（旧来のProvider）は使用しない。

### 2.1 Auth系

| Provider名 | 種別 | State型 | 説明 |
|-----------|------|---------|------|
| `supabaseClientProvider` | `Provider<SupabaseClient?>` | `SupabaseClient?` | Supabase未設定時はnull。全Providerの依存元。 |
| `authStateProvider` | `StreamProvider<AuthState>` | `AsyncValue<AuthState>` | Supabaseの認証状態ストリーム。 |
| `sessionProvider` | `Provider<Session?>` | `Session?` | 現在のセッション。未ログイン時はnull。 |
| `isSignedInProvider` | `Provider<bool>` | `bool` | ログイン済みか否か。ルートガードで使用。 |
| `currentUserProfileProvider` | `FutureProvider.autoDispose<User?>` | `AsyncValue<User?>` | `users` テーブルからプロフィール取得。 |
| `authNotifierProvider` | `StateNotifierProvider<AuthNotifier, AsyncValue<void>>` | `AsyncValue<void>` | signIn / signUp / signOut / resetPassword アクション。 |

### 2.2 施設・検索系

| Provider名 | 種別 | State型 | 説明 |
|-----------|------|---------|------|
| `facilityServiceProvider` | `Provider<FacilityService>` | `FacilityService` | FacilityServiceのシングルトン。 |
| `facilitySearchProvider` | `StateNotifierProvider<FacilitySearchNotifier, FacilitySearchState>` | `FacilitySearchState` | 検索クエリ・フィルター・結果一覧を管理。 |
| `facilityDetailProvider` | `FutureProvider.family<Facility?, String>` | `AsyncValue<Facility?>` | 施設IDで施設詳細を1件取得。 |

**`FacilitySearchState` の型:**
```
{
  facilities: List<Facility>
  isLoading: bool
  error: String?
  searchQuery: String?
  prefectureId: String?
  facilityTypeId: String?
  amenityFilters: Map<String, bool>   // amenityCode → 選択済みか
}
```

### 2.3 レビュー系

| Provider名 | 種別 | State型 | 説明 |
|-----------|------|---------|------|
| `facilityReviewsProvider` | `FutureProvider.family<List<Review>, String>` | `AsyncValue<List<Review>>` | 施設IDでレビュー一覧取得。 |
| `reviewSubmitProvider` | `StateNotifierProvider<ReviewSubmitNotifier, AsyncValue<void>>` | `AsyncValue<void>` | レビュー投稿アクション。投稿後に `facilityReviewsProvider` をinvalidate。 |

### 2.4 お気に入り系

| Provider名 | 種別 | State型 | 説明 |
|-----------|------|---------|------|
| `favoritesProvider` | `StateNotifierProvider<FavoritesNotifier, AsyncValue<Set<String>>>` | `AsyncValue<Set<String>>` | お気に入り施設IDセット。toggle / load。楽観的更新あり。 |
| `favoriteFacilitiesProvider` | `FutureProvider.autoDispose<List<Facility>>` | `AsyncValue<List<Facility>>` | IDセットから施設オブジェクトを取得。FavoritesScreen用。 |

### 2.5 訪問・チェックイン系

| Provider名 | 種別 | State型 | 説明 |
|-----------|------|---------|------|
| `userVisitsProvider` | `FutureProvider.autoDispose<List<Visit>>` | `AsyncValue<List<Visit>>` | 現在ユーザーの訪問履歴一覧。施設名JOIN済み。 |
| `visitedFacilityIdsProvider` | `FutureProvider.autoDispose<Set<String>>` | `AsyncValue<Set<String>>` | 訪問済み施設IDセット。FacilityScreen用。 |
| `checkInProvider` | `StateNotifierProvider<CheckInNotifier, AsyncValue<void>>` | `AsyncValue<void>` | チェックインアクション。成功後に訪問Providerをinvalidate。 |

### 2.6 サブスクリプション系

| Provider名 | 種別 | State型 | 説明 |
|-----------|------|---------|------|
| `subscriptionProvider` | `StateNotifierProvider<SubscriptionNotifier, SubscriptionState>` | `SubscriptionState` | RevenueCat経由のプレミアム状態管理。（旧ChangeNotifier→StateNotifierに統一） |
| `isPremiumProvider` | `Provider<bool>` | `bool` | `subscriptionProvider` から isPremium だけ取り出す便利Provider。 |

**`SubscriptionState` の型:**
```
{
  isPremium: bool
  isLoading: bool
  error: String?
}
```

### 2.7 タイムライン系 — **今回対象外**

### 2.8 ランキング系 — **今回対象外**

### 2.9 接続状態系

| Provider名 | 種別 | State型 | 説明 |
|-----------|------|---------|------|
| `connectivityProvider` | `StreamProvider<bool>` | `AsyncValue<bool>` | ネットワーク接続状態。OfflineBannerで使用。 |

---

## 3. Service一覧

| Service名 | ファイル | 責務 | 依存 |
|----------|---------|------|------|
| `SupabaseService` | `supabase_service.dart` | Supabase汎用クライアントラッパー。直接使わず各Serviceから呼ぶ。 | `SupabaseClient` |
| `AuthService` | `auth_service.dart` | Supabase Auth操作（signIn / signUp / signOut / resetPassword）。AnalyticsへイベントをFirebase。 | `SupabaseClient` / `AnalyticsService` |
| `FacilityService` | `facility_service.dart` | 施設の検索（テキスト・アメニティフィルター・都道府県）・1件取得。Supabase RPCの `get_facilities_in_bounds` を呼ぶ。 | `SupabaseClient` |
| `MapClusteringService` | `map_clustering_service.dart` | Google Maps上のFacilityマーカーをクラスタリング。`google_maps_cluster_manager` ラッパー。 | `google_maps_cluster_manager` |
| `DirectionsService` | `directions_service.dart` | Google Directions APIで出発地〜施設間のルートPolylineを取得。 | `http` / `AppConfig.googleMapsApiKey` |
| `AdService` | `ad_service.dart` | AdMobのバナー広告・リワード広告の初期化・表示制御。ID未設定時はno-op。 | `google_mobile_ads` / `AppConfig` |
| `SubscriptionService` | `subscription_service.dart` | RevenueCatの初期化・購入・復元。Supabaseのis_premiumフラグ同期。 | `purchases_flutter` / `SupabaseClient` / `AppConfig` |
| `AnalyticsService` | `analytics_service.dart` | Firebase Analyticsへのイベント送信。未設定時はno-op。シングルトン。 | `firebase_analytics` / `AppConfig` |
| `PlatformService` | `platform_service.dart` | iOS/Android固有コード（プラットフォーム判定・URLスキーム起動等）。 | `flutter/foundation.dart` |

---

## 4. lib/ ファイル構成ツリー

```
lib/
├── main.dart                          # エントリポイント。Supabase/Firebase/Sentry/RevenueCat初期化。ProviderScope。
├── app.dart                           # MaterialApp。テーマ設定。isSignedInProviderでルートガード。
├── firebase_options.dart              # flutterfire configure生成ファイル（自動生成）
│
├── core/
│   ├── config/
│   │   ├── app_config.dart            # --dart-defineで注入する環境変数。isXxxConfiguredフラグ。
│   │   └── amenity_config.dart        # アメニティコード定義（tattoo_friendly等）と表示名マッピング。
│   ├── constants/
│   │   └── app_constants.dart         # アプリ固定定数（ページサイズ・タイムアウト等）。
│   ├── theme/
│   │   └── app_theme.dart             # MaterialTheme。カラー・フォント・ボタンスタイル。
│   ├── result/
│   │   └── result.dart                # Result<T, E> Either型（エラーハンドリング用）。
│   └── widgets/
│       ├── banner_ad_widget.dart       # AdMobバナー広告ウィジェット。
│       ├── empty_widget.dart          # 空状態表示ウィジェット。
│       ├── error_widget.dart          # エラー表示ウィジェット（再試行ボタン付き）。
│       ├── loading_widget.dart        # ローディングインジケーター。
│       └── offline_banner.dart        # オフライン時のバナー通知。
│
├── domain/
│   └── entities/
│       ├── facility.dart              # Facility Equatable entity（fromJson）。
│       ├── review.dart                # Review entity（fromJson。profiles JOINあり）。
│       ├── user.dart                  # User entity（fromJson）。
│       └── user_ranking.dart          # UserRanking entity（explorer/social/total_points）。
│
├── providers/
│   ├── auth_provider.dart             # supabaseClientProvider / authStateProvider / sessionProvider
│   │                                  # isSignedInProvider / currentUserProfileProvider / authNotifierProvider
│   ├── connectivity_provider.dart     # connectivityProvider（ネット接続状態）
│   ├── facility_provider.dart         # facilityServiceProvider / facilitySearchProvider / facilityDetailProvider
│   ├── favorites_provider.dart        # favoritesProvider / favoriteFacilitiesProvider
│   ├── review_provider.dart           # facilityReviewsProvider / reviewSubmitProvider
│   ├── visit_provider.dart            # userVisitsProvider / visitedFacilityIdsProvider / checkInProvider
│   ├── subscription_provider.dart     # subscriptionProvider / isPremiumProvider
│   ├── ranking_provider.dart          # rankingProvider
│   └── timeline_provider.dart         # timelineProvider
│
├── screens/
│   ├── auth_screen.dart               # 画面1: ログイン
│   ├── sign_up_screen.dart            # 画面2: 新規登録
│   ├── main_screen.dart               # 画面3: ボトムタブナビゲーション
│   ├── map_screen.dart                # 画面4: Google Mapsマップ
│   ├── facility_screen.dart           # 画面5: 施設詳細
│   ├── timeline_screen.dart           # 画面6: タイムライン
│   ├── profile_screen.dart            # 画面7: プロフィール
│   ├── ranking_screen.dart            # 画面8: ランキング
│   ├── favorites_screen.dart          # 画面9: お気に入り
│   ├── camera_screen.dart             # 画面10: カメラ
│   ├── create_post_screen.dart        # 画面11: 投稿作成
│   ├── inquiry_screen.dart            # 画面12: お問い合わせ
│   └── route_screen.dart              # 画面13: 経路案内
│
└── services/
    ├── supabase_service.dart          # Supabase汎用ラッパー
    ├── auth_service.dart              # 認証操作
    ├── facility_service.dart          # 施設検索・取得
    ├── map_clustering_service.dart    # マーカークラスタリング
    ├── directions_service.dart        # Google Directions API
    ├── ad_service.dart                # AdMob広告
    ├── subscription_service.dart      # RevenueCat課金
    ├── analytics_service.dart         # Firebase Analytics
    └── platform_service.dart          # プラットフォーム固有処理
```

---

## 5. データモデルとDBテーブルの対応

| Entity | Dart ファイル | Supabase テーブル |
|--------|-------------|-----------------|
| `Facility` | `domain/entities/facility.dart` | `facilities` + `facility_types` JOIN |
| `Review` | `domain/entities/review.dart` | `reviews` + `users` JOIN |
| `User` | `domain/entities/user.dart` | `users` |
| `UserRanking` | `domain/entities/user_ranking.dart` | `user_rankings` |
| `Visit` | `providers/visit_provider.dart`（インラインクラス） | `visits` + `facilities` JOIN |
| `Post`（タイムライン） | `providers/timeline_provider.dart`（インラインクラス） | `reviews` + `photos` + `users` JOIN |

---

## 6. 設計上の注意事項

1. **Provider統一**: `ChangeNotifier` は使わない。`StateNotifier` または `FutureProvider` / `StreamProvider` に統一する。
2. **Supabase未設定時の安全性**: `supabaseClientProvider` が `null` を返す場合、すべてのProviderは空データ（`AsyncData([])`）を返してクラッシュしない。
3. **RevenueCat未設定時**: `SubscriptionService.initialize()` がno-opになり、`isPremiumProvider` は常に `false`。プレミアムUIは非表示。
4. **AdMob未設定時**: `AdService` がno-opになり、バナーウィジェットは `SizedBox.shrink()` を返す。
5. **アメニティフィルター**: Supabase RPCの `get_facilities_in_bounds` にUUID配列として渡す。`amenity_config.dart` でコード→UUID変換する。
