// lib/core/navigation/app_navigator.dart
//
// アプリ全体で共有するNavigatorKey。
// 通知サービス・ディープリンクなど、Contextを持たない場所からの
// 画面遷移を可能にするためのグローバルキー。
//
// 使い方（ContextなしでPushNamed）:
//   appNavigatorKey.currentState?.pushNamed('/badges');

import 'package:flutter/material.dart';

/// アプリのルートNavigatorに紐付くグローバルキー。
/// [MaterialApp] の navigatorKey に設定して使用する。
final appNavigatorKey = GlobalKey<NavigatorState>();
