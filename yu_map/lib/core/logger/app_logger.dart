// lib/core/logger/app_logger.dart
//
// Centralized logging utility replacing scattered debugPrint calls.
// Provides structured log levels and optional Sentry/analytics integration.

import 'package:flutter/foundation.dart';

/// Log severity levels.
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Centralized logger for Yu-Map.
///
/// Usage:
/// ```dart
/// AppLogger.info('User signed in', tag: 'AuthService');
/// AppLogger.error('Failed to fetch', error: e, stackTrace: st, tag: 'API');
/// ```
class AppLogger {
  AppLogger._();

  /// Minimum level to output (debug in debug mode, info in release).
  static LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  /// Override the minimum log level (useful for tests).
  static set minLevel(LogLevel level) => _minLevel = level;

  /// Get the current minimum log level.
  static LogLevel get minLevel => _minLevel;

  /// Log a debug message.
  static void debug(String message, {String? tag}) {
    _log(LogLevel.debug, message, tag: tag);
  }

  /// Log an informational message.
  static void info(String message, {String? tag}) {
    _log(LogLevel.info, message, tag: tag);
  }

  /// Log a warning.
  static void warning(String message, {String? tag, Object? error}) {
    _log(LogLevel.warning, message, tag: tag, error: error);
  }

  /// Log an error with optional stack trace.
  static void error(
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Internal log dispatcher.
  static void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < _minLevel.index) return;

    final prefix = _levelPrefix(level);
    final tagStr = tag != null ? '[$tag] ' : '';
    final logMessage = '$prefix $tagStr$message';

    debugPrint(logMessage);

    if (error != null) {
      debugPrint('  ↳ Error: $error');
    }
    if (stackTrace != null && level == LogLevel.error) {
      debugPrint('  ↳ StackTrace: $stackTrace');
    }
  }

  static String _levelPrefix(LogLevel level) => switch (level) {
        LogLevel.debug => '[DEBUG]',
        LogLevel.info => '[INFO]',
        LogLevel.warning => '[WARN]',
        LogLevel.error => '[ERROR]',
      };
}
