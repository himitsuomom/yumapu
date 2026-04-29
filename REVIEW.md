# Code Review Guidelines — YUMAPU

## Always check
- 新しい Supabase テーブルに RLS ポリシーが設定されているか
- `mounted` チェックが `await` をまたぐ非同期処理後に行われているか
- Supabase マイグレーションが後方互換性を維持しているか
- エラーメッセージにサーバー内部情報（スタックトレース、テーブル名等）が漏洩していないか
- `AnimationController` / `TextEditingController` / `StreamSubscription` の dispose 漏れがないか
- Repository パターンを通さず Widget から直接 Supabase を呼んでいないか
- `print()` を使っていないか（`debugPrint()` を使用すること）
- API キーや秘密情報がコードにハードコードされていないか

## Style
- `flutter analyze` でエラー 0・警告 0 を維持する
- `dynamic` 型は禁止（やむを得ない場合は理由コメントを添えて `// ignore:` を使用）
- named parameter を積極的に使用する
- Widget は 250 行を超えたら分割を検討する
- UI テキストはすべて日本語
- 非同期処理は `async/await` を使用し `.then()` チェーンは避ける

## Skip
- `pubspec.lock` のフォーマットのみの変更
- `.dart_tool/` 配下の自動生成ファイル
- `build/` 配下のビルド成果物
- `*.g.dart` / `*.freezed.dart`（コード生成ファイル）
