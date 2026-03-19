import 'dart:io';
import 'result.dart';

Future<Result<T>> runCatching<T>(Future<T> Function() action) async {
  try {
    final data = await action();
    return Success(data);
  } on SocketException catch (e) {
    return Failure(NetworkException('A network error occurred', e));
  } on AppException catch (e) {
    return Failure(e);
  } catch (e) {
    return Failure(UnknownException('An unexpected error occurred', e));
  }
}
