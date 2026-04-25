import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';

part 'push_notification_models.dart';
part 'push_notification_payload_parser.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
  } catch (_) {
    // 后台消息到达时如果本地还没有 Firebase 配置，直接忽略即可，
    // 不让 isolate 因初始化失败崩掉。
  }
}

abstract class PushNotificationService {
  Future<void> initialize();

  Stream<PushNotificationForegroundEvent> get foregroundMessageStream;

  Stream<PushNotificationIntent> get notificationTapStream;

  PushNotificationIntent? takeInitialNotificationIntent();

  void dispose();
}

class FirebasePushNotificationService implements PushNotificationService {
  FirebasePushNotificationService({FirebaseMessaging? messaging})
    : _messaging = messaging ?? FirebaseMessaging.instance;

  static const AndroidNotificationChannel _foregroundChannel =
      AndroidNotificationChannel(
        'chat_foreground_messages',
        'Chat Foreground Messages',
        description: 'Foreground chat message alerts',
        importance: Importance.high,
      );
  static const MethodChannel _iosNotificationMethodChannel = MethodChannel(
    'production_chat_app/notifications_ios',
  );
  static const EventChannel _iosNotificationEventsChannel = EventChannel(
    'production_chat_app/notifications_ios_events',
  );

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final StreamController<PushNotificationForegroundEvent>
  _foregroundMessageController =
      StreamController<PushNotificationForegroundEvent>.broadcast();
  final StreamController<PushNotificationIntent> _notificationTapController =
      StreamController<PushNotificationIntent>.broadcast();

  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;
  StreamSubscription<RemoteMessage>? _notificationTapSubscription;
  StreamSubscription<dynamic>? _iosNotificationEventSubscription;
  PushNotificationIntent? _initialNotificationIntent;
  bool _isInitialized = false;

  @override
  Stream<PushNotificationForegroundEvent> get foregroundMessageStream {
    return _foregroundMessageController.stream;
  }

  @override
  Stream<PushNotificationIntent> get notificationTapStream {
    return _notificationTapController.stream;
  }

  @override
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    _isInitialized = true;

    await _initializeLocalNotifications();

    if (Platform.isIOS) {
      await _initializeIosNativeNotifications();
      return;
    }

    if (!_supportsFirebaseMessagingPlatform || Firebase.apps.isEmpty) {
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen((
      message,
    ) {
      final intent = PushNotificationIntent.fromRemoteMessage(message);
      unawaited(_showForegroundSystemNotification(intent));
      _foregroundMessageController.add(
        PushNotificationForegroundEvent(
          intent: intent,
          receivedAt: DateTime.now(),
        ),
      );
    });

    _notificationTapSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      _notificationTapController.add(
        PushNotificationIntent.fromRemoteMessage(message),
      );
    });

    final initialMessage = await _messaging.getInitialMessage();

    if (initialMessage != null) {
      _initialNotificationIntent = PushNotificationIntent.fromRemoteMessage(
        initialMessage,
      );
    }

    final launchDetails = await _localNotificationsPlugin
        .getNotificationAppLaunchDetails();
    final launchPayload = launchDetails?.notificationResponse?.payload;

    if (launchDetails?.didNotificationLaunchApp == true &&
        launchPayload != null &&
        launchPayload.isNotEmpty) {
      _initialNotificationIntent =
          PushNotificationIntent.fromNotificationPayload(launchPayload);
    }
  }

  @override
  PushNotificationIntent? takeInitialNotificationIntent() {
    final intent = _initialNotificationIntent;
    _initialNotificationIntent = null;
    return intent;
  }

  @override
  void dispose() {
    _foregroundMessageSubscription?.cancel();
    _notificationTapSubscription?.cancel();
    _iosNotificationEventSubscription?.cancel();
    _foregroundMessageController.close();
    _notificationTapController.close();
  }

  bool get _supportsFirebaseMessagingPlatform {
    return !kIsWeb && Platform.isAndroid;
  }

  Future<void> _initializeLocalNotifications() async {
    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _handleLocalNotificationResponse,
    );

    if (Platform.isAndroid) {
      final androidPlugin = _localNotificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.createNotificationChannel(_foregroundChannel);
    }
  }

  Future<void> _initializeIosNativeNotifications() async {
    _iosNotificationEventSubscription = _iosNotificationEventsChannel
        .receiveBroadcastStream()
        .listen((event) {
          final eventMap = _asMap(event);
          final payload = eventMap['payload'];

          if (payload is! String || payload.isEmpty) {
            return;
          }

          final intent = PushNotificationIntent.fromNotificationPayload(
            payload,
          );
          final type = eventMap['type']?.toString();

          if (type == 'foreground') {
            _foregroundMessageController.add(
              PushNotificationForegroundEvent(
                intent: intent,
                receivedAt: DateTime.now(),
              ),
            );
            return;
          }

          if (type == 'opened') {
            _notificationTapController.add(intent);
          }
        });

    final initialPayload = await _iosNotificationMethodChannel
        .invokeMethod<String>('getInitialNotificationPayload');

    if (initialPayload != null && initialPayload.isNotEmpty) {
      _initialNotificationIntent =
          PushNotificationIntent.fromNotificationPayload(initialPayload);
    }
  }

  void _handleLocalNotificationResponse(NotificationResponse response) {
    final payload = response.payload;

    if (payload == null || payload.isEmpty) {
      return;
    }

    _notificationTapController.add(
      PushNotificationIntent.fromNotificationPayload(payload),
    );
  }

  Future<void> _showForegroundSystemNotification(
    PushNotificationIntent intent,
  ) async {
    if (!Platform.isAndroid) {
      return;
    }

    final title = intent.title ?? '收到新消息';
    final body = intent.body ?? '点击查看最新会话动态';
    final notificationDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        _foregroundChannel.id,
        _foregroundChannel.name,
        channelDescription: _foregroundChannel.description,
        icon: 'ic_notification',
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.message,
        number: intent.badgeCount,
      ),
      iOS: DarwinNotificationDetails(
        presentBadge: true,
        badgeNumber: intent.badgeCount,
      ),
    );

    await _localNotificationsPlugin.show(
      id: _notificationIdFor(intent),
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: intent.toNotificationPayload(),
    );
  }

  int _notificationIdFor(PushNotificationIntent intent) {
    final source =
        intent.messageId ??
        intent.conversationId ??
        DateTime.now().millisecondsSinceEpoch.toString();
    return source.hashCode & 0x7fffffff;
  }

  Map<String, dynamic> _asMap(dynamic payload) {
    if (payload is Map<String, dynamic>) {
      return payload;
    }

    if (payload is Map) {
      return payload.map((key, value) {
        return MapEntry(key.toString(), value);
      });
    }

    throw StateError('native notification payload must be a map');
  }
}
