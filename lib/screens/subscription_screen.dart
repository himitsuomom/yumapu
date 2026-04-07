import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:yu_map/core/config/app_config.dart';
import 'package:yu_map/providers/subscription_provider.dart';

// ── Local provider — fetches the current RevenueCat offering ─────────────────

final _currentOfferingProvider =
    FutureProvider.autoDispose<Offering?>((ref) async {
  if (!AppConfig.isRevenueCatConfigured) return null;
  try {
    final offerings = await Purchases.getOfferings();
    return offerings.current;
  } catch (_) {
    return null;
  }
});

// ── Screen ────────────────────────────────────────────────────────────────────

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _annualLoading = false;

  // ── Annual purchase (not in SubscriptionService — handled locally) ─────────

  Future<void> _purchaseAnnual(Package package) async {
    setState(() => _annualLoading = true);
    try {
      await Purchases.purchase(PurchaseParams.package(package));
      // Refresh subscription state after purchase
      ref.invalidate(subscriptionProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('年額プランに登録しました')),
      );
    } catch (_) {
      // Purchase cancelled or failed — no feedback needed
    } finally {
      if (mounted) setState(() => _annualLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final subscriptionState = ref.watch(subscriptionProvider);
    final offeringAsync = ref.watch(_currentOfferingProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('プレミアムプラン')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Header ────────────────────────────────────────────────
            const Icon(
              Icons.workspace_premium,
              size: 72,
              color: Color(0xFFDAA520),
            ),
            const SizedBox(height: 16),
            Text(
              'プレミアム会員になって\nすべての機能を使おう',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '広告非表示 • すべての施設を閲覧 • 優先サポート',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF757575),
                  ),
            ),
            const SizedBox(height: 32),

            // ── Already premium ────────────────────────────────────────
            if (subscriptionState.isPremium) ...[
              const _PremiumActiveCard(),
            ]
            // ── RevenueCat not configured ──────────────────────────────
            else if (!AppConfig.isRevenueCatConfigured) ...[
              const _ComingSoonCard(),
            ]
            // ── Plan cards ─────────────────────────────────────────────
            else ...[
              offeringAsync.when(
                data: (offering) => _PlanCards(
                  offering: offering,
                  monthlyLoading: subscriptionState.isLoading,
                  annualLoading: _annualLoading,
                  onPurchaseMonthly: () =>
                      ref.read(subscriptionProvider.notifier).purchaseMonthly(),
                  onPurchaseAnnual: (pkg) => _purchaseAnnual(pkg),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const _OfferingErrorCard(),
              ),
              // Error message from subscription provider
              if (subscriptionState.error != null) ...[
                const SizedBox(height: 16),
                Text(
                  subscriptionState.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 24),
              // Restore purchases
              Center(
                child: TextButton(
                  onPressed: subscriptionState.isLoading
                      ? null
                      : () => ref
                          .read(subscriptionProvider.notifier)
                          .restorePurchases(),
                  child: const Text('購入を復元する'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Plan cards ────────────────────────────────────────────────────────────────

class _PlanCards extends StatelessWidget {
  const _PlanCards({
    required this.offering,
    required this.monthlyLoading,
    required this.annualLoading,
    required this.onPurchaseMonthly,
    required this.onPurchaseAnnual,
  });

  final Offering? offering;
  final bool monthlyLoading;
  final bool annualLoading;
  final VoidCallback onPurchaseMonthly;
  final void Function(Package) onPurchaseAnnual;

  @override
  Widget build(BuildContext context) {
    final monthly = offering?.monthly;
    final annual = offering?.annual;
    final anyLoading = monthlyLoading || annualLoading;

    return Column(
      children: [
        // ── Annual plan (highlighted as best value) ────────────────────
        _PlanCard(
          label: '年額プラン',
          badge: 'おすすめ',
          priceString: annual?.storeProduct.priceString ?? '—',
          period: '/ 年',
          description: '月額より最大40%お得',
          isHighlighted: true,
          isLoading: annualLoading,
          onTap: annual != null && !anyLoading
              ? () => onPurchaseAnnual(annual)
              : null,
        ),
        const SizedBox(height: 12),
        // ── Monthly plan ───────────────────────────────────────────────
        _PlanCard(
          label: '月額プラン',
          priceString: monthly?.storeProduct.priceString ?? '—',
          period: '/ 月',
          description: 'いつでもキャンセル可能',
          isHighlighted: false,
          isLoading: monthlyLoading,
          onTap: monthly != null && !anyLoading ? onPurchaseMonthly : null,
        ),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.label,
    required this.priceString,
    required this.period,
    required this.description,
    required this.isHighlighted,
    required this.isLoading,
    this.badge,
    this.onTap,
  });

  final String label;
  final String? badge;
  final String priceString;
  final String period;
  final String description;
  final bool isHighlighted;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1565C0);

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isHighlighted
            ? const BorderSide(color: primary, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (badge != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        badge!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: priceString,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isHighlighted ? primary : null,
                          ),
                    ),
                    TextSpan(
                      text: period,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF757575),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF757575),
                    ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isHighlighted ? primary : null,
                    foregroundColor: isHighlighted ? Colors.white : null,
                  ),
                  onPressed: onTap,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('このプランで始める'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── State cards ───────────────────────────────────────────────────────────────

class _PremiumActiveCard extends StatelessWidget {
  const _PremiumActiveCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF8E1),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFFDAA520), size: 48),
            const SizedBox(height: 12),
            Text(
              'プレミアム会員',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'すべてのプレミアム機能が利用できます',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when [AppConfig.isRevenueCatConfigured] is false.
class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.construction_outlined,
                size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              '準備中',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'プレミアムプランは現在準備中です。\nもうしばらくお待ちください。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF757575),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfferingErrorCard extends StatelessWidget {
  const _OfferingErrorCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.orange),
            SizedBox(height: 12),
            Text(
              'プランの読み込みに失敗しました。\nしばらくしてから再度お試しください。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
