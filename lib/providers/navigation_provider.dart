// lib/providers/navigation_provider.dart
//
// アプリ全体のナビゲーション状態を管理するプロバイダー群。
//
// 主な用途:
//   - HomeShell のボトムナビタブを外部から切り替える（例: お気に入り→地図タブ）
//   - 地図画面に「指定座標にカメラを移動せよ」を伝える（例: お気に入り施設を地図で表示）

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// ボトムナビゲーションバーの現在のタブインデックス。
///
/// HomeShell がこのプロバイダーを watch し、外部から変更されたときに
/// 自動的にタブを切り替える。
///
/// タブ構成: 0=地図 / 1=検索 / 2=ランキング / 3=お気に入り / 4=プロフィール
final homeTabIndexProvider = StateProvider<int>((ref) => 0);

/// 地図画面に「この座標に飛んでほしい」と伝えるプロバイダー。
///
/// 使い方:
///   1. お気に入り画面などが lat/lng を set する
///   2. MapScreen がこれを watch し、非 null のときカメラを移動する
///   3. 移動完了後、MapScreen が null にリセットする（二重実行防止）
///
/// null = アクションなし（通常状態）
final mapFlyToProvider = StateProvider<({double lat, double lng})?>(
  (ref) => null,
);
