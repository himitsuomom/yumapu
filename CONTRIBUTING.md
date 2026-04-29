# CONTRIBUTING — YUMAPU 開発ガイド & コードレビュープロセス

YUMAPU（湯マップ）への貢献ありがとうございます。本ドキュメントでは、自動コードレビューの仕組みとプロジェクト固有の規約を定めます。

---

## 目次

1. [プロジェクト概要](#プロジェクト概要)
2. [開発環境セットアップ](#開発環境セットアップ)
3. [コードスタイル規約](#コードスタイル規約)
4. [ブランチ命名規則](#ブランチ命名規則)
5. [コミット規約](#コミット規約)
6. [自動コードレビュー（reviewdog）](#自動コードレビューreviewdog)
7. [多角的レビューチェックリスト](#多角的レビューチェックリスト)
8. [セキュリティレビュー](#セキュリティレビュー)
9. [ベストプラクティス 10 か条](#ベストプラクティス-10-か条)

---

## プロジェクト概要

YUMAPU は日本全国の温泉・銭湯施設を地図上で探索・チェックインできる Flutter モバイルアプリです。

| 項目 | 詳細 |
|---|---|
| 言語 | Dart (Flutter 3.x stable) |
| フロントエンド | Flutter (Material Design 3) |
| バックエンド | Supabase (PostgreSQL + Edge Functions) |
| 地図 | flutter_map + OpenStreetMap |
| 認証 | Supabase Auth |
| 状態管理 | Riverpod |

---

## 開発環境セットアップ

```bash
# Flutter のバージョン確認
flutter --version  # 3.x stable であること

# 依存関係インストール
flutter pub get

# 静的解析
flutter analyze

# テスト実行
flutter test

# Android ビルド確認
flutter build apk --debug

# iOS ビルド確認（Mac のみ）
flutter build ios --no-codesign
```

---

## コードスタイル規約

- Dart の `analysis_options.yaml` に従い、`flutter analyze` でエラー 0 を維持する
- `dynamic` 型は禁止（やむを得ない場合は `// ignore: ` コメント + 理由を明記）
- named parameter を積極的に使用する
- Widget は小さく分割し、単一責任原則に従う（250行を超えたら分割を検討）
- UI テキストはすべて日本語
- 非同期処理は `async/await` を使用し、`.then()` チェーンは避ける
- `BuildContext` を非同期の await をまたいで使用する場合は `mounted` チェックを必ず行う
- Riverpod の Provider は `lib/core/providers/` 配下に配置する
- Supabase クエリは Repository パターンでラップし、Widget から直接呼ばない
- `print()` は禁止（`debugPrint()` を使用し、リリースビルドでは自動除去される）

---

## ブランチ命名規則

**禁止パターン（mainへの直接プッシュも禁止）:**
- `claude/*` — AI による自動ブランチは必ずレビューを通す
- `main` への直接 `git push`

**許可パターン:**
```
feat/<機能名>       # 新機能: feat/checkin-button
fix/<バグ名>        # バグ修正: fix/map-marker-overlap
refactor/<対象>    # リファクタ: refactor/auth-provider
docs/<対象>        # ドキュメント: docs/contributing
chore/<作業>       # 雑務: chore/update-dependencies
```

---

## コミット規約

[Conventional Commits](https://www.conventionalcommits.org/ja/) に従います:

```
<type>(<scope>): <日本語の説明>

例:
feat(map): 施設マーカーにクラスタリングを追加
fix(auth): ログアウト後のナビゲーションバグを修正
refactor(feed): FeedScreen を FeedList と FeedHeader に分割
```

| type | 用途 |
|---|---|
| `feat` | 新機能 |
| `fix` | バグ修正 |
| `refactor` | 動作変更なしのコード改善 |
| `test` | テスト追加・修正 |
| `docs` | ドキュメントのみの変更 |
| `chore` | ビルド・CI・依存関係の変更 |

---

## 自動コードレビュー（reviewdog）

すべての Pull Request は、`.github/workflows/code-review.yml` により自動チェックされます。

### 使用ツール

| ツール | 目的 |
|---|---|
| [reviewdog](https://github.com/reviewdog/reviewdog) | レビューコメントを GitHub PR に自動投稿 |
| `reviewdog/action-dartanalyzer` | Dart/Flutter の静的解析結果を PR にコメント |
| `flutter test` | ユニット・ウィジェットテストの自動実行 |

### 実行される検査内容

**Dart Analyzer（`reviewdog/action-dartanalyzer`）:**
- 未使用変数・未使用 import の検出
- `dynamic` 型の使用警告
- `BuildContext` のライフサイクル違反
- `await` 忘れ（`unawaited_futures`）
- null safety 違反

**Flutter テスト（`flutter test`）:**
- ユニットテスト
- ウィジェットテスト
- `flutter analyze --fatal-infos` による型チェック

### ローカルでの事前確認

```bash
# PR を出す前に必ず実行
flutter analyze
flutter test

# 自動修正（import の整理など）
dart fix --apply
```

---

## 多角的レビューチェックリスト

すべての PR は以下の観点でレビューします:

### 🐛 正確さ (Correctness)

- [ ] ロジックバグや不正な動作がないか
- [ ] `mounted` チェックが非同期処理後に行われているか
- [ ] null safety が適切に処理されているか
- [ ] Supabase クエリのエラーハンドリングが適切か
- [ ] Riverpod の状態更新が正しく伝播しているか

### 🔒 セキュリティ (Security)

- [ ] Supabase RLS (Row Level Security) ポリシーが適切に設定されているか
- [ ] ユーザー入力が Supabase クエリに直接埋め込まれていないか
- [ ] API キーや秘密情報がコードにハードコードされていないか（`.env` / `--dart-define` を使用）
- [ ] 認証チェックが必要な画面に `AuthGuard` が設定されているか

### ⚡ パフォーマンス (Performance)

- [ ] `build()` メソッド内で重い処理をしていないか
- [ ] `ListView` に大量データを直接渡していないか（`ListView.builder` を使用）
- [ ] 地図マーカーのメモリリークがないか（dispose 処理）
- [ ] 画像のキャッシュが適切か（`cached_network_image` の使用）
- [ ] 不要な `setState` / Provider の再構築が発生していないか

### 📐 品質 (Quality)

- [ ] Widget の責務が明確で単一責任原則に従っているか
- [ ] 命名が意図を明確に表現しているか
- [ ] 重複コードがないか（DRY 原則）
- [ ] `analysis_options.yaml` のルールに違反していないか
- [ ] 新しい依存関係を追加した場合、`pubspec.yaml` にバージョン制約があるか

### 🧪 テスタビリティ (Testability)

- [ ] 新しい機能に対応するテストがあるか
- [ ] Supabase マイグレーションが後方互換性を維持しているか
- [ ] 境界値テスト・エラーケーステストが含まれているか

---

## セキュリティレビュー

### 最重要チェック項目

```
セキュリティカテゴリ:
- Supabase RLS バイパス（ポリシー漏れ）
- API キーのハードコード（環境変数を使用すること）
- 認証・認可バイパス（authStateChanges の購読漏れ）
- 位置情報の過剰収集・不適切な保存
- Deep Link のパラメータインジェクション
```

---

## ベストプラクティス 10 か条

1. **ブランチを切る** — `main` への直接プッシュは禁止。必ず feature ブランチを作成する
2. **PR を小さく保つ** — 1 PR = 1 つの目的。レビューしやすいサイズに保つ
3. **CI を通してからマージ** — `flutter analyze` と `flutter test` が緑になってからマージ
4. **`mounted` を忘れない** — `await` の後で `setState` や `context` を使う前に `if (!mounted) return`
5. **RLS を先に設計する** — 新テーブルを作ったら必ず RLS ポリシーも同じ PR に含める
6. **Provider の粒度を適切に** — 粒度が粗すぎると再描画が増える。`select` を活用する
7. **ローカルで先に確認** — `flutter analyze` と `flutter test` を PR 前に実行する
8. **dispose を忘れない** — `AnimationController`、`TextEditingController`、`StreamSubscription` は必ず dispose する
9. **AI コードは必ずレビュー** — Claude Code が生成したコードもレビューなしで main に入れない
10. **率直なフィードバックを求める** — 同意するだけでなく直接的なフィードバックを期待する
