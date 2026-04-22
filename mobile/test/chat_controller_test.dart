import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:production_chat_app/features/chat/application/chat_controller.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_history_page.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_message.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_sync_result.dart';
import 'package:production_chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:production_chat_app/features/conversation/domain/entities/conversation_summary.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime_event.dart';

void main() {
  test('chat controller backfills missing messages only once after reconnect', () async {
    final repository = _FakeChatRepository();
    final realtime = _FakeChatRealtime();
    final controller = ChatController(
      chatRepository: repository,
      chatRealtime: realtime,
      accessToken: 'access-token',
      currentUserId: 'alice',
    );

    final conversation = ConversationSummary(
      id: 'conversation-1',
      type: 'direct',
      title: 'Bob',
      memberCount: 2,
      lastMessagePreview: 'hi',
      latestSequence: 1,
      unreadCount: 0,
      updatedAt: DateTime(2026, 1, 1, 10),
      lastMessageAt: DateTime(2026, 1, 1, 10),
    );

    await controller.openConversation(conversation);

    realtime.connectionReadyController.add(
      const ChatConnectionReadyEvent(
        connectionId: 'socket-1',
        recovered: true,
        activeConnectionCount: 1,
        conversationLatestSequenceById: {'conversation-1': 3},
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(repository.syncAfterCalls, 1);
    expect(controller.messages.map((item) => item.sequence), [1, 2, 3]);

    realtime.connectionReadyController.add(
      const ChatConnectionReadyEvent(
        connectionId: 'socket-1',
        recovered: true,
        activeConnectionCount: 1,
        conversationLatestSequenceById: {'conversation-1': 3},
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(repository.syncAfterCalls, 1);

    controller.dispose();
    await realtime.dispose();
  });
}

class _FakeChatRepository implements ChatRepository {
  int syncAfterCalls = 0;

  @override
  Future<ChatHistoryPage> fetchHistory({
    required String accessToken,
    required String conversationId,
    required String currentUserId,
    int? beforeSequence,
    int limit = 20,
  }) async {
    return ChatHistoryPage(
      messages: [
        _buildTextMessage(
          clientMessageId: 'history-1',
          conversationId: conversationId,
          senderId: 'bob',
          senderName: 'Bob',
          sequence: 1,
          text: '第一条',
        ),
      ],
      latestSequence: 1,
      peerReadSequenceByUserId: const {},
      memberDisplayNameByUserId: const {},
      memberHandleByUserId: const {},
      memberAvatarUrlByUserId: const {},
      peerReadUpdatedAtByUserId: const {},
      nextBeforeSequence: null,
    );
  }

  @override
  Future<ChatSyncResult> syncAfter({
    required String accessToken,
    required String conversationId,
    required int afterSequence,
    int limit = 100,
  }) async {
    syncAfterCalls += 1;

    return ChatSyncResult(
      messages: [
        _buildTextMessage(
          clientMessageId: 'sync-2',
          conversationId: conversationId,
          senderId: 'bob',
          senderName: 'Bob',
          sequence: 2,
          text: '第二条',
        ),
        _buildTextMessage(
          clientMessageId: 'sync-3',
          conversationId: conversationId,
          senderId: 'alice',
          senderName: 'Alice',
          sequence: 3,
          text: '第三条',
        ),
      ],
      latestSequence: 3,
      nextAfterSequence: 3,
      hasMore: false,
    );
  }

  @override
  Future<ChatMessage> sendText({
    required String accessToken,
    required String conversationId,
    required String clientMessageId,
    required String text,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> updateReadCursor({
    required String accessToken,
    required String conversationId,
    required int lastReadSequence,
  }) async {}
}

class _FakeChatRealtime implements ChatRealtime {
  final StreamController<ChatRealtimeConnectionState> connectionStateController =
      StreamController<ChatRealtimeConnectionState>.broadcast();
  final StreamController<ChatConnectionReadyEvent> connectionReadyController =
      StreamController<ChatConnectionReadyEvent>.broadcast();
  final StreamController<ChatConversationCreatedEvent>
  conversationCreatedController =
      StreamController<ChatConversationCreatedEvent>.broadcast();
  final StreamController<ChatMessage> messageCreatedController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<ChatReadCursorUpdatedEvent>
  readCursorUpdatedController =
      StreamController<ChatReadCursorUpdatedEvent>.broadcast();
  final StreamController<ChatTypingUpdatedEvent> typingUpdatedController =
      StreamController<ChatTypingUpdatedEvent>.broadcast();
  final StreamController<ChatSessionRevokedEvent> sessionRevokedController =
      StreamController<ChatSessionRevokedEvent>.broadcast();
  final StreamController<String> connectionErrorController =
      StreamController<String>.broadcast();

  @override
  Stream<ChatRealtimeConnectionState> get connectionStateStream =>
      connectionStateController.stream;

  @override
  Stream<ChatConnectionReadyEvent> get connectionReadyStream =>
      connectionReadyController.stream;

  @override
  Stream<ChatConversationCreatedEvent> get conversationCreatedStream =>
      conversationCreatedController.stream;

  @override
  Stream<ChatMessage> get messageCreatedStream => messageCreatedController.stream;

  @override
  Stream<ChatReadCursorUpdatedEvent> get readCursorUpdatedStream =>
      readCursorUpdatedController.stream;

  @override
  Stream<ChatTypingUpdatedEvent> get typingUpdatedStream =>
      typingUpdatedController.stream;

  @override
  Stream<ChatSessionRevokedEvent> get sessionRevokedStream =>
      sessionRevokedController.stream;

  @override
  Stream<String> get connectionErrorStream => connectionErrorController.stream;

  @override
  bool get isConnected => false;

  @override
  void connect({required String accessToken}) {}

  @override
  void disconnect() {}

  @override
  void emitTyping({required String conversationId, required bool isTyping}) {}

  Future<void> dispose() async {
    await Future.wait([
      connectionStateController.close(),
      connectionReadyController.close(),
      conversationCreatedController.close(),
      messageCreatedController.close(),
      readCursorUpdatedController.close(),
      typingUpdatedController.close(),
      sessionRevokedController.close(),
      connectionErrorController.close(),
    ]);
  }
}

ChatMessage _buildTextMessage({
  required String clientMessageId,
  required String conversationId,
  required String senderId,
  required String senderName,
  required int sequence,
  required String text,
}) {
  return ChatMessage(
    clientMessageId: clientMessageId,
    conversationId: conversationId,
    senderId: senderId,
    senderName: senderName,
    messageKind: ChatMessageKind.text,
    content: ChatTextMessageContent(text: text),
    deliveryState: ChatMessageDeliveryState.sent,
    sequence: sequence,
    createdAt: DateTime(2026, 1, 1, 10, sequence),
    updatedAt: DateTime(2026, 1, 1, 10, sequence),
  );
}
