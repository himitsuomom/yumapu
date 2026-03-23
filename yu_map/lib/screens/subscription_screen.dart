import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/providers/subscription_provider.dart';

/// Full-screen subscription / paywall UI.
class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  @override
  void initState() {
    super.initState();
    // Ensure RevenueCat is initialized when entering the screen.
    Future.microtask(() {
      ref.read(subscriptionProvider).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sub = ref.watch(subscriptionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('プレミアムプラン'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: sub.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, sub),
    );
  }

  Widget _buildBody(BuildContext context, SubscriptionProvider sub) {
    // Listen for error messages — capture value before the async callback.
    if (sub.errorMessage != null) {
      final message = sub.errorMessage!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
        sub.clearError();
      });
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          _buildBenefits(),
          const SizedBox(height: 24),
          if (sub.isConfigured) ...[
            _buildPlanCards(sub),
          ] else ...[
            _buildNotConfiguredCard(),
          ],
          const SizedBox(height: 16),
          if (sub.isConfigured) _buildRestoreButton(sub),
          const SizedBox(height: 16),
          _buildLegalText(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// Gold gradient header with crown icon and title.
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFDAA520),
            Color(0xFFFFD700),
            Color(0xFFDAA520),
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white24,
            ),
            child: const Icon(
              Icons.workspace_premium,
              size: 48,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '湯マッププレミアム',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'すべての機能をお楽しみください',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  /// List of premium benefits.
  Widget _buildBenefits() {
    const benefits = [
      _Benefit(Icons.workspace_premium, '王冠バッジ表示', 'プロフィールとレビューに王冠が表示されます'),
      _Benefit(Icons.favorite, 'お気に入り無制限', 'お気に入り登録数の制限がなくなります'),
      _Benefit(Icons.block, '広告非表示', 'すべての広告が非表示になります'),
      _Benefit(Icons.filter_alt, '詳細フィルター', '高度な検索フィルターが利用可能になります'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: benefits.map((b) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(b.icon, color: const Color(0xFFDAA520), size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        b.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  /// Monthly and yearly plan cards with purchase buttons.
  Widget _buildPlanCards(SubscriptionProvider sub) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          // Yearly plan — recommended.
          _PlanCard(
            title: '年額プラン',
            price: '¥3,800/年',
            badge: 'おすすめ 37%OFF',
            isRecommended: true,
            isLoading: sub.isLoading,
            onTap: () => ref.read(subscriptionProvider).purchaseYearly(),
          ),
          const SizedBox(height: 12),
          // Monthly plan.
          _PlanCard(
            title: '月額プラン',
            price: '¥480/月',
            isRecommended: false,
            isLoading: sub.isLoading,
            onTap: () => ref.read(subscriptionProvider).purchaseMonthly(),
          ),
        ],
      ),
    );
  }

  /// Shown when RevenueCat is not configured.
  Widget _buildNotConfiguredCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Icon(Icons.construction, size: 40, color: Colors.grey[400]),
            const SizedBox(height: 12),
            const Text(
              '準備中',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'プレミアムプランは現在準備中です。\nもうしばらくお待ちください。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Restore purchases button.
  Widget _buildRestoreButton(SubscriptionProvider sub) {
    return TextButton(
      onPressed:
          sub.isLoading ? null : () => ref.read(subscriptionProvider).restorePurchases(),
      child: const Text(
        '購入を復元する',
        style: TextStyle(fontSize: 14),
      ),
    );
  }

  /// Legal / disclaimer text at bottom.
  Widget _buildLegalText() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Text(
        'サブスクリプションは自動更新されます。期間終了の24時間前までにキャンセルしない限り自動更新されます。'
        'お支払いはApp Store / Google Playアカウントに請求されます。'
        'サブスクリプションの管理やキャンセルは端末の設定から行えます。',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[500],
          height: 1.5,
        ),
      ),
    );
  }
}

/// Data class for benefit items.
class _Benefit {
  const _Benefit(this.icon, this.title, this.subtitle);
  final IconData icon;
  final String title;
  final String subtitle;
}

/// A selectable plan card widget.
class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    this.badge,
    required this.isRecommended,
    required this.isLoading,
    required this.onTap,
  });

  final String title;
  final String price;
  final String? badge;
  final bool isRecommended;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRecommended
                ? const Color(0xFFDAA520)
                : Colors.grey[300]!,
            width: isRecommended ? 2 : 1,
          ),
          color: isRecommended
              ? const Color(0xFFFFD700).withValues(alpha: 0.05)
              : null,
        ),
        child: Column(
          children: [
            if (badge != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFCC1818),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isRecommended
                    ? const Color(0xFFDAA520)
                    : Colors.grey[800],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
