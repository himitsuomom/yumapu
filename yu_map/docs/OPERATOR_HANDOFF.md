# Yu-Map (湯マップ) — Operator Handoff Guide

> Everything a non-technical operator needs to take this release candidate
> from merge to public app-store submission.

---

## 1. What Is Already Done

| Area | Status |
|------|--------|
| All 13 UI screens (auth, map, search, facility detail, reviews, favorites, profile, settings) | Fully implemented |
| Authentication (login / register / session restore / logout) | Fully implemented |
| Map browsing with Google Maps | Fully implemented |
| List browsing | Fully implemented |
| Search with text + amenity filters | Fully implemented |
| Facility detail (info, map, reviews, check-in) | Fully implemented |
| Review reading + submission | Fully implemented |
| Favorites / bookmarks | Fully implemented |
| Visit / check-in tracking | Fully implemented |
| Profile with stats + recent visits | Fully implemented |
| Settings screen | Fully implemented |
| Loading / empty / offline / error states | Fully implemented |
| Firebase Analytics event wiring (all core flows) | Fully implemented — safe no-op when unconfigured |
| Sentry error reporting | Fully implemented — safe no-op when unconfigured |
| AdMob banner ads (facility detail) | Implemented — ads hidden when IDs not configured |
| RevenueCat subscription / premium UI | Implemented — premium section hidden when keys not configured |
| Android project structure | Created and configured (com.yumap.app) |
| iOS project structure | Created and configured (com.yumap.app) |
| Safe environment/config handling | All integrations degrade gracefully |
| Unit tests (14 tests) | All passing |
| Static analysis | 0 issues |

---

## 2. Remaining Human-Only Checklist

Complete these items in order. Each item includes the exact file or location to update.

### 2.1 Supabase Backend

- [ ] **Create a Supabase project** at https://supabase.com
- [ ] Run the migration in `yu_map/supabase/migrations/20240209000000_initial_schema.sql`
- [ ] Deploy edge functions from `yu_map/supabase/functions/`
- [ ] Copy the **Project URL** and **anon key** from Supabase Dashboard → Settings → API
- [ ] Add them to your `.env` file (copy from `.env.example`):
  ```
  SUPABASE_URL=https://YOUR_PROJECT.supabase.co
  SUPABASE_ANON_KEY=eyJ...your-anon-key...
  ```

### 2.2 Google Maps API Keys

- [ ] Create a Google Cloud project at https://console.cloud.google.com
- [ ] Enable **Maps SDK for Android** and **Maps SDK for iOS**
- [ ] Create two API keys (one restricted to Android, one to iOS)
- [ ] **Android**: Add to `yu_map/android/app/src/main/AndroidManifest.xml`:
  ```xml
  <meta-data
      android:name="com.google.android.geo.API_KEY"
      android:value="YOUR_ANDROID_MAPS_KEY" />
  ```
  Also add to `yu_map/android/local.properties`:
  ```
  MAPS_API_KEY=YOUR_ANDROID_MAPS_KEY
  ```
- [ ] **iOS**: Update `yu_map/ios/Runner/AppDelegate.swift`:
  ```swift
  GMSServices.provideAPIKey("YOUR_IOS_MAPS_KEY")
  ```
- [ ] Add to `.env`:
  ```
  GOOGLE_MAPS_API_KEY=YOUR_KEY
  ```

### 2.3 Firebase (Analytics + Config)

- [ ] Create a Firebase project at https://console.firebase.google.com
- [ ] Register the Android app (`com.yumap.app`) and download `google-services.json`
- [ ] Place `google-services.json` in `yu_map/android/app/`
- [ ] Register the iOS app (`com.yumap.app`) and download `GoogleService-Info.plist`
- [ ] Place `GoogleService-Info.plist` in `yu_map/ios/Runner/`
- [ ] Enable Analytics in the Firebase console

### 2.4 AdMob (Ads)

- [ ] Create an AdMob account at https://admob.google.com
- [ ] Create an Android app and iOS app in AdMob
- [ ] Create **Banner** ad units for each platform
- [ ] Create **Rewarded** ad units for each platform (optional for v1)
- [ ] Add the ad unit IDs to `.env`:
  ```
  ADMOB_BANNER_ANDROID=ca-app-pub-XXXX/YYYY
  ADMOB_BANNER_IOS=ca-app-pub-XXXX/YYYY
  ADMOB_REWARDED_ANDROID=ca-app-pub-XXXX/YYYY
  ADMOB_REWARDED_IOS=ca-app-pub-XXXX/YYYY
  ```
- [ ] Pass them at build time:
  ```bash
  flutter build apk \
    --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-XXXX/YYYY \
    --dart-define=ADMOB_BANNER_IOS=ca-app-pub-XXXX/YYYY
  ```

> **Current behavior when IDs are missing:** Ads are completely hidden.
> The app never attempts to load an ad with an empty ID.
> No test IDs are used in release builds.

### 2.5 RevenueCat (Subscriptions)

- [ ] Create an account at https://app.revenuecat.com
- [ ] Create a project and add Android + iOS apps
- [ ] Set up products/entitlements in the RevenueCat dashboard
- [ ] Copy the **API keys** for each platform
- [ ] Add to `.env`:
  ```
  REVENUECAT_ANDROID_KEY=your_android_key
  REVENUECAT_IOS_KEY=your_ios_key
  ```

> **Current behavior when keys are missing:** The entire premium/subscription
> section is hidden from the settings screen. No purchase UI is ever shown.
> The app does not crash or present broken purchase flows.

### 2.6 Sentry (Error Reporting)

- [ ] Create a Sentry project at https://sentry.io
- [ ] Copy the DSN from Project Settings → Client Keys
- [ ] Add to `.env`:
  ```
  SENTRY_DSN=https://xxx@yyy.ingest.sentry.io/zzz
  ```

> **Current behavior when DSN is missing:** Sentry is not initialized.
> The app runs normally without error reporting.

### 2.7 App Icon

The repository currently uses the default Flutter icon. Replace it with
the custom 湯マップ icon:

#### Android (5 density buckets)

Replace these files in `yu_map/android/app/src/main/res/`:

| Directory | File | Size |
|-----------|------|------|
| `mipmap-mdpi/` | `ic_launcher.png` | 48×48 px |
| `mipmap-hdpi/` | `ic_launcher.png` | 72×72 px |
| `mipmap-xhdpi/` | `ic_launcher.png` | 96×96 px |
| `mipmap-xxhdpi/` | `ic_launcher.png` | 144×144 px |
| `mipmap-xxxhdpi/` | `ic_launcher.png` | 192×192 px |

Also replace the corresponding `ic_launcher_round.png` and
`ic_launcher_foreground.png` files if using adaptive icons.

#### iOS

Replace files in `yu_map/ios/Runner/Assets.xcassets/AppIcon.appiconset/`:

| File | Size | Usage |
|------|------|-------|
| `Icon-App-20x20@1x.png` | 20×20 | iPad Notification |
| `Icon-App-20x20@2x.png` | 40×40 | iPhone Notification |
| `Icon-App-20x20@3x.png` | 60×60 | iPhone Notification |
| `Icon-App-29x29@1x.png` | 29×29 | iPad Settings |
| `Icon-App-29x29@2x.png` | 58×58 | iPhone Settings |
| `Icon-App-29x29@3x.png` | 87×87 | iPhone Settings |
| `Icon-App-40x40@1x.png` | 40×40 | iPad Spotlight |
| `Icon-App-40x40@2x.png` | 80×80 | iPhone Spotlight |
| `Icon-App-40x40@3x.png` | 120×120 | iPhone Spotlight |
| `Icon-App-60x60@2x.png` | 120×120 | iPhone App |
| `Icon-App-60x60@3x.png` | 180×180 | iPhone App |
| `Icon-App-76x76@1x.png` | 76×76 | iPad App |
| `Icon-App-76x76@2x.png` | 152×152 | iPad App |
| `Icon-App-83.5x83.5@2x.png` | 167×167 | iPad Pro App |
| `Icon-App-1024x1024@1x.png` | 1024×1024 | App Store |

> **Tip:** Use a tool like https://appicon.co to generate all sizes from
> a single 1024×1024 source image.

### 2.8 Legal & Support

- [ ] **Privacy Policy URL** — Create and host a privacy policy page. Add the URL to:
  - App Store Connect metadata
  - Google Play Console listing
  - The settings screen (currently shows placeholder)
- [ ] **Terms of Service URL** — Same as above
- [ ] **Support Email** — Decide on a support email address for store listings

### 2.9 App Signing

#### Android

- [ ] Generate a signing keystore:
  ```bash
  keytool -genkey -v -keystore yumap-release.keystore \
    -alias yumap -keyalg RSA -keysize 2048 -validity 10000
  ```
- [ ] Create `yu_map/android/key.properties`:
  ```
  storePassword=<your_password>
  keyPassword=<your_password>
  keyAlias=yumap
  storeFile=<path_to>/yumap-release.keystore
  ```
- [ ] **Do not commit the keystore or key.properties**

#### iOS

- [ ] Enroll in the Apple Developer Program ($99/year)
- [ ] Create an App ID for `com.yumap.app` in the Developer portal
- [ ] Create provisioning profiles (development + distribution)
- [ ] Configure signing in Xcode under Signing & Capabilities

### 2.10 Store Accounts

- [ ] **Google Play Console** — Register at https://play.google.com/console ($25 one-time)
- [ ] **Apple App Store Connect** — Access via https://appstoreconnect.apple.com (requires Apple Developer membership)

---

## 3. Store Screenshot Shot List

Capture these screens on real devices for both Android and iOS submissions.

### Required Screenshots (minimum per store)

| # | Screen | Description |
|---|--------|-------------|
| 1 | **Map browsing** | Map view with several facility markers visible |
| 2 | **Search results** | Search screen showing filtered facility list |
| 3 | **Facility detail** | A facility detail screen with reviews visible |
| 4 | **Favorites list** | Favorites screen with saved facilities |
| 5 | **Profile** | Profile screen showing visit stats |
| 6 | **Login** | Auth screen (register/login) |

### Device Sizes Needed

**Android (Google Play):**
- Phone: 1080×1920 or higher (e.g., Pixel 6)
- Tablet (optional): 1200×1920 or higher

**iOS (App Store):**
- 6.7" display (iPhone 15 Pro Max): 1290×2796
- 6.1" display (iPhone 15 Pro): 1179×2556
- 5.5" display (iPhone 8 Plus): 1242×2208 (if supporting older devices)
- iPad Pro 12.9": 2048×2732 (if supporting iPad)

---

## 4. Store Metadata Drafts

### App Name
`湯マップ`

### Short Description (Google Play, max 80 chars)
`日本の温泉・銭湯・サウナを地図で探す・レビュー・チェックイン`

### Full Description (draft)
```
湯マップは、日本全国の温泉、銭湯、サウナ施設を簡単に発見できるアプリです。

主な機能：
・地図上で近くの施設を探す
・施設名やアメニティで検索・フィルタリング
・施設の詳細情報を確認
・レビューを読む・書く
・お気に入り施設を保存
・チェックインで訪問記録を管理

温泉好きのための必須アプリ。お気に入りの湯処を見つけましょう！
```

### Category
- **Google Play:** Travel & Local
- **App Store:** Travel (primary), Lifestyle (secondary)

### Content Rating
- IARC: suitable for all ages (no objectionable content)

### Keywords (App Store, max 100 chars)
`温泉,銭湯,サウナ,onsen,sento,sauna,入浴,湯,地図,レビュー`

---

## 5. Build & Release Commands

### Development Build (with test config)

```bash
cd yu_map
flutter pub get
flutter run
```

### Production Build — Android

```bash
cd yu_map
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key \
  --dart-define=GOOGLE_MAPS_API_KEY=your_key \
  --dart-define=ADMOB_BANNER_ANDROID=ca-app-pub-XXXX/YYYY \
  --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-XXXX/YYYY \
  --dart-define=REVENUECAT_ANDROID_KEY=your_key \
  --dart-define=SENTRY_DSN=your_dsn
```

The output `.aab` file will be at
`build/app/outputs/bundle/release/app-release.aab`.
Upload this to Google Play Console.

### Production Build — iOS

```bash
cd yu_map
flutter build ipa --release \
  --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your_anon_key \
  --dart-define=GOOGLE_MAPS_API_KEY=your_key \
  --dart-define=ADMOB_BANNER_IOS=ca-app-pub-XXXX/YYYY \
  --dart-define=ADMOB_REWARDED_IOS=ca-app-pub-XXXX/YYYY \
  --dart-define=REVENUECAT_IOS_KEY=your_key \
  --dart-define=SENTRY_DSN=your_dsn
```

Open the resulting `.xcarchive` in Xcode → Distribute App → App Store Connect.

---

## 6. Exact Next Step After Merge

1. **Merge PR #16** to `main`.
2. Clone fresh and verify `flutter pub get && flutter analyze && flutter test` pass.
3. Work through the checklist in Section 2 above, starting with Supabase.
4. Once credentials are in `.env`, run `flutter run` on a real device to verify.
5. Replace the app icon (Section 2.7).
6. Capture store screenshots (Section 3).
7. Fill in legal URLs (Section 2.8).
8. Build release binaries (Section 5).
9. Upload to Google Play Console and App Store Connect.
10. Submit for review.

---

## 7. Safe Fallback Behavior Summary

| Integration | When Configured | When Not Configured |
|-------------|-----------------|---------------------|
| **Supabase** | Full data access | All providers return empty state; no crashes |
| **Google Maps** | Interactive maps with markers | Map widget may show blank; no crash |
| **AdMob** | Banner ads shown in facility detail | Ads completely hidden; MobileAds never initialized |
| **RevenueCat** | Premium section in settings; paywall | Premium section hidden; no purchase UI shown |
| **Firebase Analytics** | Events logged for all core flows | Service stays in no-op state; all calls silently ignored |
| **Sentry** | Errors reported to dashboard | Sentry not initialized; app runs normally |
