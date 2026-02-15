// test/core/app_logger_test.dart
//
// Tests for the centralized AppLogger.

import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/core/logger/app_logger.dart';

void main() {
  group('LogLevel', () {
    test('debug has lowest index', () {
      expect(LogLevel.debug.index, lessThan(LogLevel.info.index));
    });

    test('info is between debug and warning', () {
      expect(LogLevel.info.index, greaterThan(LogLevel.debug.index));
      expect(LogLevel.info.index, lessThan(LogLevel.warning.index));
    });

    test('warning is between info and error', () {
      expect(LogLevel.warning.index, greaterThan(LogLevel.info.index));
      expect(LogLevel.warning.index, lessThan(LogLevel.error.index));
    });

    test('error has highest index', () {
      expect(LogLevel.error.index, greaterThan(LogLevel.warning.index));
    });

    test('all levels have distinct indices', () {
      final indices = LogLevel.values.map((l) => l.index).toSet();
      expect(indices.length, LogLevel.values.length);
    });

    test('there are exactly 4 log levels', () {
      expect(LogLevel.values.length, 4);
    });
  });

  group('AppLogger', () {
    setUp(() {
      // Reset to default for each test
      AppLogger.minLevel = LogLevel.debug;
    });

    test('minLevel can be set and read', () {
      AppLogger.minLevel = LogLevel.warning;
      expect(AppLogger.minLevel, LogLevel.warning);
    });

    test('debug does not throw', () {
      expect(
        () => AppLogger.debug('test debug message'),
        returnsNormally,
      );
    });

    test('debug with tag does not throw', () {
      expect(
        () => AppLogger.debug('test message', tag: 'TestTag'),
        returnsNormally,
      );
    });

    test('info does not throw', () {
      expect(
        () => AppLogger.info('test info message'),
        returnsNormally,
      );
    });

    test('info with tag does not throw', () {
      expect(
        () => AppLogger.info('test info', tag: 'AuthService'),
        returnsNormally,
      );
    });

    test('warning does not throw', () {
      expect(
        () => AppLogger.warning('test warning'),
        returnsNormally,
      );
    });

    test('warning with error object does not throw', () {
      expect(
        () => AppLogger.warning(
          'warning with error',
          tag: 'Service',
          error: Exception('test'),
        ),
        returnsNormally,
      );
    });

    test('error does not throw', () {
      expect(
        () => AppLogger.error('test error'),
        returnsNormally,
      );
    });

    test('error with all parameters does not throw', () {
      expect(
        () => AppLogger.error(
          'full error',
          tag: 'DB',
          error: Exception('db error'),
          stackTrace: StackTrace.current,
        ),
        returnsNormally,
      );
    });

    test('all log methods accept empty strings', () {
      expect(() => AppLogger.debug(''), returnsNormally);
      expect(() => AppLogger.info(''), returnsNormally);
      expect(() => AppLogger.warning(''), returnsNormally);
      expect(() => AppLogger.error(''), returnsNormally);
    });

    test('all log methods accept Japanese text', () {
      expect(() => AppLogger.debug('デバッグメッセージ'), returnsNormally);
      expect(() => AppLogger.info('ユーザーログイン', tag: '認証'), returnsNormally);
      expect(() => AppLogger.warning('接続が不安定'), returnsNormally);
      expect(() => AppLogger.error('サーバーエラー'), returnsNormally);
    });

    test('setting minLevel to error suppresses lower levels without error', () {
      AppLogger.minLevel = LogLevel.error;

      // These should complete without error (they just won't output)
      expect(() => AppLogger.debug('should be suppressed'), returnsNormally);
      expect(() => AppLogger.info('should be suppressed'), returnsNormally);
      expect(() => AppLogger.warning('should be suppressed'), returnsNormally);
      expect(() => AppLogger.error('should appear'), returnsNormally);
    });
  });
}
