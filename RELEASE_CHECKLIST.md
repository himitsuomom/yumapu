# 湯マップ — App Store / Google Play リリースチェックリスト

> バージョン 1.0.0 | 最終更新: 2026-04-27

---

## 🔴 必須（申請前に必ず完了）

### コード・ビルド

- [ ] `flutter analyze` でエラー・警告ゼロを確認
- [ ] `flutter build ios --release` が成功する
- [ ] `flutter build apk --release` または `flutter build appbundle` が成功する
- [ ] `git rm lib/features/reviews/screens/write_review_screen.dart` でデッドコード削除
- [ ] `flutter pub get && flutter pub run flutter_native_splash:create` でスプラッシュ生成

### Supabase 設定（SQL Editor で実行）

- [ ] `supabase/migrations/20260427000001_posts_update_rls.sql` を適用（posts UPDATE RLS）
- [ ] `supabase/migrations/20260427000002_review_update_rls.sql` を適用（reviews UPDATE RLS）
- [ ] `get_facility_review_summary` RPC が Supabase にデプロイ済みか確認
- [ ] `get_facility_avg_rating` RPC が Supabase にデプロイ済みか確認

### iOS 固有

- [ ] Apple Developer Program に加入済み（年間 $99）
- [ ] Bundle ID `com.yumap.app` を App Store Connect で登録済み
- [ ] Signing & Capabilities → Team を自分のアカウントに設定
- [ ] `ios/Runner/Info.plist` の NSLocationWhenInUseUsageDescription が日本語で記載済み
- [ ] `ios/Runner/Info.plist` の NSPhotoLibraryUsageDescription が日本語で記載済み
- [ ] Xcode → Product → Archive でアーカイブ作成 → App Store Connect にアップロード

### Android 固有

- [ ] Google Play Developer Console でアカウント登録済み（$25 一回払い）
- [ ] `android/app/build.gradle.kts` の applicationId が `com.yumap.app` で確定
- [ ] キーストア（JKS）ファイルを作成して署名設定済み
- [ ] `flutter build appbundle --release` で AAB ファイルを生成

### App Store Connect / Google Play Console

- [ ] アプリアイコン（1024×1024 PNG, 透過なし）をアップロード
- [ ] スクリーンショット撮影（iPhone 6.7" / 6.5" 各最低3枚）
- [ ] アプリ名: 湯マップ — 温泉・サウナ・銭湯マップ
- [ ] サブタイトル（iOS）: 温泉・銭湯・サウナを地図で探す
- [ ] 説明文を日本語で入力（下の「説明文テンプレート」参照）
- [ ] キーワード（iOS）: 温泉,サウナ,銭湯,地図,口コミ,スパ,健康
- [ ] カテゴリ: 旅行（Travel）または ライフスタイル（Lifestyle）
- [ ] プライバシーポリシーURL を入力（GitHub Pages / Notion などで公開）
- [ ] 年齢制限: 4+ または 17+（アルコール・広告の有無によって決定）
- [ ] 価格: 無料

### AppConstants 設定（ストアURL確定後）

```dart
// lib/core/constants/app_constants.dart
static const String appStoreUrl = 'https://apps.apple.com/jp/app/yu-map/id?????????';
static const String googlePlayUrl = 'https://play.google.com/store/apps/details?id=com.yumap.app';
```

---

## 🟡 推奨（V1.0 品質として望ましい）

- [ ] プライバシーポリシーを Web ページとして公開（GitHub Pages が無料で簡単）
- [ ] お問い合わせメールアドレスを設定（InquiryScreen の宛先を確認）
- [ ] Firebase Analytics の動作確認（DebugView でイベント確認）
- [ ] Sentry DSN を設定して本番クラッシュを監視
- [ ] TestFlight または内部テスト（Android）で実機動作確認
- [ ] App Store 審査ガイドライン 5.1（プライバシー）と 2.1（完成度）を確認

---

## 🟢 任意（V1.1 以降）

- [ ] アプリ内購入（RevenueCat）の商品を設定
- [ ] Google AdMob の本番広告ユニットIDを設定
- [ ] 施設データの初期投入（温泉・銭湯・サウナ 100件〜）
- [ ] App Store の「プロモーション用画像」（2560×1440）作成
- [ ] Android の「フィーチャーグラフィック」（1024×500）作成

---

## 📝 アプリ説明文テンプレート（日本語）

```
湯マップは、全国の温泉・銭湯・サウナを地図で探せるソーシャルアプリです。

【主な機能】
• 地図で周辺の温泉・銭湯・サウナを検索
• 施設のクチコミ・星評価を見る・投稿する
• お気に入り施設をリストに保存
• 湯めぐりプランを作成・管理
• チェックイン機能でバッジを獲得
• 都道府県・アメニティ・営業時間でフィルター検索

【こんな方におすすめ】
• 旅先で温泉を探したい方
• サウナブームを楽しみたい方
• お気に入りの銭湯を記録したい方
• 温泉仲間とクチコミを共有したい方
```

---

## 🔗 参考リンク

- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play Policy Center](https://play.google.com/about/developer-content-policy/)
- [Supabase Dashboard](https://app.supabase.com)
- [Firebase Console](https://console.firebase.google.com)
- [RevenueCat Dashboard](https://app.revenuecat.com)
