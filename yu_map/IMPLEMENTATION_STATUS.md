# Yu-Map Implementation Status

## Architecture Overview

```
lib/
├── core/
│   ├── config/app_config.dart          # --dart-define 環境変数 (Supabase, Maps, RevenueCat, Sentry)
│   ├── router/app_router.dart          # GoRouter 12ルート, auth-aware redirect
│   ├── theme/app_theme.dart            # Material 3 light/dark テーマ
│   └── utils/query_utils.dart          # ILIKE サニタイズ
├── domain/entities/
│   ├── facility.dart                   # 施設モデル (amenities 含む)
│   ├── review.dart                     # レビューモデル (rating 1-5 validation)
│   ├── user.dart                       # ユーザーモデル
│   └── user_ranking.dart               # ランキングモデル
├── providers/
│   ├── service_providers.dart          # 全12サービスの DI
│   ├── auth_providers.dart             # 認証状態管理 (AuthNotifier)
│   ├── facility_providers.dart         # 施設検索・詳細・マップ
│   ├── review_providers.dart           # レビュー CRUD + Like
│   ├── favorite_providers.dart         # お気に入り管理
│   └── user_providers.dart             # ランキング・統計・リーダーボード
├── presentation/
│   ├── screens/
│   │   ├── auth/login_screen.dart      # ログイン画面
│   │   ├── auth/signup_screen.dart     # サインアップ画面
│   │   ├── auth/password_reset_screen.dart  # パスワードリセット
│   │   ├── home/home_screen.dart       # タブナビゲーション (Map/Search/Profile)
│   │   ├── map/map_screen.dart         # Google Maps + GPS + クラスタリング + 遷移
│   │   ├── facility/facility_detail_screen.dart  # 施設詳細 + 写真 + レビュー
│   │   ├── search/search_screen.dart   # 検索・フィルタ
│   │   ├── review/review_form_screen.dart  # レビュー投稿 (rating bar)
│   │   ├── badge/badge_screen.dart     # バッジ一覧 (獲得/未獲得)
│   │   ├── leaderboard/leaderboard_screen.dart  # ランキング画面
│   │   ├── visit/visit_history_screen.dart      # 訪問履歴
│   │   ├── profile/profile_screen.dart     # プロフィール + ランキング + 統計
│   │   └── profile/edit_profile_screen.dart # プロフィール編集
│   └── widgets/
│       ├── amenity_filter_chips.dart    # アメニティフィルタ (9種類)
│       ├── facility_list_tile.dart      # 施設リスト項目
│       └── review_card.dart            # レビューカード (Like ボタン付き)
├── services/
│   ├── auth_service.dart               # Supabase Auth (email/OAuth/profile)
│   ├── facility_service.dart           # 施設検索 + LRU キャッシュ (10min/200件)
│   ├── review_service.dart             # レビュー CRUD + Like + 平均評価
│   ├── user_service.dart               # プロフィール・ランキング・統計
│   ├── photo_service.dart              # Supabase Storage 写真アップロード
│   ├── visit_service.dart              # GPS チェックイン + 重複防止
│   ├── badge_service.dart              # 7種バッジ自動付与
│   ├── favorite_service.dart           # お気に入り CRUD
│   ├── map_clustering_service.dart     # マーカークラスタリング + タップ遷移
│   ├── analytics_service.dart          # Firebase Analytics
│   ├── ad_service.dart                 # Google AdMob (Rewarded + Banner)
│   └── subscription_service.dart       # RevenueCat (AppConfig 経由キー設定)
├── app.dart                            # MaterialApp.router ルート
└── main.dart                           # Firebase/Sentry/AdMob/Supabase 初期化
```

## Completed Items

### Phase 1 — Foundation
- [x] Project structure, pubspec.yaml, analysis_options.yaml
- [x] SQL injection sanitization, cache TTL, entity toJson/copyWith
- [x] Edge Functions with JWT auth (calculate-ranking, verify-contribution)
- [x] Unit tests with mocktail

### Phase 2 — Full Application
- [x] **Authentication**: AuthService (email/password, OAuth, profile, password reset)
- [x] **Riverpod Providers**: 16 providers for DI and state management
- [x] **GoRouter Navigation**: 12 routes, auth-aware redirect, deep linking
- [x] **Theme**: Material 3, light/dark mode, onsen-blue brand
- [x] **Map Screen**: Google Maps, marker clustering, GPS, amenity filters, marker tap → detail
- [x] **Facility Detail**: Rating, amenity chips, check-in, photo gallery + upload, review list, favorites
- [x] **Search Screen**: Text search, amenity filters, result list
- [x] **Review System**: ReviewService CRUD/like, form with rating bar, interactive like button
- [x] **Profile Screen**: User info, ranking card (Riverpod), stats, quick actions, favorites
- [x] **Edit Profile**: Username, display name, bio editing
- [x] **Badge Screen**: All badges with earned/locked status display
- [x] **Leaderboard Screen**: Global ranking with podium styling
- [x] **Visit History Screen**: Chronological visit list with verified status
- [x] **Password Reset**: Email-based reset with success confirmation UI
- [x] **Photo Service**: Supabase Storage upload/list/delete with gallery picker
- [x] **Visit Service**: GPS-verified check-in, daily duplicate prevention
- [x] **Badge Service**: Rule-based auto-award (7 badge types)
- [x] **Favorite Service**: Add/remove/list favorites
- [x] **DB Schema**: favorites table with RLS
- [x] **Seed Data**: 47 prefectures, 8 facility types, 8 badges

### Phase 3 — Bug Fixes & Quality
- [x] Facility entity: added `amenities` field (was missing, caused Detail screen bug)
- [x] MapClusteringService: connected marker tap → facility detail navigation
- [x] main.dart: Firebase, Sentry, AdMob initialization with graceful fallbacks
- [x] ProfileScreen: FutureBuilder → FutureProvider (fixed infinite rebuild issue)
- [x] UserService.getVisitCount: removed duplicate query
- [x] SubscriptionService: moved API keys from hardcode → AppConfig
- [x] SupabaseService: deprecated (superseded by FacilityService)
- [x] ReviewCard: interactive Like button with optimistic UI
- [x] Tests: added amenities field coverage

## Remaining Items

### Must-have for launch
- [ ] `flutter pub get` and compile verification (requires local Flutter SDK)
- [ ] Firebase project configuration (google-services.json / GoogleService-Info.plist)
- [ ] Google Maps API key in AndroidManifest.xml and AppDelegate
- [ ] Supabase Storage bucket creation (facility-photos)
- [ ] Actual facility data import from government sources

### Nice-to-have
- [ ] Offline caching with Hive
- [ ] Push notifications
- [ ] i18n (Japanese/English) with ARB files
- [ ] Facility comparison feature
- [ ] Supabase Realtime for live review updates
- [ ] Deep linking for facility sharing (URL scheme registration)
- [ ] Business hours parsing and "open now" indicator
- [ ] Review report/flag functionality
- [ ] Congestion level display
- [ ] Route guidance integration
