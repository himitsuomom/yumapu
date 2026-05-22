// lib/core/result/run_catching.dart
import 'package:yu_map/core/error/error_mapper.dart';
import 'result.dart';

Future<Result<T>> runCatching<T>(Future<T> Function() action) async {
  try {
    return Success(await action());
  } catch (e) {
    return Failure(ErrorMapper.map(e));
  }
}

Result<T> runCatchingSync<T>(T Function() action) {
  try {
    return Success(action());
  } catch (e) {
    return Failure(ErrorMapper.map(e));
  }
}
