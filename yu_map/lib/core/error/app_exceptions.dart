// lib/core/error/app_exceptions.dart
//
// Typed exception hierarchy for Yu-Map.
// Every service should throw one of these instead of raw Exception/StateError.

/// Base exception for all Yu-Map application errors.
sealed class AppException implements Exception {
  final String message;
  final String? code;
  final Object? cause;

  const AppException(this.message, {this.code, this.cause});

  @override
  String toString() => '$runtimeType: $message${code != null ? ' [$code]' : ''}';
}

/// User is not authenticated but the operation requires it.
class AuthRequiredException extends AppException {
  const AuthRequiredException([String message = 'ログインが必要です'])
      : super(message, code: 'AUTH_REQUIRED');
}

/// Authentication attempt failed (wrong credentials, etc.).
class AuthFailedException extends AppException {
  const AuthFailedException([String message = 'ログインに失敗しました', Object? cause])
      : super(message, code: 'AUTH_FAILED', cause: cause);
}

/// A requested resource was not found.
class NotFoundException extends AppException {
  const NotFoundException([String message = 'データが見つかりません'])
      : super(message, code: 'NOT_FOUND');
}

/// A network request failed (timeout, no connection, etc.).
class NetworkException extends AppException {
  const NetworkException([String message = 'ネットワークエラーが発生しました', Object? cause])
      : super(message, code: 'NETWORK_ERROR', cause: cause);
}

/// The server returned an unexpected error.
class ServerException extends AppException {
  final int? statusCode;

  const ServerException([
    String message = 'サーバーエラーが発生しました',
    this.statusCode,
    Object? cause,
  ]) : super(message, code: 'SERVER_ERROR', cause: cause);

  @override
  String toString() =>
      'ServerException: $message${statusCode != null ? ' (HTTP $statusCode)' : ''}';
}

/// Input validation failed.
class ValidationException extends AppException {
  final Map<String, String> fieldErrors;

  const ValidationException(
    String message, {
    this.fieldErrors = const {},
  }) : super(message, code: 'VALIDATION_ERROR');
}

/// A duplicate record was detected (e.g. duplicate check-in).
class DuplicateException extends AppException {
  const DuplicateException([String message = '既に登録されています'])
      : super(message, code: 'DUPLICATE');
}

/// Permission / authorization denied.
class PermissionDeniedException extends AppException {
  const PermissionDeniedException([String message = '権限がありません'])
      : super(message, code: 'PERMISSION_DENIED');
}

/// Storage-related error (upload, download, delete).
class StorageException extends AppException {
  const StorageException([String message = 'ストレージエラーが発生しました', Object? cause])
      : super(message, code: 'STORAGE_ERROR', cause: cause);
}

/// Cache-related error.
class CacheException extends AppException {
  const CacheException([String message = 'キャッシュエラーが発生しました', Object? cause])
      : super(message, code: 'CACHE_ERROR', cause: cause);
}
