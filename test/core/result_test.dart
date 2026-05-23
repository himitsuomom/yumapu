// test/core/result_test.dart
//
// Unit tests for the Result<T> sealed class and its AppException hierarchy.
// No Flutter, no Supabase — pure Dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/core/result/result.dart';

void main() {
  group('Result<T>', () {
    test('Success holds data and isSuccess is true', () {
      const result = Success<String>('hello');
      expect(result.isSuccess, isTrue);
      expect(result.isFailure, isFalse);
      expect(result.dataOrNull, equals('hello'));
      expect(result.errorOrNull, isNull);
    });

    test('Failure holds error and isFailure is true', () {
      final result = Failure<String>(
        const NetworkException('network error'),
      );
      expect(result.isFailure, isTrue);
      expect(result.isSuccess, isFalse);
      expect(result.dataOrNull, isNull);
      expect(result.errorOrNull, isA<NetworkException>());
    });

    test('Success with null data (Result<void>) is valid', () {
      const result = Success<void>(null);
      expect(result.isSuccess, isTrue);
      // dataOrNull returns void for Result<void>; just confirm success state
      expect(result.isFailure, isFalse);
    });

    test('pattern matching on Success extracts data', () {
      final Result<int> result = const Success<int>(42);
      final value = switch (result) {
        Success(:final data) => data,
        Failure() => -1,
      };
      expect(value, equals(42));
    });

    test('pattern matching on Failure extracts exception', () {
      final Result<int> result = Failure<int>(
        const NotFoundException('item not found'),
      );
      final error = switch (result) {
        Success() => null,
        Failure(:final exception) => exception,
      };
      expect(error, isA<NotFoundException>());
    });

    test('Failure preserves error code from NetworkException', () {
      final result = Failure<String>(
        const NetworkException('timeout'),
      );
      expect(result.errorOrNull?.code, equals('NETWORK'));
    });

    test('Failure with NotFoundException has correct error code', () {
      final result = Failure<String>(
        const NotFoundException('not found'),
      );
      expect(result.errorOrNull?.code, equals('NOT_FOUND'));
    });

    test('Success<Set<String>> with empty set is valid', () {
      const result = Success<Set<String>>({});
      expect(result.isSuccess, isTrue);
      expect(result.dataOrNull, isEmpty);
    });

    test('dataOrNull returns null for Failure', () {
      final result = Failure<int>(const UnknownException('oops'));
      expect(result.dataOrNull, isNull);
    });

    test('errorOrNull returns null for Success', () {
      const result = Success<int>(1);
      expect(result.errorOrNull, isNull);
    });
  });

  group('AppException subclasses', () {
    test('NetworkException has code NETWORK', () {
      const e = NetworkException('connection refused');
      expect(e.code, equals('NETWORK'));
      expect(e.message, equals('connection refused'));
    });

    test('NotFoundException has code NOT_FOUND', () {
      const e = NotFoundException('resource missing');
      expect(e.code, equals('NOT_FOUND'));
    });

    test('ValidationException has code VALIDATION', () {
      const e = ValidationException('invalid input');
      expect(e.code, equals('VALIDATION'));
    });

    test('NotAuthenticatedException has code AUTH_REQUIRED', () {
      const e = NotAuthenticatedException();
      expect(e.code, equals('AUTH_REQUIRED'));
    });

    test('UniqueConstraintException has code DB_UNIQUE_VIOLATION', () {
      const e = UniqueConstraintException('duplicate key');
      expect(e.code, equals('DB_UNIQUE_VIOLATION'));
    });

    test('UnknownException has code UNKNOWN', () {
      const e = UnknownException('unexpected');
      expect(e.code, equals('UNKNOWN'));
    });

    test('InvalidCredentialsException is an AuthException', () {
      const e = InvalidCredentialsException();
      expect(e, isA<AuthException>());
      expect(e.code, equals('AUTH_INVALID_CREDENTIALS'));
    });

    test('SessionExpiredException is an AuthException', () {
      const e = SessionExpiredException();
      expect(e, isA<AuthException>());
      expect(e.code, equals('AUTH_SESSION_EXPIRED'));
    });
  });
}
