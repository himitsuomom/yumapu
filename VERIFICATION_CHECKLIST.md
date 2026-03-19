# Yu-Map 実装検証チェックリスト

このドキュメントは、4つのタスク(Task A-D、Task B-D)の実装が完了した後の検証手順です。

## 📋 実装状態確認

### Task B: Result<T> パターン統合 ✅

**作成されたファイル:**
- ✅ `lib/core/result/result.dart` - Result型定義
- ✅ `lib/core/result/run_catching.dart` - runCatching ヘルパー

**更新されたサービス:**
- ✅ `lib/services/subscription_service.dart`
- ✅ `lib/services/facility_service.dart`
- ✅ `lib/services/supabase_service.dart`
- ✅ `lib/services/analytics_service.dart`

**検証内容:**
- [ ] `flutter analyze` で Result型のインポートエラーがないか確認
- [ ] 全サービスで `Future<Result<T>>` の戻り値を使用
- [ ] ProviderやViewModelで `switch/case` で Result パターンマッチング

### Task C: AppLogger 統合 ✅

**作成されたファイル:**
- ✅ `lib/core/logger/app_logger.dart` - ログユーティリティ

**更新されたサービス:**
- ✅ `lib/services/ad_service.dart` - 2件の debugPrint を置換

**検証内容:**
- [ ] `grep -rn "debugPrint" lib/` が0件の結果を返す
- [ ] `grep -rn "print(" lib/` で残存する print() をチェック
- [ ] AppLogger の tag パラメータが適切に設定されているか

### Task D: 共有UI コンポーネント ✅

**作成されたコンポーネント:**
- ✅ `lib/core/widgets/loading/shimmer_box.dart`
- ✅ `lib/core/widgets/loading/shimmer_loading.dart`
- ✅ `lib/core/widgets/error/common_error_view.dart`
- ✅ `lib/core/widgets/empty/common_empty_view.dart`
- ✅ `lib/core/widgets/async_state_view.dart`

**検証内容:**
- [ ] shimmer パッケージが `pubspec.yaml` に存在するか確認
- [ ] AsyncStateView が4つの状態(Loading/Error/Empty/Success)を正しく処理
- [ ] CircularProgressIndicator の残存使用箇所をチェック: `grep -rn "CircularProgressIndicator" lib/`

### Task A: i18n 設定 ✅

**作成されたファイル:**
- ✅ `l10n.yaml` - ローカライゼーション設定
- ✅ `lib/l10n/app_ja.arb` - 日本語ARBテンプレート(12キー)

**更新されたファイル:**
- ✅ `pubspec.yaml` - flutter_localizations 追加
- ✅ `lib/app.dart` - localizationsDelegates 設定

**検証内容:**
- [ ] `flutter gen-l10n` を実行してコード生成
- [ ] `lib/l10n/app_ja.arb` にすべてのキーが定義されているか
- [ ] `AppLocalizations.of(context)!.keyName` でアクセス可能か

---

## 🔍 検証手順

### 1. 依存関係確認

```bash
# Flutterが利用可能か確認
flutter --version

# 必要なパッケージが pubspec.yaml に入っているか確認
grep -E "flutter_localizations|shimmer|flutter_gen" pubspec.yaml
```

### 2. コード生成とビルド

```bash
# 依存関係をインストール
flutter pub get

# l10n ファイル生成
flutter gen-l10n

# ビルドランナー実行(必要に応じて)
flutter pub run build_runner build --delete-conflicting-outputs

# コード解析
flutter analyze

# テスト実行
flutter test test/facility_service_test.dart
```

### 3. ファイル整合性確認

**ARB ファイルでのキー重複チェック:**
```bash
grep -o '"[^"]*":' lib/l10n/app_ja.arb | sort | uniq -d
# 結果が空でなければ重複あり
```

**Result型の適切な使用:**
```bash
# Future<Result< のパターンが全サービスにあるか
grep -r "Future<Result<" lib/services/

# try-catch や debugPrint が残っていないか
grep -r "try {" lib/services/
grep -r "debugPrint\|print(" lib/
```

### 4. 構造検証

**必要なディレクトリ構造:**
```
lib/
├── core/
│   ├── logger/
│   │   └── app_logger.dart ✓
│   ├── result/
│   │   ├── result.dart ✓
│   │   └── run_catching.dart ✓
│   └── widgets/
│       ├── loading/
│       │   ├── shimmer_box.dart ✓
│       │   └── shimmer_loading.dart ✓
│       ├── error/
│       │   └── common_error_view.dart ✓
│       ├── empty/
│       │   └── common_empty_view.dart ✓
│       └── async_state_view.dart ✓
├── l10n/
│   └── app_ja.arb ✓
├── domain/entities/
│   └── user_ranking.dart (i18n 対応) ✓
├── presentation/
│   ├── screens/
│   │   └── facility_list_screen_example.dart (参考例)
│   └── providers/
│       └── facility_provider_example.dart (参考例)
└── services/
    ├── facility_service.dart (Result<T> 対応) ✓
    ├── supabase_service.dart (Result<T> 対応) ✓
    ├── subscription_service.dart (Result<T> 対応) ✓
    ├── analytics_service.dart (Result<T> 対応) ✓
    └── ad_service.dart (AppLogger 対応) ✓
```

---

## 📚 統合ガイド

### UI スクリーンの実装パターン

```dart
// lib/presentation/screens/my_screen.dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:yu_map/core/widgets/async_state_view.dart';
import 'package:yu_map/core/logger/app_logger.dart';

class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(myProvider);
    
    return AsyncStateView<MyData>(
      isLoading: state.isLoading,
      errorMessage: state.error,
      data: state.data,
      isEmpty: state.isEmpty,
      builder: (context, data) => MyContent(data: data),
      shimmerBuilder: (context, index) => MyShimmer(),
      onRetry: () => ref.refresh(myProvider),
      emptyMessage: l10n.commonMessageNoData,
    );
  }
}
```

### サービス呼び出しパターン

```dart
// Provider での使用
final myProvider = StateNotifierProvider((ref) {
  final service = ref.watch(myServiceProvider);
  return MyNotifier(service);
});

class MyNotifier extends StateNotifier<MyState> {
  Future<void> fetchData() async {
    // AppLogger.debug で処理追跡
    AppLogger.debug('Fetching data...', tag: 'MyNotifier');
    
    final result = await _service.fetchData();
    
    switch (result) {
      case Success(:final data):
        AppLogger.info('Data fetched successfully', tag: 'MyNotifier');
        state = state.copyWith(data: data, error: null);
      case Failure(:final exception):
        AppLogger.error('Failed to fetch data', tag: 'MyNotifier', error: exception);
        state = state.copyWith(error: exception.message);
    }
  }
}
```

---

## ⚠️ 注意事項

1. **i18n 対応の段階的実施**
   - UIレイヤーのみに `AppLocalizations.of(context)!.keyName` を使用
   - Service/Entity層では日本語文字列は定数として保持（TODO コメント付き）

2. **Result<T> パターンの一貫性**
   - 全てのサービスメソッドが `Future<Result<T>>` を返す
   - runCatching での自動エラーハンドリングを活用

3. **ログレベルの適切な設定**
   - `AppLogger.debug()` - 開発時デバッグ情報
   - `AppLogger.info()` - 処理成功時の記録
   - `AppLogger.warning()` - 予期しない(ただし回復可能な)状態
   - `AppLogger.error()` - エラー発生時(tagnとerrorを必須指定)

4. **UI コンポーネント**
   - AsyncStateView で全ての非同期状態を統一管理
   - 個別の if/else 分岐ではなく AsyncStateView 使用を推奨

---

## 🚀 デプロイ準備

```bash
# ビルド確認
flutter build apk --debug    # Android
flutter build ios            # iOS

# コード品質チェック
flutter analyze
dart analyze lib/

# テスト実行
flutter test
```

---

## 📞 トラブルシューティング

### l10n生成エラー
```bash
# l10n.yaml の設定を確認
cat l10n.yaml

# 手動クリーン
rm -rf lib/gen_l10n/
flutter gen-l10n
```

### インポートエラー
```bash
# pubspec.yaml インポート確認
flutter pub get

# ビルドランナー再実行
flutter pub run build_runner build --delete-conflicting-outputs
```

### テスト失敗
```bash
# テストメモリ不足
flutter test --concurrency=1

# 単一テストのみ実行
flutter test test/facility_service_test.dart -k "searchFacilities"
```

---

**最終確認**: すべてのチェックボックスが ✅ になったら実装完了です！
