import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yu_map/core/theme/app_theme.dart';
import 'package:yu_map/core/constants/app_constants.dart';
import 'package:yu_map/core/widgets/offline_banner.dart';
import 'package:yu_map/providers/auth_provider.dart';
import 'package:yu_map/providers/connectivity_provider.dart';
import 'package:yu_map/features/auth/screens/login_screen.dart';
import 'package:yu_map/features/home/home_shell.dart';

class YuMapApp extends ConsumerWidget {
  const YuMapApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      home: const _AppRoot(),
    );
  }
}

class _AppRoot extends ConsumerWidget {
  const _AppRoot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOnline = ref.watch(isOnlineProvider);
    final isSignedIn = ref.watch(isSignedInProvider);

    return Column(
      children: [
        if (!isOnline) const OfflineBanner(),
        Expanded(
          child: isSignedIn ? const HomeShell() : const LoginScreen(),
        ),
      ],
    );
  }
}
