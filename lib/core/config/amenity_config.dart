// lib/core/config/amenity_config.dart
import 'package:flutter/material.dart';

/// アメニティ（施設設備）の定義
/// DBの amenities JSONB カラムのキーと対応しています。
class AmenityDef {
  final String key;
  final String label;
  final IconData icon;

  const AmenityDef({
    required this.key,
    required this.label,
    required this.icon,
  });
}

/// 全アメニティ定義リスト
/// 施設詳細画面の◯/×表とマップフィルターの両方で使います。
class AmenityConfig {
  AmenityConfig._();

  static const List<AmenityDef> definitions = [
    AmenityDef(key: 'tattoo',            label: '刺青可',     icon: Icons.warning_amber_rounded),
    AmenityDef(key: 'food',              label: '食事所',     icon: Icons.restaurant),
    AmenityDef(key: 'parking',           label: '駐車場',     icon: Icons.local_parking),
    AmenityDef(key: 'outdoor_bath',      label: '外気浴',     icon: Icons.air),
    AmenityDef(key: 'cold_bath',         label: '水風呂',     icon: Icons.ac_unit),
    AmenityDef(key: 'mixed_bath',        label: '混浴',       icon: Icons.people),
    AmenityDef(key: 'rock_bath',         label: '岩盤浴',     icon: Icons.terrain),
    AmenityDef(key: 'lodging',           label: '宿泊',       icon: Icons.hotel),
    AmenityDef(key: 'natural_hot_spring',label: '天然温泉',   icon: Icons.hot_tub),
  ];
}
