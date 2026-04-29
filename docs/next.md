# 次回やること（セッション50完了後）

## セッション50 完了内容
- セッション46〜49の未コミット変更を一括コミット ✅
- UX-V28-1: プロフィール画面の重複ランキングリンク削除 ✅
  - `_GamificationCards`がランキングカードを既に表示しているため`_RankingLinkCard`を削除
- UX-V28-2: FilterBarの「今日営業中」チップを先頭に移動 ✅
  - 施設タイプの末尾→先頭に移動し、スクロールなしで即アクセス可能に
- UX-V28-3: フォロワー数ウィジェットのエラー/ロード時フォールバック表示 ✅
  - SizedBox.shrink()→「-」表示でレイアウトのガタつきを防ぐ
  - `_FollowCountBadge`に sentinel 値（count < 0 → '-'）を追加

---

## ユーザーによる手動対応が必要（優先度高）

1. **pushする** 🔴最優先
   ```bash
   cd yu_map
   git push origin feat/ci-setup
   ```

2. **Supabase migration を適用** 🔴必須
   Supabase Dashboard → SQL Editor で以下を実行：
   - `supabase/migrations/20260429000001_user_follows.sql`

3. **GitHub Pages 有効化** 🟡
   - リポジトリ Settings → Pages → Source: docs/ フォルダ
   - プライバシーポリシーURL が公開される

4. **App Store Connect / Google Play Console 登録** 🟡
   - Bundle ID: com.yumap.app
   - 登録後に AppConstants.appStoreUrl / googlePlayUrl を設定

5. **flutter pub get && flutter pub run flutter_native_splash:create** 🟡

---

## 次回の開発候補

- UX-V29分析（新たな課題がないかチェック）
- OSMインポートスクリプト実行（scripts/import_osm_facilities.py）
- appVersion を pubspec.yaml と同期確認（現在 '1.0.0'、pubspec は '1.0.0+1'）
- ランキング都道府県別フィルター（LOW priority）
- プッシュ通知（FCM）本番設定
