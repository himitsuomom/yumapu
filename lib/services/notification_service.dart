import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show ValueNotifier, WidgetsBinding;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yu_map/core/navigation/app_navigator.dart';

/// バックグラウンド通知ハンドラー（top-level 関数必須）
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background notification: ${message.notification?.title}');
}

/// FCM デバイストークンの登録・更新と
/// フォアグラウンド/バックグラウンド通知ハンドリングを担当するサービス。
///
/// 使い方:
///   1. main.dart で Firebase 初期化後に initialize() を呼ぶ（権限リクエストなし）
///   2. ログイン後に registerToken() + requestPermissionLazily() を呼ぶ
///   3. ログアウト時に removeToken() を呼んで古いトークンを削除
///
/// ## 通知許可タイミングについて
///
/// 許可ダイアログをアプリ起動直後に表示するのはユーザー体験が悪い（許可率が低下する）。
/// 代わりにログイン後の [requestPermissionLazily] を呼ぶことで、
/// ユーザーがアプリの価値を理解した後に許可を求める設計にしている。
/// 一度 granted/denied が確定した後は再リクエストしない（notDetermined の場合のみリクエスト）。
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  /// cold start（アプリ終了状態から通知タップで起動）時に
  /// Navigator がまだ存在しないため、一時的に保留するルート。
  /// [drainPendingNavigation] が呼ばれた時点で実行する。
  String? _pendingNavigation;

  /// 保留ナビゲーションに渡す引数（施設IDなど）。
  /// '/facility' の場合は String 型の施設IDを保持する。
  Object? _pendingNavigationArgs;

  static const _androidChannel = AndroidNotificationChannel(
    'yumap_default',
    '湯マップ通知',
    description: 'いいね・コメント・フォローなどの通知',
    importance: Importance.high,
  );

  /// アプリ起動時に呼ぶ初期化処理。
  ///
  /// 通知許可ダイアログは表示しない。すべてのハンドラーとチャンネルは
  /// 許可状態に関わらず設定する（後から許可が得られた場合に備えるため）。
  Future<void> initialize() async {
    // バックグラウンドハンドラー登録（top-level 関数）
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Android 13+ のローカル通知チャンネル作成
    // 許可状態に関わらず作成しておく（権限取得後にすぐ使えるよう）
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

    // iOS フォアグラウンドでもバナー表示（許可後に有効になる）
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
    // cold start では Navigator がまだ存在しないため、保留キューに積んで
    // Navigator が使えるようになるまで待機する。
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _storePendingNavigation(initialMessage.data);
    }
  }

  /// ログイン後に呼ぶ: 通知許可を遅延リクエストする。
  ///
  /// - 既に granted/denied が確定済みの場合は何もしない（再リクエストしない）
  /// - notDetermined（iOS: 未決定 / Android: 未リクエスト）の場合のみ許可ダイアログを表示
  ///
  /// ログイン後に呼ぶことで「アプリの価値を理解したユーザー」に許可を求めるため、
  /// 起動直後に表示するより許可率が高くなる（industry standard パターン）。
  Future<void> requestPermissionLazily() async {
    final current = await _messaging.getNotificationSettings();
    if (current.authorizationStatus != AuthorizationStatus.notDetermined) {
      // 既に判定済み（granted / denied / provisional）→ 再リクエストしない
      debugPrint(
          'Notification permission already determined: ${current.authorizationStatus}');
      return;
    }

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Push notification permission denied by user');
    } else {
      debugPrint(
          'Push notification permission granted: ${settings.authorizationStatus}');
    }
  }

  /// 通知が有効かどうかを返す。
  ///
  /// UX-62 で設定画面の通知トグルの初期値を決定するために使用する。
  /// granted / provisional → true、それ以外 → false。
  Future<bool> isNotificationEnabled() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// OS レベルで通知が拒否されているかどうかを返す。
  ///
  /// UX-66 対応: denied の場合はアプリ内のトグルでは変更できないため
  /// OS の設定画面へ誘導するUIを表示するために使用する。
  Future<bool> isNotificationDenied() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.denied;
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

  /// cold start の保留ナビゲーションを実行する。
  ///
  /// Navigator が利用可能になったタイミング（app.dart の initState）で
  /// 一度だけ呼ぶ。保留ルートがなければ何もしない。
  void drainPendingNavigation() {
    final route = _pendingNavigation;
    if (route == null) return;
    final args = _pendingNavigationArgs;
    _pendingNavigation = null;
    _pendingNavigationArgs = null;
    // postFrameCallback: ウィジェットツリー構築後に遷移する
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appNavigatorKey.currentState?.pushNamed(route, arguments: args);
    });
  }

  /// 通知データからルート文字列を決定する（引数不要なルート用）。
  ///
  /// type: 'like' | 'comment' → '/feed'（フィード画面でレスポンスを確認）
  /// type: 'follow'           → '/profile'（自分のプロフィールで通知確認）
  /// type: 'checkin_badge'    → '/badges'（バッジ獲得画面に遷移）
  /// type: 'facility'         → null（引数が必要なため _handleNavigation で個別処理）
  /// 未知の type              → null（遷移しない）
  String? _routeForData(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    switch (type) {
      case 'like':
      case 'comment':
        return '/feed';
      case 'follow':
        return '/profile';
      case 'checkin_badge':
        return '/badges';
      default:
        if (type != 'facility') {
          debugPrint('Notification: unknown type=$type');
        }
        return null;
    }
  }

  /// 通知データを保留キューに積む（cold start 用）。
  void _storePendingNavigation(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    if (type == 'facility') {
      final facilityId = data['target_id'] as String?;
      if (facilityId != null && facilityId.isNotEmpty) {
        _pendingNavigation = '/facility';
        _pendingNavigationArgs = facilityId;
      }
    } else {
      _pendingNavigation = _routeForData(data);
      _pendingNavigationArgs = null;
    }
  }

  /// 通知タイプに応じた画面遷移。
  ///
  /// appNavigatorKey 経由で Navigator を操作するため Context 不要。
  /// Navigator がまだ存在しない場合（極めて短時間）は保留キューに積む。
  void _handleNavigation(Map<String, dynamic> data) {
    final type = data['type'] as String?;

    // 施設詳細は引数（施設ID）付きの onGenerateRoute ルートのため個別処理
    if (type == 'facility') {
      final facilityId = data['target_id'] as String?;
      if (facilityId == null || facilityId.isEmpty) return;

      final navigator = appNavigatorKey.currentState;
      if (navigator == null) {
        _pendingNavigation = '/facility';
        _pendingNavigationArgs = facilityId;
        return;
      }
      navigator.pushNamed('/facility', arguments: facilityId);
      return;
    }

    final route = _routeForData(data);
    if (route == null) return;

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      // Navigator がまだ起動していない場合は保留キューに積む
      _pendingNavigation = route;
      _pendingNavigationArgs = null;
      return;
    }
    navigator.pushNamed(route);
  }

  String _encodePayload(Map<String, dynamic> data) =>
      data.entries.map((e) => '${e.key}=${e.value}').join('&');

  Map<String, dynamic> _decodePayload(String payload) =>
      Map.fromEntries(payload.split('&').map((e) {
        final parts = e.split('=');
        return MapEntry(parts[0], parts.length > 1 ? parts[1] : '');
      }));
}
