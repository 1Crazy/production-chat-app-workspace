import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_chat_app/shared/notifications/push_notification_service.dart';

void main() {
  test('push intent parses notification payload and conversation target', () {
    final intent = PushNotificationIntent.fromRemoteMessage(
      const RemoteMessage(
        messageId: 'message-1',
        data: {'conversationId': 'conversation-123', 'messagePreview': '你好'},
        notification: RemoteNotification(title: 'Alice', body: '你好'),
      ),
    );

    expect(intent.messageId, 'message-1');
    expect(intent.title, 'Alice');
    expect(intent.body, '你好');
    expect(intent.conversationId, 'conversation-123');
    expect(intent.hasConversationTarget, isTrue);
    expect(intent.badgeCount, isNull);
    expect(intent.latestSequence, isNull);
  });

  test('push intent falls back to compatible data keys', () {
    final intent = PushNotificationIntent.fromRemoteMessage(
      const RemoteMessage(
        data: {
          'conversation_id': 'conversation-456',
          'senderName': 'Bob',
          'preview': '新的文件消息',
        },
      ),
    );

    expect(intent.title, 'Bob');
    expect(intent.body, '新的文件消息');
    expect(intent.conversationId, 'conversation-456');
    expect(intent.hasConversationTarget, isTrue);
  });

  test('push intent extracts conversation target from route-like payload', () {
    final intent = PushNotificationIntent.fromRemoteMessage(
      const RemoteMessage(
        data: {
          'route': '/conversations/conversation-789',
          'title': 'Carol',
          'body': '点击查看新消息',
        },
      ),
    );

    expect(intent.title, 'Carol');
    expect(intent.body, '点击查看新消息');
    expect(intent.conversationId, 'conversation-789');
    expect(intent.hasConversationTarget, isTrue);
  });

  test('push intent extracts conversation target from deep link query', () {
    final intent = PushNotificationIntent.fromRemoteMessage(
      const RemoteMessage(
        data: {
          'deepLink':
              'production-chat://chat/open?conversationId=conversation-999',
        },
      ),
    );

    expect(intent.conversationId, 'conversation-999');
    expect(intent.hasConversationTarget, isTrue);
  });

  test('push intent parses badge count and latest sequence from sync payload', () {
    final intent = PushNotificationIntent.fromRemoteMessage(
      const RemoteMessage(
        messageId: 'message-2',
        data: {
          'conversationId': 'conversation-123',
          'badgeCount': '7',
          'sequence': '42',
        },
      ),
    );

    expect(intent.badgeCount, 7);
    expect(intent.latestSequence, 42);
  });
}
