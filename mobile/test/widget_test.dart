import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_message.dart';
import 'package:production_chat_app/features/chat/presentation/widgets/chat_message_bubble.dart';
import 'package:production_chat_app/features/conversation/domain/entities/conversation_summary.dart';
import 'package:production_chat_app/features/conversation/domain/repositories/conversation_repository.dart';
import 'package:production_chat_app/features/conversation/presentation/pages/conversation_list_page.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime.dart';
import 'package:production_chat_app/shared/realtime/chat_realtime_event.dart';

void main() {
  testWidgets('conversation list renders remote conversations', (tester) async {
    ConversationSummary? selectedConversation;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConversationListPage(
            accessToken: 'access-token',
            conversationRepository: _FakeConversationRepository(),
            chatRealtime: _FakeChatRealtime(),
            currentUserId: 'current-user-id',
            selectedConversationId: null,
            isVisible: true,
            reloadToken: 0,
            onConversationSelected: (conversation) {
              selectedConversation = conversation;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Demo User'), findsOneWidget);
    expect(find.text('你好'), findsOneWidget);

    await tester.tap(find.text('Demo User'));

    expect(selectedConversation?.id, 'conversation-id');
  });

  testWidgets('chat message bubble renders media cards', (tester) async {
    Future<void> pumpMessage(ChatMessage message) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatMessageBubble(message: message, isMine: false),
          ),
        ),
      );
    }

    await pumpMessage(
      ChatMessage(
        clientMessageId: 'image-1',
        conversationId: 'conversation-id',
        senderId: 'peer-id',
        senderName: 'Peer',
        messageKind: ChatMessageKind.image,
        content: const ChatMediaMessageContent(
          attachmentId: 'attachment-image',
          attachmentKind: ChatMessageKind.image,
          attachmentStatus: ChatMediaAttachmentStatus.processing,
          fileName: 'photo.png',
          mimeType: 'image/png',
          sizeBytes: 2048,
        ),
        deliveryState: ChatMessageDeliveryState.sent,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

    expect(find.text('photo.png'), findsWidgets);
    expect(find.text('处理中'), findsOneWidget);
    expect(find.text('附件处理中，稍后可用'), findsOneWidget);

    await pumpMessage(
      ChatMessage(
        clientMessageId: 'audio-1',
        conversationId: 'conversation-id',
        senderId: 'peer-id',
        senderName: 'Peer',
        messageKind: ChatMessageKind.audio,
        content: const ChatMediaMessageContent(
          attachmentId: 'attachment-audio',
          attachmentKind: ChatMessageKind.audio,
          attachmentStatus: ChatMediaAttachmentStatus.ready,
          fileName: 'voice.m4a',
          mimeType: 'audio/mp4',
          sizeBytes: 4096,
        ),
        deliveryState: ChatMessageDeliveryState.sent,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

    expect(find.text('voice.m4a'), findsOneWidget);
    expect(find.text('可用'), findsOneWidget);
    expect(find.text('附件已处理完成'), findsOneWidget);

    await pumpMessage(
      ChatMessage(
        clientMessageId: 'file-1',
        conversationId: 'conversation-id',
        senderId: 'peer-id',
        senderName: 'Peer',
        messageKind: ChatMessageKind.file,
        content: const ChatMediaMessageContent(
          attachmentId: 'attachment-file',
          attachmentKind: ChatMessageKind.file,
          attachmentStatus: ChatMediaAttachmentStatus.ready,
          fileName: 'report.pdf',
          mimeType: 'application/pdf',
          sizeBytes: 8192,
        ),
        deliveryState: ChatMessageDeliveryState.sent,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

    expect(find.text('report.pdf'), findsOneWidget);
    expect(find.textContaining('application/pdf'), findsOneWidget);

    await pumpMessage(
      ChatMessage(
        clientMessageId: 'file-2',
        conversationId: 'conversation-id',
        senderId: 'peer-id',
        senderName: 'Peer',
        messageKind: ChatMessageKind.file,
        content: const ChatMediaMessageContent(
          attachmentId: 'attachment-file-failed',
          attachmentKind: ChatMessageKind.file,
          attachmentStatus: ChatMediaAttachmentStatus.failed,
          fileName: 'broken.zip',
          mimeType: 'application/zip',
          sizeBytes: 5120,
        ),
        deliveryState: ChatMessageDeliveryState.sent,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );

    expect(find.text('处理失败'), findsOneWidget);
    expect(find.text('附件处理失败，请稍后重试'), findsOneWidget);
  });
}

class _FakeConversationRepository implements ConversationRepository {
  @override
  Future<List<ConversationSummary>> fetchRecent({
    required String accessToken,
  }) async {
    return [
      ConversationSummary(
        id: 'conversation-id',
        type: 'direct',
        title: 'Demo User',
        memberCount: 2,
        lastMessagePreview: '你好',
        latestSequence: 1,
        unreadCount: 2,
        updatedAt: DateTime(2026, 1, 1),
        lastMessageAt: DateTime(2026, 1, 1),
      ),
    ];
  }

  @override
  Future<ConversationSummary?> findById({
    required String accessToken,
    required String conversationId,
  }) async {
    final conversations = await fetchRecent(accessToken: accessToken);

    for (final conversation in conversations) {
      if (conversation.id == conversationId) {
        return conversation;
      }
    }

    return null;
  }

  @override
  Future<String> createOrReuseDirectConversation({
    required String accessToken,
    required String targetHandle,
  }) async {
    return 'conversation-id';
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
