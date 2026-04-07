// lib/screens/facility_screen.dart
//
// 施設詳細画面。以下の機能を含む:
//  - 施設情報（名前・評価・料金・営業時間・定休日）
//  - アメニティ表（◯/× 3列グリッド）
//  - チェックインボタン (+100pt)
//  - ルート案内ボタン（Apple Maps / Google Maps 選択ダイアログ）
//  - シェアボタン（X・スレッズ・Instagram・ネイティブ共有シート）
//  - ここで投稿ボタン
//  - 問い合わせリンク（営業時間変更・未登録施設追加）

import 'package:flutter/material.dart' hide Badge;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:yu_map/core/config/amenity_config.dart';
import 'package:yu_map/models/badge.dart';
import 'package:yu_map/domain/entities/facility.dart';
import 'package:yu_map/providers/app_state.dart';
import 'package:yu_map/screens/create_post_screen.dart';
import 'package:yu_map/screens/inquiry_screen.dart';
import 'package:yu_map/screens/route_screen.dart';

/// FacilityScreen - Detailed view of a single facility
class FacilityScreen extends StatefulWidget {
  final Facility facility;
  final VoidCallback onBackPressed;

  const FacilityScreen({
    super.key,
    required this.facility,
    required this.onBackPressed,
  });

  @override
  State<FacilityScreen> createState() => _FacilityScreenState();
}

class _FacilityScreenState extends State<FacilityScreen> {
  bool _isCheckingIn = false;

  // ─── チェックイン ───────────────────────────────────────────────────────────

  Future<void> _onCheckIn(BuildContext context) async {
    setState(() => _isCheckingIn = true);
    final appState = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);

    final (result, newBadges) = await appState.checkIn(widget.facility.id);
    if (!mounted) return;
    setState(() => _isCheckingIn = false);

    switch (result) {
      case 'success':
        messenger.showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('チェックイン完了！+100pt 獲得'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        if (newBadges.isNotEmpty) {
          if (!mounted) return;
          _showBadgeDialog(newBadges);
        }
      case 'already':
        messenger.showSnackBar(
          const SnackBar(
            content: Text('今日はすでにチェックイン済みです（1日1回まで）'),
            duration: Duration(seconds: 2),
          ),
        );
      default:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('チェックインに失敗しました。ログインしているか確認してください'),
            duration: Duration(seconds: 2),
          ),
        );
    }
  }

  void _showBadgeDialog(List<Badge> badges) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(
          '🎉 バッジ獲得！',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('新しいバッジを獲得しました！', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ...badges.map((b) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Text(b.icon, style: const TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(b.nameJa,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16)),
                            Text(b.descriptionJa,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('やった！'),
          ),
        ],
      ),
    );
  }

  // ─── ナビゲーション（地図アプリ選択） ─────────────────────────────────────

  void _showNavigationDialog() {
    final lat = widget.facility.latitude;
    final lng = widget.facility.longitude;
    final name = Uri.encodeComponent(widget.facility.name);

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ハンドルバー
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  '地図アプリを選択',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.map, color: Colors.blue),
                title: const Text('Apple マップ'),
                subtitle: const Text('iOSの標準マップアプリで案内'),
                onTap: () async {
                  Navigator.pop(context);
                  final url = Uri.parse(
                    'https://maps.apple.com/?daddr=$lat,$lng&dirflg=d',
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined, color: Colors.green),
                title: const Text('Google マップ'),
                subtitle: const Text('Google マップアプリで案内'),
                onTap: () async {
                  Navigator.pop(context);
                  final url = Uri.parse(
                    'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&destination_place_id=$name&travelmode=driving',
                  );
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── シェア ─────────────────────────────────────────────────────────────────

  void _showShareBottomSheet() {
    final facility = widget.facility;
    final text =
        '【${_facilityTypeLabel(facility.type)}】${facility.name}\n'
        '📍 ${facility.address}\n'
        '💴 ${facility.price}円〜\n'
        '⭐ ${facility.rating} (${facility.reviewCount}件)\n'
        '#銭湯 #サウナ #温泉 #yumap';

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'シェア',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _shareButton(
                    label: 'X (Twitter)',
                    icon: Icons.alternate_email,
                    color: Colors.black,
                    onTap: () async {
                      Navigator.pop(context);
                      final encoded = Uri.encodeComponent(text);
                      final url = Uri.parse('https://twitter.com/intent/tweet?text=$encoded');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  _shareButton(
                    label: 'スレッズ',
                    icon: Icons.forum_outlined,
                    color: Colors.black87,
                    onTap: () async {
                      Navigator.pop(context);
                      final encoded = Uri.encodeComponent(text);
                      final url = Uri.parse('https://www.threads.net/intent/post?text=$encoded');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                  _shareButton(
                    label: 'Instagram',
                    icon: Icons.camera_alt_outlined,
                    color: Colors.purple,
                    onTap: () async {
                      Navigator.pop(context);
                      // Instagramはテキスト直接共有ができないためストーリーズURIを試行、
                      // 非対応環境ではネイティブシェートにフォールバック
                      final igUrl = Uri.parse('instagram://');
                      if (await canLaunchUrl(igUrl)) {
                        await launchUrl(igUrl, mode: LaunchMode.externalApplication);
                      } else {
                        await SharePlus.instance.share(ShareParams(text: text, subject: facility.name));
                      }
                    },
                  ),
                  _shareButton(
                    label: 'その他',
                    icon: Icons.ios_share,
                    color: Colors.blueGrey,
                    onTap: () async {
                      Navigator.pop(context);
                      await SharePlus.instance.share(ShareParams(text: text, subject: facility.name));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _shareButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }

  // ─── ルート画面 ─────────────────────────────────────────────────────────────

  Future<void> _openRouteScreen(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // ダイアログを先に閉じてからmountedチェック（閉じ忘れ防止）
          navigator.pop();
          if (!mounted) return;
          messenger.showSnackBar(
            const SnackBar(content: Text('位置情報の許可が必要です')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        navigator.pop();
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('設定から位置情報の許可を有効にしてください')),
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      // ダイアログを先に閉じてからmountedチェック
      navigator.pop();
      if (!mounted) return;

      navigator.push(
        MaterialPageRoute(
          builder: (_) => RouteScreen(
            facility: widget.facility,
            currentLocation: LatLng(position.latitude, position.longitude),
          ),
        ),
      );
    } catch (e) {
      navigator.pop();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('位置情報の取得に失敗しました: $e')),
      );
    }
  }

  // ─── ヘルパー ────────────────────────────────────────────────────────────────

  String _facilityTypeLabel(String type) {
    switch (type) {
      case 'sauna':
        return 'サウナ';
      case 'onsen':
        return '温泉';
      case 'supersento':
        return 'スーパー銭湯';
      case 'public_bath':
        return '銭湯';
      default:
        return type;
    }
  }

  Color _facilityTypeColor(String type) {
    switch (type) {
      case 'sauna':
        return Colors.deepOrange;
      case 'onsen':
        return Colors.blue;
      case 'supersento':
        return Colors.teal;
      case 'public_bath':
        return Colors.indigo;
      default:
        return Colors.orange;
    }
  }

  IconData _facilityTypeIcon(String type) {
    switch (type) {
      case 'sauna':
        return Icons.local_fire_department;
      case 'onsen':
        return Icons.hot_tub;
      case 'supersento':
        return Icons.pool;
      case 'public_bath':
        return Icons.bathtub;
      default:
        return Icons.spa;
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // ─── アメニティ表 ────────────────────────────────────────────────────────────

  Widget _buildAmenityTable() {
    final amenities = widget.facility.amenities;

    // アメニティ定義が1つもない場合は非表示
    if (AmenityConfig.definitions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '設備・アメニティ',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: AmenityConfig.definitions.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.5,
          ),
          itemBuilder: (_, i) {
            final def = AmenityConfig.definitions[i];
            final hasAmenity = amenities[def.key] == true;
            return Container(
              decoration: BoxDecoration(
                color: hasAmenity
                    ? Colors.orange.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: hasAmenity
                      ? Colors.orange.shade200
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hasAmenity ? '◯' : '×',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: hasAmenity
                          ? Colors.deepOrange
                          : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      def.label,
                      style: TextStyle(
                        fontSize: 11,
                        color: hasAmenity ? Colors.black87 : Colors.grey,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final facility = widget.facility;
    final typeColor = _facilityTypeColor(facility.type);

    return Scaffold(
      body: Consumer<AppState>(
        builder: (context, appState, _) {
          final isFavorite = appState.isFavorite(facility.id);

          return CustomScrollView(
            slivers: [
              // ── AppBar with type-based color header ─────────────────────
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                leading: IconButton(
                  icon: const CircleAvatar(
                    backgroundColor: Colors.black38,
                    child: Icon(Icons.arrow_back, color: Colors.white),
                  ),
                  onPressed: widget.onBackPressed,
                ),
                actions: [
                  // シェアボタン
                  IconButton(
                    icon: const CircleAvatar(
                      backgroundColor: Colors.black38,
                      child: Icon(Icons.ios_share, color: Colors.white),
                    ),
                    onPressed: _showShareBottomSheet,
                  ),
                  // お気に入りボタン
                  IconButton(
                    icon: CircleAvatar(
                      backgroundColor: Colors.black38,
                      child: Icon(
                        isFavorite ? Icons.favorite : Icons.favorite_border,
                        color: isFavorite ? Colors.red : Colors.white,
                      ),
                    ),
                    onPressed: () async {
                      final snackMessenger = ScaffoldMessenger.of(context);
                      await appState.toggleFacilityFavorite(facility.id);
                      if (!mounted) return;
                      snackMessenger.showSnackBar(
                        SnackBar(
                          content: Text(isFavorite
                              ? 'お気に入りから削除しました'
                              : 'お気に入りに追加しました'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    color: typeColor.withValues(alpha: 0.15),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _facilityTypeIcon(facility.type),
                            size: 64,
                            color: typeColor,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _facilityTypeLabel(facility.type),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: typeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ── コンテンツ ───────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 名前 & 営業中/準備中バッジ
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              facility.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: facility.isOpen
                                  ? Colors.green.shade100
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              facility.isOpen ? '営業中' : '準備中',
                              style: TextStyle(
                                color: facility.isOpen
                                    ? Colors.green.shade800
                                    : Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // 評価
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.orange, size: 18),
                          Text(
                            ' ${facility.rating} (${facility.reviewCount}件のレビュー)',
                            style: const TextStyle(
                                color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 施設情報カード
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.lightBlue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            _buildInfoRow(
                                '入浴料', '大人 ${facility.price}円〜'),
                            const Divider(),
                            _buildInfoRow('営業時間',
                                facility.hours.isEmpty ? '未登録' : facility.hours),
                            const Divider(),
                            _buildInfoRow('定休日',
                                facility.holiday.isEmpty ? '未登録' : facility.holiday),
                            if (facility.phone.isNotEmpty) ...[
                              const Divider(),
                              _buildInfoRow('電話', facility.phone),
                            ],
                            if (facility.address.isNotEmpty) ...[
                              const Divider(),
                              _buildInfoRow('住所', facility.address),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── アメニティ表 ──────────────────────────────────
                      _buildAmenityTable(),
                      const SizedBox(height: 20),

                      // ── チェックインボタン ─────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.deepOrange,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isCheckingIn
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.where_to_vote),
                          label: Text(
                            _isCheckingIn ? '記録中...' : '今ここにいる  +100pt',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _isCheckingIn
                              ? null
                              : () => _onCheckIn(context),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // ── 道案内 / ここで投稿 ───────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.lightBlue,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.navigation),
                              label: const Text('道案内'),
                              onPressed: _showNavigationDialog,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueGrey.shade600,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.alt_route),
                              label: const Text('ルート案内'),
                              onPressed: () => _openRouteScreen(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('ここで投稿'),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CreatePostScreen(
                                      facility: facility,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── 問い合わせリンク ────────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '情報の修正・追加',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => InquiryScreen(
                                    type: InquiryType.hoursChange,
                                    initialFacilityName: facility.name,
                                  ),
                                ),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(Icons.access_time,
                                        size: 18, color: Colors.deepOrange),
                                    SizedBox(width: 8),
                                    Text('営業時間・定休日の変更を報告する',
                                        style:
                                            TextStyle(color: Colors.deepOrange)),
                                    Spacer(),
                                    Icon(Icons.chevron_right,
                                        color: Colors.deepOrange),
                                  ],
                                ),
                              ),
                            ),
                            const Divider(height: 1),
                            InkWell(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const InquiryScreen(
                                    type: InquiryType.addFacility,
                                  ),
                                ),
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(Icons.add_location_alt,
                                        size: 18, color: Colors.blue),
                                    SizedBox(width: 8),
                                    Text('未登録の施設を追加申請する',
                                        style: TextStyle(color: Colors.blue)),
                                    Spacer(),
                                    Icon(Icons.chevron_right,
                                        color: Colors.blue),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
