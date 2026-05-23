// lib/core/error/error_reporter.dart
import 'package:flutter/foundation.dart';
import 'package:yu_map/core/result/result.dart';

class ErrorReporter {
  ErrorReporter._();

  static void report(AppException exception, {String? context}) {
    if (kDebugMode) {
      debugPrint(
          '[ErrorReporter]${context != null ? ' [$context]' : ''} $exception');
    }
    // Sentry連携（本番のみ）
    // if (!kDebugMode) Sentry.captureException(exception);
  }

  static void reportUnknown(Object error, {String? context}) {
    if (kDebugMode) {
      debugPrint(
          '[ErrorReporter]${context != null ? ' [$context]' : ''} Unknown: $error');
    }
  }
}
