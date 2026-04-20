import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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

class PushNotificationIntent {
  const PushNotificationIntent({
    required this.messageId,
    required this.title,
    required this.body,
    required this.conversationId,
  });

  factory PushNotificationIntent.fromRemoteMessage(RemoteMessage message) {
    final data = message.data;

    return PushNotificationIntent(
      messageId: message.messageId,
      title:
          message.notification?.title ??
          _firstNonEmptyString(data, const ['title', 'senderName']),
      body:
          message.notification?.body ??
          _firstNonEmptyString(data, const [
            'body',
            'messagePreview',
            'preview',
          ]),
      conversationId: _extractConversationId(data),
    );
  }

  factory PushNotificationIntent.fromNotificationPayload(String payload) {
    final decoded = jsonDecode(payload);

    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('notification payload must be a json object');
    }

    return PushNotificationIntent(
      messageId: decoded['messageId'] as String?,
      title: decoded['title'] as String?,
      body: decoded['body'] as String?,
      conversationId: decoded['conversationId'] as String?,
    );
  }

  final String? messageId;
  final String? title;
  final String? body;
  final String? conversationId;

  bool get hasConversationTarget {
    return conversationId != null && conversationId!.isNotEmpty;
  }

  String toNotificationPayload() {
    return jsonEncode({
      'messageId': messageId,
      'title': title,
      'body': body,
      'conversationId': conversationId,
    });
  }
}

class PushNotificationForegroundEvent {
  const PushNotificationForegroundEvent({
    required this.intent,
    required this.receivedAt,
  });

  final PushNotificationIntent intent;
  final DateTime receivedAt;
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

    if (!_supportsFirebaseMessagingPlatform || Firebase.apps.isEmpty) {
      return;
    }

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _initializeLocalNotifications();

    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

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
    _foregroundMessageController.close();
    _notificationTapController.close();
  }

  bool get _supportsFirebaseMessagingPlatform {
    return !kIsWeb && (Platform.isIOS || Platform.isAndroid);
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
}

String? _firstNonEmptyString(
  Map<String, dynamic> data,
  List<String> candidates,
) {
  for (final key in candidates) {
    final rawValue = data[key];

    if (rawValue is String && rawValue.trim().isNotEmpty) {
      return rawValue.trim();
    }
  }

  return null;
}

String? _extractConversationId(Map<String, dynamic> data) {
  final directValue = _firstNonEmptyString(data, const [
    'conversationId',
    'conversation_id',
    'chatConversationId',
    'targetConversationId',
  ]);

  if (directValue != null) {
    return directValue;
  }

  final routeLikeValue = _firstNonEmptyString(data, const [
    'route',
    'deepLink',
    'deeplink',
    'link',
  ]);

  if (routeLikeValue == null) {
    return null;
  }

  final uri = Uri.tryParse(routeLikeValue);

  if (uri == null) {
    return _extractConversationIdFromPath(routeLikeValue);
  }

  final queryConversationId = uri.queryParameters['conversationId'];

  if (queryConversationId != null && queryConversationId.trim().isNotEmpty) {
    return queryConversationId.trim();
  }

  return _extractConversationIdFromPath(uri.path);
}

String? _extractConversationIdFromPath(String path) {
  final normalizedPath = path.trim();

  if (normalizedPath.isEmpty) {
    return null;
  }

  final segments = normalizedPath
      .split('/')
      .where((segment) => segment.trim().isNotEmpty)
      .toList(growable: false);

  for (var index = 0; index < segments.length - 1; index += 1) {
    if (segments[index] == 'conversations') {
      return segments[index + 1];
    }
  }

  return null;
}
