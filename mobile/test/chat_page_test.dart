import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_history_page.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_message.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_sync_result.dart';
import 'package:production_chat_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:production_chat_app/features/chat/presentation/pages/chat_page.dart';
import 'package:production_chat_app/features/conversation/domain/entities/conversation_summary.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime_event.dart';

void main() {
  testWidgets(
    'chat page opens at latest message and hides older items offscreen',
    (tester) async {
      final repository = _FakeChatRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 640,
              child: ChatPage(
                accessToken: 'access-token',
                currentUserId: 'user-1',
                chatRepository: repository,
                chatRealtime: _FakeChatRealtime(),
                onBackToConversationList: () {},
                onConversationChanged: () {},
                onOpenDirectConversation: (_) async {},
                reloadToken: 0,
                selectedConversation: _conversation,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('message 40'), findsOneWidget);
      expect(find.text('message 1'), findsNothing);
    },
  );

  testWidgets(
    'chat page composer grows and sending scrolls back to latest message',
    (tester) async {
      final repository = _FakeChatRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 640,
              child: ChatPage(
                accessToken: 'access-token',
                currentUserId: 'user-1',
                chatRepository: repository,
                chatRealtime: _FakeChatRealtime(),
                onBackToConversationList: () {},
                onConversationChanged: () {},
                onOpenDirectConversation: (_) async {},
                reloadToken: 0,
                selectedConversation: _conversation,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final composerFinder = find.byType(TextField).last;
      final composerBefore = tester.widget<TextField>(composerFinder);
      expect(composerBefore.maxLines, 11);
      expect(composerBefore.textAlignVertical, TextAlignVertical.center);

      final initialHeight = tester.getSize(composerFinder).height;
      await tester.enterText(
        composerFinder,
        List.filled(40, '这是一段会自动换行的长消息').join(),
      );
      await tester.pumpAndSettle();

      final expandedHeight = tester.getSize(composerFinder).height;
      expect(expandedHeight, greaterThan(initialHeight));

      for (var index = 0; index < 5; index += 1) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
        await tester.pumpAndSettle();
      }
      expect(find.text('message 1'), findsOneWidget);

      await tester.enterText(composerFinder, 'brand new outgoing message');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      expect(find.text('brand new outgoing message'), findsOneWidget);
      expect(find.text('message 1'), findsNothing);
    },
  );

  testWidgets(
    'chat page replaces local sending state with failed reason from server',
    (tester) async {
      final repository = _FakeChatRepositoryWithFailedSend();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 640,
              child: ChatPage(
                accessToken: 'access-token',
                currentUserId: 'user-1',
                chatRepository: repository,
                chatRealtime: _FakeChatRealtime(),
                onBackToConversationList: () {},
                onConversationChanged: () {},
                onOpenDirectConversation: (_) async {},
                reloadToken: 0,
                selectedConversation: _conversation,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final composerFinder = find.byType(TextField).last;
      await tester.enterText(composerFinder, 'blocked message');
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pumpAndSettle();

      expect(find.text('需先加好友'), findsOneWidget);
      expect(find.text('发送中'), findsNothing);
    },
  );

  testWidgets('chat page does not show read receipt for failed messages', (
    tester,
  ) async {
    final repository = _FakeChatRepositoryWithFailedHistory();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 640,
            child: ChatPage(
              accessToken: 'access-token',
              currentUserId: 'user-1',
              chatRepository: repository,
              chatRealtime: _FakeChatRealtime(),
              onBackToConversationList: () {},
              onConversationChanged: () {},
              onOpenDirectConversation: (_) async {},
              reloadToken: 0,
              selectedConversation: _conversation,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('需先加好友'), findsOneWidget);
    expect(find.text('已读'), findsNothing);
  });
}

final ConversationSummary _conversation = ConversationSummary(
  id: 'conversation-1',
  type: 'direct',
  title: 'Chat Peer',
  memberCount: 2,
  lastMessagePreview: 'message 40',
  latestSequence: 40,
  unreadCount: 0,
  updatedAt: DateTime(2026, 1, 1, 12, 0),
  lastMessageAt: DateTime(2026, 1, 1, 12, 0),
);

class _FakeChatRepository implements ChatRepository {
  int _latestSequence = 40;

  @override
  Future<ChatHistoryPage> fetchHistory({
    required String accessToken,
    required String conversationId,
    required String currentUserId,
    int? beforeSequence,
    int limit = 20,
  }) async {
    return ChatHistoryPage(
      messages: List.generate(40, (index) {
        final sequence = index + 1;
        final isMine = sequence.isEven;

        return ChatMessage(
          clientMessageId: 'message-$sequence',
          conversationId: conversationId,
          senderId: isMine ? 'user-1' : 'user-2',
          senderName: isMine ? 'Me' : 'Peer',
          messageKind: ChatMessageKind.text,
          content: ChatTextMessageContent(text: 'message $sequence'),
          deliveryState: ChatMessageDeliveryState.sent,
          sequence: sequence,
          createdAt: DateTime(2026, 1, 1, 12, sequence),
          updatedAt: DateTime(2026, 1, 1, 12, sequence),
        );
      }),
      latestSequence: 40,
      peerReadSequenceByUserId: const {'user-2': 40},
      memberDisplayNameByUserId: const {'user-1': 'Me', 'user-2': 'Peer'},
      memberHandleByUserId: const {'user-1': 'me', 'user-2': 'peer'},
      memberAvatarUrlByUserId: const {'user-1': null, 'user-2': null},
      peerReadUpdatedAtByUserId: {'user-2': DateTime(2026, 1, 1, 12, 40)},
      nextBeforeSequence: 20,
    );
  }

  @override
  Future<ChatMessage> sendText({
    required String accessToken,
    required String conversationId,
    required String clientMessageId,
    required String text,
  }) async {
    _latestSequence += 1;

    return ChatMessage(
      clientMessageId: clientMessageId,
      conversationId: conversationId,
      senderId: 'user-1',
      senderName: 'Me',
      messageKind: ChatMessageKind.text,
      content: ChatTextMessageContent(text: text),
      deliveryState: ChatMessageDeliveryState.sent,
      sequence: _latestSequence,
      createdAt: DateTime(2026, 1, 1, 13, _latestSequence - 40),
      updatedAt: DateTime(2026, 1, 1, 13, _latestSequence - 40),
    );
  }

  @override
  Future<ChatSyncResult> syncAfter({
    required String accessToken,
    required String conversationId,
    required int afterSequence,
    int limit = 100,
  }) async {
    return ChatSyncResult(
      messages: const [],
      latestSequence: _latestSequence,
      nextAfterSequence: _latestSequence,
      hasMore: false,
    );
  }

  @override
  Future<void> updateReadCursor({
    required String accessToken,
    required String conversationId,
    required int lastReadSequence,
  }) async {}
}

class _FakeChatRepositoryWithFailedSend extends _FakeChatRepository {
  @override
  Future<ChatMessage> sendText({
    required String accessToken,
    required String conversationId,
    required String clientMessageId,
    required String text,
  }) async {
    return ChatMessage(
      clientMessageId: clientMessageId,
      conversationId: conversationId,
      senderId: 'user-1',
      senderName: 'Me',
      messageKind: ChatMessageKind.text,
      content: ChatTextMessageContent(text: text),
      deliveryState: ChatMessageDeliveryState.failed,
      sequence: 41,
      createdAt: DateTime(2026, 1, 1, 13, 1),
      updatedAt: DateTime(2026, 1, 1, 13, 1),
      serverMessageId: 'failed-message-1',
      failureReason: '需先加好友',
    );
  }
}

class _FakeChatRepositoryWithFailedHistory extends _FakeChatRepository {
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
        ChatMessage(
          clientMessageId: 'failed-history-1',
          conversationId: conversationId,
          senderId: 'user-1',
          senderName: 'Me',
          messageKind: ChatMessageKind.text,
          content: const ChatTextMessageContent(text: 'blocked message'),
          deliveryState: ChatMessageDeliveryState.failed,
          sequence: 41,
          createdAt: DateTime(2026, 1, 1, 13, 1),
          updatedAt: DateTime(2026, 1, 1, 13, 1),
          serverMessageId: 'failed-history-server-1',
          failureReason: '需先加好友',
        ),
      ],
      latestSequence: 41,
      peerReadSequenceByUserId: const {'user-2': 999},
      memberDisplayNameByUserId: const {'user-1': 'Me', 'user-2': 'Peer'},
      memberHandleByUserId: const {'user-1': 'me', 'user-2': 'peer'},
      memberAvatarUrlByUserId: const {'user-1': null, 'user-2': null},
      peerReadUpdatedAtByUserId: {'user-2': DateTime(2026, 1, 1, 13, 2)},
      nextBeforeSequence: null,
    );
  }
}

class _FakeChatRealtime implements ChatRealtime {
  @override
  final Stream<ChatRealtimeConnectionState> connectionStateStream =
      const Stream<ChatRealtimeConnectionState>.empty();

  @override
  final Stream<ChatConnectionReadyEvent> connectionReadyStream =
      const Stream<ChatConnectionReadyEvent>.empty();

  @override
  final Stream<String> connectionErrorStream = const Stream<String>.empty();

  @override
  final Stream<ChatConversationCreatedEvent> conversationCreatedStream =
      const Stream<ChatConversationCreatedEvent>.empty();

  @override
  final Stream<ChatMessage> messageCreatedStream =
      const Stream<ChatMessage>.empty();

  @override
  final Stream<ChatReadCursorUpdatedEvent> readCursorUpdatedStream =
      const Stream<ChatReadCursorUpdatedEvent>.empty();

  @override
  final Stream<ChatSessionRevokedEvent> sessionRevokedStream =
      const Stream<ChatSessionRevokedEvent>.empty();

  @override
  final Stream<ChatTypingUpdatedEvent> typingUpdatedStream =
      const Stream<ChatTypingUpdatedEvent>.empty();

  @override
  bool get isConnected => false;

  @override
  void connect({required String accessToken}) {}

  @override
  void disconnect() {}

  @override
  void emitTyping({required String conversationId, required bool isTyping}) {}
}
