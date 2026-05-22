// lib/core/result/result_extensions.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'result.dart';

extension ResultExtensions<T> on Result<T> {
  AsyncValue<T> toAsyncValue() => switch (this) {
        Success(:final data) => AsyncData(data),
        Failure(:final exception) => AsyncError(exception, StackTrace.current),
      };

  Result<T> onSuccess(void Function(T data) f) {
    if (this case Success(:final data)) f(data);
    return this;
  }

  Result<T> onFailure(void Function(AppException e) f) {
    if (this case Failure(:final exception)) f(exception);
    return this;
  }

  Result<R> mapResult<R>(R Function(T data) transform) => switch (this) {
        Success(:final data) => Success(transform(data)),
        Failure(:final exception) => Failure<R>(exception),
      };
}
