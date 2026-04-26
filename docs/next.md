# 次回やること（セッション30完了後）

## 完了済み（セッション30）
- Bug-V12-1: 地図検索バーの文字入力がgeo-bounds検索時に無視される問題を修正 ✅
  → facility_service.dart: _searchByBounds()結果をclient-sideでsearchQueryフィルタリング
- UX-V12-1: 地図検索バーのhintTextを「施設名・エリアで検索」に更新 ✅
- 検索画面に「もっと見る」ページネーション実装 ✅
  → _accumulatedFacilities でページを蓄積、フィルター変更時はリセット
- withOpacity → withAlpha に修正（deprecated警告解消）✅
- splash_logo.png の壊れたファイルを有効なPNG（温泉桶アイコン）に置き換え ✅
- コードスキャン: TODO/FIXME残存なし・print()なし確認済み ✅

## セッション29で手動対応待ち（まだ未実施）
- Supabase migration適用: 20260427000001_posts_update_rls.sql をSQL Editorで実行
- スプラッシュ生成: `flutter pub get && flutter pub run flutter_native_splash:create`
  ※ splash_logo.png は今セッションで修正済みなので、実行すれば有効なスプラッシュが生成できる
- git commit: index.lock が残存のため手動で実施
  `rm .git/index.lock && git add -A && git commit -m "feat: セッション30 Bug-V12-1修正・地図検索・ページネーション"`

## 次回タスク（優先度順）
- 本番リリース準備 🔴高
  - App Store Connect でアプリ登録
  - ストアURL確定後に AppConstants.appStoreUrl / googlePlayUrl を設定
  - スクリーンショット撮影（シミュレーターで各画面）
  - アプリ説明文・キーワード入力
- splash_logo.png の改善 🟡中
  - より洗練されたロゴデザインに差し替え（デザイナーまたはFigmaで作成後に置き換え）
- マーカーの施設タイプ別色分け 🟡中
  - 温泉=赤、銭湯=青、サウナ=緑（map_clustering_service.dartでの実装）
- 検索の都道府県フィルター UI 🟢低
  - facilitySearchParamsのprefectureIdはDB対応済みだがUIがない
