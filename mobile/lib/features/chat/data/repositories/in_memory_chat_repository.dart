import 'package:production_chat_app/features/chat/domain/entities/chat_message.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_history_page.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_sync_result.dart';
import 'package:production_chat_app/features/chat/domain/repositories/chat_repository.dart';

class InMemoryChatRepository implements ChatRepository {
  @override
  Future<ChatHistoryPage> fetchHistory({
    required String accessToken,
    required String conversationId,
    required String currentUserId,
    int? beforeSequence,
    int limit = 20,
  }) async {
    return const ChatHistoryPage(
      messages: <ChatMessage>[],
      latestSequence: 0,
      peerReadSequenceByUserId: <String, int>{},
      memberDisplayNameByUserId: <String, String>{},
      memberHandleByUserId: <String, String>{},
      memberAvatarUrlByUserId: <String, String?>{},
      peerReadUpdatedAtByUserId: <String, DateTime>{},
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
    return const ChatSyncResult(
      messages: <ChatMessage>[],
      latestSequence: 0,
      nextAfterSequence: 0,
      hasMore: false,
    );
  }

  @override
  Future<ChatMessage> sendText({
    required String accessToken,
    required String conversationId,
    required String clientMessageId,
    required String text,
  }) async {
    final now = DateTime.now();
    return ChatMessage(
      clientMessageId: clientMessageId,
      conversationId: conversationId,
      senderId: 'local-user',
      senderName: '本地用户',
      messageKind: ChatMessageKind.text,
      content: ChatTextMessageContent(text: text),
      deliveryState: ChatMessageDeliveryState.sent,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Future<void> updateReadCursor({
    required String accessToken,
    required String conversationId,
    required int lastReadSequence,
  }) async {}
}
