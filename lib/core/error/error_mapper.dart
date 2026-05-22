// lib/core/error/error_mapper.dart
import 'dart:async' as dart_async;
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/result/result.dart';

class ErrorMapper {
  ErrorMapper._();

  static AppException map(Object error) {
    if (error is AuthApiException) {
      final code = error.code ?? '';
      final msg = error.message.toLowerCase();
      if (code == 'invalid_credentials' ||
          msg.contains('invalid login') ||
          msg.contains('invalid credentials')) {
        return InvalidCredentialsException(error);
      }
      if (msg.contains('already registered') ||
          code == 'email_exists' ||
          msg.contains('already been registered')) {
        return EmailAlreadyInUseException(error);
      }
      if (msg.contains('weak password') || code == 'weak_password') {
        return WeakPasswordException(error);
      }
      if ((msg.contains('session') && msg.contains('expired')) ||
          code == 'session_not_found') {
        return SessionExpiredException(error);
      }
      return ServerException('認証エラー: ${error.message}', error, code);
    }

    if (error is PostgrestException) {
      switch (error.code) {
        case '23505':
          return UniqueConstraintException('一意制約違反: ${error.message}', error);
        case '23503':
          return ForeignKeyException('参照整合性違反: ${error.message}', error);
        case '42501':
        case 'PGRST301':
          return PermissionDeniedException('権限がありません', error);
        case 'PGRST116':
          return NotFoundException('対象が見つかりません', error);
        default:
          return ServerException(
              'DBエラー: ${error.message}', error, error.code);
      }
    }

    if (error is StorageException) {
      if (error.statusCode == '404') {
        return NotFoundException('ファイルが見つかりません', error);
      }
      if (error.statusCode == '403') {
        return PermissionDeniedException('ストレージへのアクセスが拒否されました', error);
      }
      return ServerException(
          'ストレージエラー: ${error.message}', error, error.statusCode);
    }

    if (error is SocketException) {
      return NetworkException('ネットワーク接続を確認してください', error);
    }
    if (error is HttpException) {
      return NetworkException('HTTPエラー: ${error.message}', error);
    }
    if (error is dart_async.TimeoutException) {
      return TimeoutException('リクエストがタイムアウトしました', error);
    }
    if (error is AppException) return error;

    return UnknownException('予期しないエラー: $error', error);
  }
}
