// lib/core/logger/app_logger.dart
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warning, error }

class AppLogger {
  AppLogger._();

  static LogLevel _minimumLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  static void setMinimumLevel(LogLevel level) {
    _minimumLevel = level;
  }

  static void debug(String message, {String? tag}) {
    _log(LogLevel.debug, message, tag: tag);
  }

  static void info(String message, {String? tag}) {
    _log(LogLevel.info, message, tag: tag);
  }

  static void warning(String message, {String? tag, Object? error}) {
    _log(LogLevel.warning, message, tag: tag, error: error);
  }

  static void error(String message, {String? tag, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < _minimumLevel.index) return;

    final prefix = '[${level.name.toUpperCase()}]${tag != null ? '[$tag]' : ''}';

    // Log in debug mode, or errors in release mode (for diagnostics)
    if (kDebugMode || level == LogLevel.error) {
      developer.log(
        '$prefix $message',
        name: tag ?? 'App',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}
