import 'package:flutter/material.dart';

/// A gold crown icon on a red circle. Hidden when [isPremium] is false.
class CrownBadge extends StatelessWidget {
  const CrownBadge({
    super.key,
    required this.isPremium,
    this.size = 20,
  });

  final bool isPremium;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!isPremium) return const SizedBox.shrink();

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFCC1818),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        Icons.workspace_premium,
        size: size * 0.65,
        color: const Color(0xFFFFD700),
      ),
    );
  }
}

/// A [CircleAvatar] with a [CrownBadge] stacked in the top-right corner.
class UserAvatarWithCrown extends StatelessWidget {
  const UserAvatarWithCrown({
    super.key,
    required this.isPremium,
    this.radius = 40,
    this.avatarUrl,
    this.fallbackIcon = Icons.person,
    this.backgroundColor,
  });

  final bool isPremium;
  final double radius;
  final String? avatarUrl;
  final IconData fallbackIcon;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final bgColor =
        backgroundColor ?? Theme.of(context).colorScheme.primaryContainer;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: radius,
          backgroundColor: bgColor,
          backgroundImage:
              avatarUrl != null ? NetworkImage(avatarUrl!) : null,
          child: avatarUrl == null
              ? Icon(fallbackIcon, size: radius)
              : null,
        ),
        if (isPremium)
          Positioned(
            top: -2,
            right: -2,
            child: CrownBadge(isPremium: true, size: radius * 0.55),
          ),
      ],
    );
  }
}

/// A small gold gradient chip with crown icon and "プレミアム" text.
class PremiumChip extends StatelessWidget {
  const PremiumChip({super.key, this.height = 22});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFDAA520),
            Color(0xFFFFD700),
            Color(0xFFDAA520),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium,
            size: height * 0.65,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            'プレミアム',
            style: TextStyle(
              fontSize: height * 0.52,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
