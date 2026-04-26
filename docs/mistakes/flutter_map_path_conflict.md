# flutter_map と dart:ui の Path 衝突

## 何が起きたか:
flutter_map パッケージをインポートすると Path という型が flutter_map 側の型として解釈され、
CustomPainter.paint() 内で Path() を使うと型エラーが発生する。

## 根本原因:
flutter_map が内部で Path を export しており、dart:ui の Path と名前が衝突する。

## 対策・今後の方針:
flutter_map を使うファイルで CustomPainter を書く場合は先頭に以下を追加する:
  import 'dart:ui' as ui;
そして Path() の代わりに ui.Path() を使う。
