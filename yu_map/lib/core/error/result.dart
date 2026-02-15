// lib/core/error/result.dart
//
// Functional Result<T> type for operation outcomes.
// Eliminates nullable return values and unhandled exceptions.

import 'package:yu_map/core/error/app_exceptions.dart';

/// Represents either a successful value [T] or an [AppException].
sealed class Result<T> {
  const Result();

  /// Create a successful result.
  const factory Result.success(T value) = Success<T>;

  /// Create a failure result.
  const factory Result.failure(AppException exception) = Failure<T>;

  /// True if this result is [Success].
  bool get isSuccess => this is Success<T>;

  /// True if this result is [Failure].
  bool get isFailure => this is Failure<T>;

  /// Returns the value or null.
  T? get valueOrNull => switch (this) {
        Success(value: final v) => v,
        Failure() => null,
      };

  /// Returns the exception or null.
  AppException? get exceptionOrNull => switch (this) {
        Success() => null,
        Failure(exception: final e) => e,
      };

  /// Pattern match on the result.
  R when<R>({
    required R Function(T value) success,
    required R Function(AppException exception) failure,
  }) =>
      switch (this) {
        Success(value: final v) => success(v),
        Failure(exception: final e) => failure(e),
      };

  /// Map the success value.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Success(value: final v) => Result.success(transform(v)),
        Failure(exception: final e) => Result.failure(e),
      };

  /// FlatMap for chaining operations.
  Result<R> flatMap<R>(Result<R> Function(T value) transform) => switch (this) {
        Success(value: final v) => transform(v),
        Failure(exception: final e) => Result.failure(e),
      };

  /// Returns the value or throws the exception.
  T getOrThrow() => switch (this) {
        Success(value: final v) => v,
        Failure(exception: final e) => throw e,
      };

  /// Returns the value or a default.
  T getOrDefault(T defaultValue) => switch (this) {
        Success(value: final v) => v,
        Failure() => defaultValue,
      };
}

/// Successful result containing a value.
class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);

  @override
  String toString() => 'Success($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Failure result containing an exception.
class Failure<T> extends Result<T> {
  final AppException exception;
  const Failure(this.exception);

  @override
  String toString() => 'Failure($exception)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure<T> && other.exception.message == exception.message;

  @override
  int get hashCode => exception.message.hashCode;
}

/// Helper to run async operations and wrap in Result.
Future<Result<T>> runCatching<T>(Future<T> Function() block) async {
  try {
    return Result.success(await block());
  } on AppException catch (e) {
    return Result.failure(e);
  } catch (e) {
    return Result.failure(
      ServerException('予期しないエラーが発生しました', null, e),
    );
  }
}
