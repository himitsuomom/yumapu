// lib/core/navigation/app_navigator.dart
//
// アプリ全体で共有するNavigatorKey と タブ切り替えNotifier。
// 通知サービス・ディープリンクなど、Contextを持たない場所からの
// 画面遷移を可能にするためのグローバルキー。
//
// 使い方（ContextなしでPushNamed）:
//   appNavigatorKey.currentState?.pushNamed('/badges');
//
// タブ切り替え（HomeShellのBottomNavBarと連動させる場合）:
//   pendingTabSwitch.value = 2; // → Feed タブに切り替わる

import 'package:flutter/material.dart';

/// アプリのルートNavigatorに紐付くグローバルキー。
/// [MaterialApp] の navigatorKey に設定して使用する。
final appNavigatorKey = GlobalKey<NavigatorState>();

/// 通知・外部トリガーから HomeShell のタブを切り替えるための ValueNotifier。
///
/// 通知サービスがこれを更新 → HomeShell が即座にタブを切り替える。
/// HomeShell が処理後に null にリセットする（二重処理防止）。
///
/// タブ構成: 0=地図 / 1=検索 / 2=フィード / 3=お気に入り / 4=プロフィール
final pendingTabSwitch = ValueNotifier<int?>(null);
