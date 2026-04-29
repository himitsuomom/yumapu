import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// バックグラウンド通知ハンドラー（top-level 関数必須）
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background notification: ${message.notification?.title}');
}

/// FCM デバイストークンの登録・更新と
/// フォアグラウンド/バックグラウンド通知ハンドリングを担当するサービス。
///
/// 使い方:
///   1. main.dart で Firebase 初期化後に initialize() を呼ぶ
///   2. ログイン後に registerToken() を呼んでトークンを Supabase に保存
///   3. ログアウト時に removeToken() を呼んで古いトークンを削除
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'yumap_default',
    '湯マップ通知',
    description: 'いいね・コメント・フォローなどの通知',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    // バックグラウンドハンドラー登録（top-level 関数）
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // iOS/macOS の通知許可リクエスト
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Push notification permission denied');
      return;
    }

    // Android 13+ のローカル通知チャンネル作成
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_androidChannel);

    // ローカル通知プラグインの初期化
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    // iOS フォアグラウンドでもバナー表示
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // フォアグラウンドでのメッセージ受信
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // バックグラウンドからアプリを開いたとき
    FirebaseMessaging.onMessageOpenedApp.listen(_onNotificationTapped);

    // アプリが terminated 状態から通知タップで起動したとき
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _onNotificationTapped(initialMessage);
  }

  /// ログイン後に呼ぶ: FCM トークンを取得して Supabase に保存する
  Future<void> registerToken() async {
    // iOS: APNs トークンが取得できてから FCM トークンを取得
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await _messaging.getAPNSToken();
    }
    final token = await _messaging.getToken();
    if (token != null) await _upsertToken(token);

    // トークンリフレッシュ時に再保存
    _messaging.onTokenRefresh.listen(_upsertToken);
  }

  /// ログアウト時に呼ぶ: このデバイスのトークンを削除する
  Future<void> removeToken() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final token = await _messaging.getToken();
    if (token == null) return;

    await Supabase.instance.client
        .from('push_tokens')
        .delete()
        .eq('user_id', user.id)
        .eq('token', token)
        .catchError((e) => debugPrint('push token remove failed: $e'));

    await _messaging.deleteToken();
  }

  Future<void> _upsertToken(String token) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final platform =
        defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

    await Supabase.instance.client
        .from('push_tokens')
        .upsert(
          {
            'user_id': user.id,
            'token': token,
            'platform': platform,
            'updated_at': DateTime.now().toIso8601String(),
          },
          onConflict: 'user_id,token',
        )
        .catchError((e) => debugPrint('push token upsert failed: $e'));

    debugPrint('FCM token registered: ${token.substring(0, 20)}...');
  }

  void _onForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    // フォアグラウンド時はローカル通知として表示
    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: _encodePayload(message.data),
    );
  }

  void _onNotificationTapped(RemoteMessage message) {
    _handleNavigation(message.data);
  }

  void _onLocalNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;
    final data = _decodePayload(response.payload!);
    _handleNavigation(data);
  }

  /// 通知タイプに応じた画面遷移
  /// type: 'like' | 'comment' | 'follow' | 'checkin_badge'
  void _handleNavigation(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final targetId = data['target_id'] as String?;
    debugPrint('Notification nav: type=$type, target=$targetId');

    // TODO: GoRouter が利用可能になったら以下のように遷移する
    // switch (type) {
    //   case 'like':
    //   case 'comment':
    //     router.push('/posts/$targetId');
    //   case 'follow':
    //     router.push('/profile/$targetId');
    //   case 'checkin_badge':
    //     router.push('/badges');
    // }
  }

  String _encodePayload(Map<String, dynamic> data) =>
      data.entries.map((e) => '${e.key}=${e.value}').join('&');

  Map<String, dynamic> _decodePayload(String payload) =>
      Map.fromEntries(payload.split('&').map((e) {
        final parts = e.split('=');
        return MapEntry(parts[0], parts.length > 1 ? parts[1] : '');
      }));
}
