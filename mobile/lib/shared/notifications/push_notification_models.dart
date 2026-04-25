part of 'push_notification_service.dart';

class PushNotificationIntent {
  const PushNotificationIntent({
    required this.messageId,
    required this.title,
    required this.body,
    required this.conversationId,
    required this.badgeCount,
    required this.latestSequence,
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
      badgeCount: _parseInt(data['badgeCount']),
      latestSequence: _parseInt(data['sequence']),
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
      badgeCount: decoded['badgeCount'] as int?,
      latestSequence: decoded['latestSequence'] as int?,
    );
  }

  final String? messageId;
  final String? title;
  final String? body;
  final String? conversationId;
  final int? badgeCount;
  final int? latestSequence;

  bool get hasConversationTarget {
    return conversationId != null && conversationId!.isNotEmpty;
  }

  String toNotificationPayload() {
    return jsonEncode({
      'messageId': messageId,
      'title': title,
      'body': body,
      'conversationId': conversationId,
      'badgeCount': badgeCount,
      'latestSequence': latestSequence,
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

class NoopPushNotificationService implements PushNotificationService {
  const NoopPushNotificationService();

  @override
  Stream<PushNotificationForegroundEvent> get foregroundMessageStream {
    return const Stream<PushNotificationForegroundEvent>.empty();
  }

  @override
  Stream<PushNotificationIntent> get notificationTapStream {
    return const Stream<PushNotificationIntent>.empty();
  }

  @override
  Future<void> initialize() async {}

  @override
  PushNotificationIntent? takeInitialNotificationIntent() {
    return null;
  }

  @override
  void dispose() {}
}
