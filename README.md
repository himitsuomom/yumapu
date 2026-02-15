# Yu-Map (湯マップ)

日本全国の温泉・銭湯・サウナを地図上で探索できるソーシャルマップアプリケーションです。

## 概要

Yu-Mapは、政府公開データやユーザー投稿をもとに、全国の入浴施設情報をリアルタイムで共有・検索できるFlutterアプリです。

### 主な機能

- **地図表示**: Google Maps上に施設をクラスタリング表示、GPS対応
- **施設検索**: 名前・地域・アメニティ（サウナ、タトゥーOK等）でフィルタリング
- **施設詳細**: 評価、アメニティ、営業情報、写真、レビュー一覧
- **レビュー**: 施設への口コミ・5段階評価投稿、いいね機能
- **チェックイン**: GPS位置認証付きの訪問記録
- **写真共有**: 施設の写真をアップロード・共有
- **ランキング**: ユーザーの活動に応じた称号（初心者→マスター）・バッジシステム
- **お気に入り**: 施設のブックマーク管理
- **プレミアム**: 広告非表示などのサブスクリプション機能
- **認証**: メール/パスワード + OAuth (Google/Apple)

## 技術スタック

| カテゴリ | 技術 |
|----------|------|
| フロントエンド | Flutter (Dart) |
| 状態管理 | Riverpod |
| ルーティング | GoRouter |
| バックエンド | Supabase (PostgreSQL + PostGIS) |
| 地図 | Google Maps Flutter + クラスタリング |
| 認証 | Supabase Auth |
| ストレージ | Supabase Storage |
| 課金 | RevenueCat |
| 広告 | Google AdMob |
| 分析 | Firebase Analytics |
| Edge Functions | Deno (TypeScript) |

## プロジェクト構造

```
yu_map/
├── lib/
│   ├── core/           # 設定、ルーター、テーマ、ユーティリティ
│   ├── domain/         # データモデル (Facility, Review, User, UserRanking)
│   ├── providers/      # Riverpod Provider (認証、施設、レビュー、お気に入り)
│   ├── presentation/   # UI画面 & ウィジェット
│   │   ├── screens/    # 8画面 (認証, マップ, 検索, 詳細, レビュー, プロフィール)
│   │   └── widgets/    # 共通ウィジェット
│   ├── services/       # ビジネスロジック (12サービス)
│   ├── app.dart        # アプリルート (Material 3 + GoRouter)
│   └── main.dart       # エントリーポイント
├── supabase/
│   ├── functions/      # Edge Functions (ランキング計算, 情報検証)
│   ├── migrations/     # DBスキーマ (15テーブル)
│   └── seed/           # 初期データ (47都道府県, 8施設タイプ, 8バッジ)
├── test/               # ユニットテスト
└── pubspec.yaml        # 依存関係
```

## セットアップ

### 前提条件

- Flutter SDK >= 3.2.0
- Supabase プロジェクト（PostGIS拡張有効）
- Google Maps API キー
- Firebase プロジェクト

### 環境変数

ビルド時に `--dart-define` で設定してください:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ... \
  --dart-define=GOOGLE_MAPS_KEY=AIza...
```

### インストール

```bash
cd yu_map
flutter pub get
flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... --dart-define=GOOGLE_MAPS_KEY=...
```

### データベースセットアップ

```bash
# スキーマ適用
supabase db push

# 初期データ投入
psql -f supabase/seed/seed_data.sql
```

## 画面一覧

| 画面 | パス | 説明 |
|------|------|------|
| ログイン | `/login` | メール認証 |
| サインアップ | `/signup` | アカウント作成 |
| ホーム | `/` | タブナビ (マップ/検索/プロフィール) |
| 施設詳細 | `/facility/:id` | 情報、レビュー、チェックイン |
| 検索 | `/search` | テキスト + アメニティフィルタ |
| レビュー投稿 | `/facility/:id/review` | 評価 + テキスト入力 |
| プロフィール | `/profile` | ランキング、統計、お気に入り |
| プロフィール編集 | `/profile/edit` | ユーザー名、自己紹介 |

## リサーチツール

ルートディレクトリにある `research_summary.py` は、多言語ウェブリサーチの結果を分析・要約するCLIツールです。

```bash
pip install openai
export OPENAI_API_KEY=sk-...
python research_summary.py --input results.json --format json --output report.md
```

## ライセンス

Private
