# YuMap 設計ルール — リグレッション防止チェックリスト

修正のたびに新バグが発生した反省を踏まえた、設計・実装時の強制ルール。
コードレビューでこのリストを必ず確認すること。

---

## ルール 1: タブインデックスは定数で一元管理する

**根拠**: タブ構成を変更したとき、分散した数値リテラルを一括で更新できず、
通知ナビゲーションのインデックスがズレた（`like/comment→tab2=お気に入り` に飛んだ）。

```dart
// NG: マジックナンバーを各所に散布
pendingTabSwitch.value = 2; // feed?

// OK: 定数で一元管理
abstract class AppTabs {
  static const explore  = 0;
  static const home     = 1;
  static const favorites = 2;
  static const profile  = 3;
}
pendingTabSwitch.value = AppTabs.home;
```

**チェック**: タブ構成を変えるときは `AppTabs` 定数を先に更新し、
コンパイルエラーで漏れを検出できる設計にする。

---

## ルール 2: 蓄積リスト（accumulated）パターンには空状態チェックを必ず追加する

**根拠**: `addPostFrameCallback` で `setState` する前のフレームで
`_accumulatedFacilities.isEmpty` が true になり、一瞬「施設が見つかりません」が表示された。

```dart
// NG: データ到着中に空状態を見せてしまう
if (_accumulatedFacilities.isEmpty) {
  return EmptyWidget(...);
}

// OK: providerの値も確認してからEmptyWidgetを表示
if (_accumulatedFacilities.isEmpty) {
  if (facilityAsync.valueOrNull?.isNotEmpty ?? false) {
    return const LoadingWidget(); // データ待ち
  }
  return EmptyWidget(...); // 本当に空
}
```

---

## ルール 3: 画面統合時はフィーチャーパリティチェックを実施する

**根拠**: MapScreen + SearchScreen を ExploreScreen に統合した際、
アメニティ絞り込みチップが隠れた（ピッカーボタンに変わり、見つけにくくなった）。

**統合時の必須チェックリスト**:
- [ ] 旧画面の全フィルター項目が新画面でも操作可能か
- [ ] ユーザーが学習コストなしに同じ機能を発見できるか（見た目が維持されているか）
- [ ] 両方の旧画面で動いていた機能が新画面でも動くか

---

## ルール 4: すべてのインタラクティブUIはタップ時に必ずフィードバックを返す

**根拠**: ゲストユーザーがいいねボタンをタップしても何も起きなかった。
`onTap: null` は Flutter が入力を丸ごと無視するため、UXとして "壊れている" に見える。

```dart
// NG: ゲストのタップを無視
onTap: isSignedIn ? () { like(); } : null,

// OK: ゲストにも理由を伝える
onTap: () async {
  if (!isSignedIn) {
    await GuestRestrictionDialog.show(context, featureName: 'いいね');
    return;
  }
  like();
},
```

**原則**: `onTap: null` を使ってよいのは、ボタンが視覚的に「無効（disabled）」と
明確に表現されている場合のみ（グレーアウト、`isDisabled` などの明示的な状態）。

---

## ルール 5: テキストの色は必ず明示する（背景が固定の場合）

**根拠**: `FacilityPreviewSheet` のシート背景が `Colors.white` に固定なのに、
施設名テキストの色が未指定のため、テーマ設定によっては薄い色で表示された。

```dart
// NG: 背景が白固定なのにテキスト色が未指定
Text(facility.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),

// OK: 背景色に合わせて色を明示
Text(facility.displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
```

**原則**: Container/Card の `color` を固定値（`Colors.white` など）にした場合、
その内側のテキスト色も明示的に設定する。テーマ依存を混在させない。

---

## ルール 6: ビルドは必ず `.env` を読み込んで行う

**根拠**: `--dart-define-from-file=.env` なしでビルドすると Supabase クライアントが
null になり、検索・いいね・設備フィルターなど全機能が無音で壊れる。

```bash
# 常にこれを使う
flutter run --dart-define-from-file=.env
flutter build ios --simulator --debug --dart-define-from-file=.env
```

**警告システム**: `facilityServiceProvider` が null のとき `debugPrint` だけでなく
開発環境では AssertionError を投げる設計にする（本番では無視）:

```dart
assert(() {
  if (supabase == null) {
    throw AssertionError('Supabase client is null. Build with --dart-define-from-file=.env');
  }
  return true;
}());
```

---

## ルール 7: コミット前テストチェックリスト

実装完了 → コミットの間に、以下を必ず手動確認する:

| 確認項目 | 確認方法 |
|---------|---------|
| 施設リストが表示される | ExploreScreen を開いて施設が表示されることを確認 |
| フィルターチップが見える | 温泉・銭湯などのタイプチップ、駐車場などのアメニティチップが表示 |
| アメニティで絞り込める | 「駐車場」チップをタップして結果が変わることを確認 |
| いいねが動く（ログイン時） | フィードでいいねボタンをタップ → 即座に赤♥に変わる |
| いいねがダイアログを出す（ゲスト） | ゲストでいいね → 「ログインが必要です」ダイアログ表示 |
| 地図マーカータップ → 施設名が読める | マーカーをタップしてプレビューシートの施設名が濃く表示 |
| 通知タップ → 正しいタブに遷移 | like通知 → ホームタブ、follow通知 → プロフィールタブ |

---

## ルール 8: 状態管理プロバイダーは責務を明確に分離する

**根拠**: `mapSearchParamsProvider` と `facilitySearchParamsProvider` が
統合画面で混在すると、マップのフィルターとリストのフィルターが干渉する。

- `mapSearchParamsProvider` → MapScreen のマーカー絞り込み専用
- `facilitySearchParamsProvider` → ExploreScreen/SearchScreen のリスト専用
- これら2つを同じ画面で同期させる場合は明示的な橋渡しロジックを書く（暗黙の共有禁止）
