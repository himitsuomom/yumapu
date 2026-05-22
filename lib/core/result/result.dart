// lib/core/result/result.dart
sealed class Result<T> {
  const Result();

  T? get dataOrNull => switch (this) {
        Success(:final data) => data,
        Failure() => null,
      };

  AppException? get errorOrNull => switch (this) {
        Success() => null,
        Failure(:final exception) => exception,
      };

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
}

final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

final class Failure<T> extends Result<T> {
  const Failure(this.exception);
  final AppException exception;
}

// ── 例外階層 ──────────────────────────────────────────────────────────────────

sealed class AppException implements Exception {
  const AppException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  // Subclasses override to provide a stable error code.
  String? get code => null;

  @override
  String toString() => '$runtimeType($code): $message';
}

// ネットワーク・サーバー系
final class NetworkException extends AppException {
  const NetworkException(super.message, [super.cause]);

  @override
  String? get code => 'NETWORK';
}

final class ServerException extends AppException {
  const ServerException(super.message, [super.cause, this._code]);
  final String? _code;

  @override
  String? get code => _code;
}

final class TimeoutException extends AppException {
  const TimeoutException(super.message, [super.cause]);

  @override
  String? get code => 'TIMEOUT';
}

final class CacheException extends AppException {
  const CacheException(super.message, [super.cause]);

  @override
  String? get code => 'CACHE';
}

// 認証系（新規）
sealed class AuthException extends AppException {
  const AuthException(super.message, [super.cause]);
}

final class InvalidCredentialsException extends AuthException {
  const InvalidCredentialsException([Object? cause])
      : super('メールアドレスまたはパスワードが正しくありません', cause);

  @override
  String? get code => 'AUTH_INVALID_CREDENTIALS';
}

final class UserNotFoundException extends AuthException {
  const UserNotFoundException([Object? cause])
      : super('ユーザーが見つかりません', cause);

  @override
  String? get code => 'AUTH_USER_NOT_FOUND';
}

final class EmailAlreadyInUseException extends AuthException {
  const EmailAlreadyInUseException([Object? cause])
      : super('このメールアドレスは既に登録されています', cause);

  @override
  String? get code => 'AUTH_EMAIL_IN_USE';
}

final class SessionExpiredException extends AuthException {
  const SessionExpiredException([Object? cause])
      : super('セッションが期限切れです。再ログインしてください', cause);

  @override
  String? get code => 'AUTH_SESSION_EXPIRED';
}

final class NotAuthenticatedException extends AuthException {
  const NotAuthenticatedException() : super('ログインが必要です');

  @override
  String? get code => 'AUTH_REQUIRED';
}

final class WeakPasswordException extends AuthException {
  const WeakPasswordException([Object? cause])
      : super('パスワードが弱すぎます', cause);

  @override
  String? get code => 'AUTH_WEAK_PASSWORD';
}

// DB操作系
final class UniqueConstraintException extends AppException {
  const UniqueConstraintException(super.message, [super.cause]);

  @override
  String? get code => 'DB_UNIQUE_VIOLATION';
}

final class ForeignKeyException extends AppException {
  const ForeignKeyException(super.message, [super.cause]);

  @override
  String? get code => 'DB_FK_VIOLATION';
}

final class PermissionDeniedException extends AppException {
  const PermissionDeniedException(super.message, [super.cause]);

  @override
  String? get code => 'DB_PERMISSION_DENIED';
}

final class NotFoundException extends AppException {
  const NotFoundException(super.message, [super.cause]);

  @override
  String? get code => 'NOT_FOUND';
}

// バリデーション系
final class ValidationException extends AppException {
  const ValidationException(super.message, [super.cause]);

  @override
  String? get code => 'VALIDATION';
}

final class BusinessRuleException extends AppException {
  const BusinessRuleException(super.message, [super.cause, this._code]);
  final String? _code;

  @override
  String? get code => _code;
}

// 不明
final class UnknownException extends AppException {
  const UnknownException(super.message, [super.cause]);

  @override
  String? get code => 'UNKNOWN';
}
