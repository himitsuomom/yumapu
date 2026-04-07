import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Periodically checks internet connectivity using a DNS lookup.
///
/// Returns `true` when online. Checks immediately on creation,
/// then every 30 seconds. Uses [InternetAddress.lookup] from dart:io
/// (no connectivity_plus dependency required).
final connectivityProvider =
    StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
  return ConnectivityNotifier();
});

class ConnectivityNotifier extends StateNotifier<bool> {
  ConnectivityNotifier() : super(true) {
    _check();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
  }

  Timer? _timer;

  Future<void> _check() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (mounted) {
        state = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      }
    } on SocketException {
      if (mounted) state = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
