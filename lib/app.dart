import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/core/theme/app_theme.dart';
import 'package:yu_map/core/widgets/offline_banner.dart';
import 'package:yu_map/features/auth/screens/login_screen.dart';
import 'package:yu_map/features/auth/screens/register_screen.dart';
import 'package:yu_map/features/facility/screens/facility_detail_screen.dart';
import 'package:yu_map/features/home/home_shell.dart';
import 'package:yu_map/features/profile/screens/profile_screen.dart';
import 'package:yu_map/features/reviews/screens/write_review_screen.dart';
import 'package:yu_map/features/settings/settings_screen.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/connectivity_provider.dart';
import 'package:yu_map/screens/subscription_screen.dart';

class YuMapApp extends ConsumerWidget {
  const YuMapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(connectivityProvider);

    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      // Named routes for screens pushed via Navigator.pushNamed.
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/subscription': (_) => const SubscriptionScreen(),
        '/profile': (_) => const ProfileScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
      // Routes that carry typed arguments use onGenerateRoute.
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/facility':
            final facilityId = settings.arguments as String;
            return MaterialPageRoute<void>(
              builder: (_) => FacilityDetailScreen(facilityId: facilityId),
            );
          case '/review':
            final args = settings.arguments as Map<String, String>;
            return MaterialPageRoute<void>(
              builder: (_) => WriteReviewScreen(
                facilityId: args['facilityId']!,
                facilityName: args['facilityName']!,
              ),
            );
          default:
            return null;
        }
      },
      // Overlays OfflineBanner above all routes when the device is offline.
      builder: (context, child) {
        return Column(
          children: [
            if (!isOnline) const OfflineBanner(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
      home: const _AuthGate(),
    );
  }
}

/// Watches [isSignedInProvider] and shows either [HomeShell] or [LoginScreen].
///
/// When the auth state changes (login / logout) any screens pushed on top of
/// this gate are popped so the user always sees the correct root view.
class _AuthGate extends ConsumerStatefulWidget {
  const _AuthGate();

  @override
  ConsumerState<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<_AuthGate> {
  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isSignedInProvider, (previous, next) {
      if (previous != null && previous != next) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });

    final isSignedIn = ref.watch(isSignedInProvider);
    return isSignedIn ? const HomeShell() : const LoginScreen();
  }
}
