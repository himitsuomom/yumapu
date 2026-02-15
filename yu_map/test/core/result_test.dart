// test/core/result_test.dart
//
// Tests for the Result<T> type and runCatching helper.

import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/core/error/app_exceptions.dart';
import 'package:yu_map/core/error/result.dart';

void main() {
  group('Success', () {
    test('isSuccess returns true', () {
      const result = Result<int>.success(42);
      expect(result.isSuccess, true);
      expect(result.isFailure, false);
    });

    test('valueOrNull returns the value', () {
      const result = Result<String>.success('hello');
      expect(result.valueOrNull, 'hello');
    });

    test('exceptionOrNull returns null', () {
      const result = Result<int>.success(1);
      expect(result.exceptionOrNull, isNull);
    });

    test('getOrThrow returns value', () {
      const result = Result<int>.success(42);
      expect(result.getOrThrow(), 42);
    });

    test('getOrDefault returns value (not default)', () {
      const result = Result<int>.success(42);
      expect(result.getOrDefault(0), 42);
    });

    test('when calls success branch', () {
      const result = Result<int>.success(5);
      final output = result.when(
        success: (v) => 'value: $v',
        failure: (e) => 'error: ${e.message}',
      );
      expect(output, 'value: 5');
    });

    test('map transforms the value', () {
      const result = Result<int>.success(5);
      final mapped = result.map((v) => v * 2);

      expect(mapped.isSuccess, true);
      expect(mapped.valueOrNull, 10);
    });

    test('flatMap chains successfully', () {
      const result = Result<int>.success(5);
      final chained = result.flatMap((v) => Result.success(v.toString()));

      expect(chained.isSuccess, true);
      expect(chained.valueOrNull, '5');
    });

    test('flatMap chains to failure', () {
      const result = Result<int>.success(5);
      final chained = result.flatMap<String>(
        (v) => const Result.failure(NotFoundException()),
      );

      expect(chained.isFailure, true);
    });

    test('equality works for same values', () {
      const r1 = Result<int>.success(42);
      const r2 = Result<int>.success(42);
      expect(r1, equals(r2));
    });

    test('inequality for different values', () {
      const r1 = Result<int>.success(1);
      const r2 = Result<int>.success(2);
      expect(r1, isNot(equals(r2)));
    });

    test('toString is descriptive', () {
      const result = Result<String>.success('test');
      expect(result.toString(), 'Success(test)');
    });
  });

  group('Failure', () {
    test('isFailure returns true', () {
      const result = Result<int>.failure(NotFoundException());
      expect(result.isFailure, true);
      expect(result.isSuccess, false);
    });

    test('valueOrNull returns null', () {
      const result = Result<int>.failure(NotFoundException());
      expect(result.valueOrNull, isNull);
    });

    test('exceptionOrNull returns the exception', () {
      const result = Result<int>.failure(NotFoundException());
      expect(result.exceptionOrNull, isA<NotFoundException>());
    });

    test('getOrThrow throws the exception', () {
      const result = Result<int>.failure(AuthRequiredException());
      expect(() => result.getOrThrow(), throwsA(isA<AuthRequiredException>()));
    });

    test('getOrDefault returns the default', () {
      const result = Result<int>.failure(NotFoundException());
      expect(result.getOrDefault(99), 99);
    });

    test('when calls failure branch', () {
      const result = Result<int>.failure(NotFoundException('not found'));
      final output = result.when(
        success: (v) => 'value: $v',
        failure: (e) => 'error: ${e.code}',
      );
      expect(output, 'error: NOT_FOUND');
    });

    test('map preserves failure', () {
      const result = Result<int>.failure(NotFoundException());
      final mapped = result.map((v) => v * 2);

      expect(mapped.isFailure, true);
      expect(mapped.exceptionOrNull, isA<NotFoundException>());
    });

    test('flatMap preserves failure', () {
      const result = Result<int>.failure(NotFoundException());
      final chained = result.flatMap((v) => Result.success(v.toString()));

      expect(chained.isFailure, true);
    });

    test('toString is descriptive', () {
      const result = Result<int>.failure(NotFoundException());
      expect(result.toString(), startsWith('Failure('));
    });
  });

  group('runCatching', () {
    test('returns Success for normal completion', () async {
      final result = await runCatching(() async => 42);
      expect(result.isSuccess, true);
      expect(result.valueOrNull, 42);
    });

    test('returns Failure for AppException', () async {
      final result = await runCatching<int>(() async {
        throw const NotFoundException('test');
      });
      expect(result.isFailure, true);
      expect(result.exceptionOrNull, isA<NotFoundException>());
    });

    test('wraps unknown exceptions in ServerException', () async {
      final result = await runCatching<int>(() async {
        throw Exception('unexpected');
      });
      expect(result.isFailure, true);
      expect(result.exceptionOrNull, isA<ServerException>());
      expect(result.exceptionOrNull?.cause, isA<Exception>());
    });

    test('wraps String throw in ServerException', () async {
      final result = await runCatching<int>(() async {
        throw 'raw string error';
      });
      expect(result.isFailure, true);
      expect(result.exceptionOrNull, isA<ServerException>());
    });

    test('wraps AuthRequiredException specifically', () async {
      final result = await runCatching<int>(() async {
        throw const AuthRequiredException();
      });
      expect(result.isFailure, true);
      expect(result.exceptionOrNull, isA<AuthRequiredException>());
      expect(result.exceptionOrNull?.code, 'AUTH_REQUIRED');
    });
  });

  group('Result practical usage patterns', () {
    test('chaining multiple operations', () {
      const result = Result<int>.success(10);

      final output = result
          .map((v) => v * 2)
          .map((v) => v + 5)
          .map((v) => 'Result: $v');

      expect(output.valueOrNull, 'Result: 25');
    });

    test('early failure stops chain', () {
      const Result<int> result = Result.failure(NotFoundException());

      final output = result
          .map((v) => v * 2) // skipped
          .map((v) => v + 5) // skipped
          .map((v) => 'Result: $v'); // skipped

      expect(output.isFailure, true);
    });

    test('pattern matching with switch', () {
      const Result<int> result = Result.success(42);

      final message = switch (result) {
        Success(value: final v) => 'Got $v',
        Failure(exception: final e) => 'Error: ${e.message}',
      };

      expect(message, 'Got 42');
    });
  });
}
