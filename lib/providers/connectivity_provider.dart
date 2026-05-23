import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Periodically checks internet connectivity using a DNS lookup.
///
/// Returns `true` when online. Checks immediately on creation,
/// then every 30 seconds. Uses [InternetAddress.lookup] from dart:io
/// (no connectivity_plus dependency required).
final connectivityProvider =
    NotifierProvider<ConnectivityNotifier, bool>(ConnectivityNotifier.new);

class ConnectivityNotifier extends Notifier<bool> {
  Timer? _timer;

  @override
  bool build() {
    _check();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _check());
    ref.onDispose(() => _timer?.cancel());
    return true;
  }

  Future<void> _check() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      state = result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } on SocketException {
      state = false;
    }
  }
}
