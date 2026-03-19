sealed class Result<T> {
  const Result();
}

final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;
}

final class Failure<T> extends Result<T> {
  const Failure(this.exception);
  final AppException exception;
}

sealed class AppException implements Exception {
  const AppException(this.message, [this.cause]);
  final String message;
  final Object? cause;
}

final class NetworkException extends AppException {
  const NetworkException(super.message, [super.cause]);
}

final class ServerException extends AppException {
  const ServerException(super.message, [super.cause]);
}

final class CacheException extends AppException {
  const CacheException(super.message, [super.cause]);
}

final class UnknownException extends AppException {
  const UnknownException(super.message, [super.cause]);
}
