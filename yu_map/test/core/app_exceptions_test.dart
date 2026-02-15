// test/core/app_exceptions_test.dart
//
// Tests for the custom exception hierarchy.

import 'package:flutter_test/flutter_test.dart';
import 'package:yu_map/core/error/app_exceptions.dart';

void main() {
  group('AppException hierarchy', () {
    test('AuthRequiredException has correct defaults', () {
      const e = AuthRequiredException();
      expect(e.message, 'ログインが必要です');
      expect(e.code, 'AUTH_REQUIRED');
      expect(e.cause, isNull);
      expect(e.toString(), contains('AuthRequiredException'));
      expect(e.toString(), contains('AUTH_REQUIRED'));
    });

    test('AuthRequiredException with custom message', () {
      const e = AuthRequiredException('カスタムメッセージ');
      expect(e.message, 'カスタムメッセージ');
    });

    test('AuthFailedException has correct defaults', () {
      const e = AuthFailedException();
      expect(e.message, 'ログインに失敗しました');
      expect(e.code, 'AUTH_FAILED');
    });

    test('AuthFailedException preserves cause', () {
      final cause = Exception('original error');
      final e = AuthFailedException('failed', cause);
      expect(e.cause, cause);
    });

    test('NotFoundException has correct defaults', () {
      const e = NotFoundException();
      expect(e.message, 'データが見つかりません');
      expect(e.code, 'NOT_FOUND');
    });

    test('NetworkException has correct defaults', () {
      const e = NetworkException();
      expect(e.message, 'ネットワークエラーが発生しました');
      expect(e.code, 'NETWORK_ERROR');
    });

    test('ServerException includes status code in toString', () {
      const e = ServerException('error', 500);
      expect(e.statusCode, 500);
      expect(e.toString(), contains('HTTP 500'));
    });

    test('ServerException without status code', () {
      const e = ServerException();
      expect(e.statusCode, isNull);
      expect(e.toString(), isNot(contains('HTTP')));
    });

    test('ValidationException carries field errors', () {
      const e = ValidationException(
        'バリデーションエラー',
        fieldErrors: {'email': '無効なメールアドレス', 'username': '短すぎます'},
      );
      expect(e.code, 'VALIDATION_ERROR');
      expect(e.fieldErrors.length, 2);
      expect(e.fieldErrors['email'], '無効なメールアドレス');
    });

    test('ValidationException with empty field errors', () {
      const e = ValidationException('invalid');
      expect(e.fieldErrors, isEmpty);
    });

    test('DuplicateException has correct defaults', () {
      const e = DuplicateException();
      expect(e.message, '既に登録されています');
      expect(e.code, 'DUPLICATE');
    });

    test('PermissionDeniedException has correct defaults', () {
      const e = PermissionDeniedException();
      expect(e.message, '権限がありません');
      expect(e.code, 'PERMISSION_DENIED');
    });

    test('StorageException has correct defaults', () {
      const e = StorageException();
      expect(e.message, 'ストレージエラーが発生しました');
      expect(e.code, 'STORAGE_ERROR');
    });

    test('CacheException has correct defaults', () {
      const e = CacheException();
      expect(e.message, 'キャッシュエラーが発生しました');
      expect(e.code, 'CACHE_ERROR');
    });

    test('all exceptions implement Exception', () {
      const exceptions = <AppException>[
        AuthRequiredException(),
        AuthFailedException(),
        NotFoundException(),
        NetworkException(),
        ServerException(),
        ValidationException('test'),
        DuplicateException(),
        PermissionDeniedException(),
        StorageException(),
        CacheException(),
      ];

      for (final e in exceptions) {
        expect(e, isA<Exception>());
        expect(e, isA<AppException>());
        expect(e.message, isNotEmpty);
        expect(e.code, isNotNull);
      }
    });

    test('all exception codes are unique', () {
      const exceptions = <AppException>[
        AuthRequiredException(),
        AuthFailedException(),
        NotFoundException(),
        NetworkException(),
        ServerException(),
        ValidationException('test'),
        DuplicateException(),
        PermissionDeniedException(),
        StorageException(),
        CacheException(),
      ];

      final codes = exceptions.map((e) => e.code).toSet();
      expect(codes.length, exceptions.length);
    });

    test('sealed class prevents external subclassing', () {
      // Verify pattern matching covers all cases
      const AppException e = AuthRequiredException();
      final result = switch (e) {
        AuthRequiredException() => 'auth_required',
        AuthFailedException() => 'auth_failed',
        NotFoundException() => 'not_found',
        NetworkException() => 'network',
        ServerException() => 'server',
        ValidationException() => 'validation',
        DuplicateException() => 'duplicate',
        PermissionDeniedException() => 'permission',
        StorageException() => 'storage',
        CacheException() => 'cache',
      };
      expect(result, 'auth_required');
    });
  });
}
