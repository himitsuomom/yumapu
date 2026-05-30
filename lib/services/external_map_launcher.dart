// lib/services/external_map_launcher.dart
//
// 外部マップアプリ（Google マップ・Yahoo! マップ・Apple マップ・既定ナビ）を
// ボトムシートで選択して起動するユーティリティ。

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class ExternalMapLauncher {
  static Future<void> showMapPickerSheet(
    BuildContext context, {
    required double lat,
    required double lng,
    required String name,
  }) async {
    final encodedName = Uri.encodeComponent(name);

    await showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('地図アプリを選択',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Google マップ'),
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                );
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
            ListTile(
              leading: const Icon(Icons.map_outlined),
              title: const Text('Yahoo! マップ'),
              onTap: () async {
                Navigator.pop(ctx);
                final uri = Uri.parse(
                  'https://map.yahoo.co.jp/place?lat=$lat&lon=$lng&zoom=17',
                );
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
            ),
            if (Platform.isIOS)
              ListTile(
                leading: const Icon(Icons.apple),
                title: const Text('Apple マップ'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(
                    'https://maps.apple.com/?ll=$lat,$lng&q=$encodedName',
                  );
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
            ListTile(
              leading: const Icon(Icons.near_me),
              title: const Text('既定のナビアプリ'),
              onTap: () async {
                Navigator.pop(ctx);
                final uri =
                    Uri.parse('geo:$lat,$lng?q=$lat,$lng($encodedName)');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  // フォールバック: Google Maps Web
                  final fallback = Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                  );
                  await launchUrl(fallback,
                      mode: LaunchMode.externalApplication);
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
