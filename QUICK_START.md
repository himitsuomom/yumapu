# 🚀 Yu-Map: クイックスタートガイド

## 前提条件

- Flutter SDK ≥ 3.2.0
- Dart ≥ 3.2.0
- Android SDK / iOS SDK

## セットアップ (5分)

### 1️⃣ スクリプト実行 (推奨)

```bash
cd /Users/yangdaniel/Downloads/udemy-main/yu_map
chmod +x setup_and_build.sh
./setup_and_build.sh
```

### 2️⃣ 手動実行

```bash
# 依存関係インストール
flutter pub get

# ビルドクリーン
flutter clean

# コード生成
flutter gen-l10n
flutter pub run build_runner build --delete-conflicting-outputs

# 品質チェック
flutter analyze
flutter test

# ビルド
flutter build apk --debug
```

## 実装済みの機能

### ✅ Task A: i18n ローカライゼーション
- 12個の日本語キー定義
- ARB ベースの多言語対応準備
- `AppLocalizations.of(context)!.keyName` で使用可能

### ✅ Task B: Result<T> パターン
- 統一されたエラーハンドリング
- 4つのサービスに適用完了
- `switch(result) { case Success: ... case Failure: ... }` パターン

### ✅ Task C: AppLogger
- 4つのログレベル (debug/info/warning/error)
- タグベースのフィルタリング
- 本番環境での自動切り替え

### ✅ Task D: UI コンポーネント
- ShimmerLoading (スケルトン画面)
- CommonErrorView (エラー表示)
- CommonEmptyView (空状態)
- AsyncStateView (統合状態管理)

## 使用例

### スクリーンの実装

```dart
class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(myProvider);

    return AsyncStateView<MyData>(
      isLoading: state.isLoading,
      errorMessage: state.error,
      data: state.data,
      isEmpty: state.isEmpty,
      builder: (context, data) => MyContent(data),
      shimmerBuilder: (context, idx) => MyShimmer(),
      onRetry: () => ref.refresh(myProvider),
      emptyMessage: l10n.commonMessageNoData,
    );
  }
}
```

### サービスの使用

```dart
final result = await facilityService.searchFacilities(
  searchQuery: 'onsen',
);

switch (result) {
  case Success(:final data):
    AppLogger.info('Found ${data.length} facilities', tag: 'MyService');
    state = state.copyWith(facilities: data);
  case Failure(:final exception):
    AppLogger.error('Search failed', tag: 'MyService', error: exception);
    state = state.copyWith(error: exception.message);
}
```

## トラブルシューティング

### 問題: gen-l10n で AppLocalizations が生成されない

```bash
rm -rf lib/gen_l10n/
flutter gen-l10n
```

### 問題: build_runner が失敗する

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 問題: テストが失敗する

```bash
# 単一ファイルのみテスト
flutter test test/facility_service_test.dart

# 詳細出力
flutter test test/facility_service_test.dart -v
```

## ドキュメント

- [BUILD_VERIFICATION_REPORT.md](BUILD_VERIFICATION_REPORT.md) ← ここをチェック！
- [VERIFICATION_CHECKLIST.md](VERIFICATION_CHECKLIST.md) - 検証チェックリスト
- [IMPLEMENTATION_COMPLETE.md](IMPLEMENTATION_COMPLETE.md) - 詳細ガイド
- [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md) - 概要

## 次のステップ

1. ✅ セットアップスクリプト実行
2. ✅ `flutter analyze` で 0 エラー確認
3. ✅ `flutter test` で全テスト合格確認
4. ✅ 新規スクリーン実装開始

## 📞 サポート

エラー発生時は以下を確認してください:
- Flutter バージョン: `flutter --version`
- Dart バージョン: `dart --version`
- 依存関係: `flutter pub outdated`
