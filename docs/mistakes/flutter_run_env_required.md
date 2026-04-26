# flutter run に --dart-define-from-file=.env が必要

## 何が起きたか:
flutter run だけで起動するとSupabaseに接続できず、施設データが取得されず地図にマーカーが出なかった。

## 根本原因:
Supabase の URL と APIキーが .env ファイルで管理されており、
--dart-define-from-file=.env オプションなしでビルドするとnullになる。

## 対策・今後の方針:
必ず以下のコマンドで起動する:
  flutter run --dart-define-from-file=.env
シミュレーターでデータが出ない場合はまずこれを疑う。
