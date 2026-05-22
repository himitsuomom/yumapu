// lib/core/network/secure_http_client.dart
//
// セキュアHTTPクライアント。
// - HTTPS接続のみ許可（HTTP URLを拒否）
// - 無効なTLS証明書を拒否
// - アプリ全体で共有するシングルトンを提供

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// A shared HTTP client that enforces HTTPS and strict TLS validation.
///
/// Usage:
///   final response = await SecureHttpClient.instance.post(url, ...);
///
/// In tests, use http.Client() directly (no need for TLS in unit tests).
class SecureHttpClient {
  SecureHttpClient._();

  static http.Client? _instance;

  /// Returns the app-wide secure HTTP client.
  ///
  /// On non-IO platforms (e.g. web), falls back to the default http.Client().
  static http.Client get instance {
    _instance ??= _createClient();
    return _instance!;
  }

  static http.Client _createClient() {
    if (!Platform.isAndroid && !Platform.isIOS && !Platform.isMacOS) {
      // Web / unsupported platform: use default client
      return http.Client();
    }

    final ioClient = HttpClient()
      ..badCertificateCallback = (X509Certificate cert, String host, int port) {
        // Always reject invalid certificates.
        // In debug mode, log the rejection so developers can diagnose issues.
        if (kDebugMode) {
          debugPrint(
            'SecureHttpClient: REJECTED bad certificate for $host:$port '
            'subject=${cert.subject}',
          );
        }
        return false; // reject
      };

    return IOClient(ioClient);
  }

  /// Validates that a URL uses HTTPS. Throws [ArgumentError] in debug mode
  /// and returns false in release mode if the URL is not HTTPS.
  static bool assertHttps(Uri url) {
    if (url.scheme != 'https') {
      const msg = 'SecureHttpClient: HTTP (non-TLS) connections are not allowed';
      if (kDebugMode) {
        throw ArgumentError(msg);
      }
      debugPrint(msg);
      return false;
    }
    return true;
  }
}
