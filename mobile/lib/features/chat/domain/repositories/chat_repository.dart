import '../entities/chat_message.dart';
import '../entities/chat_history_page.dart';
import '../entities/chat_sync_result.dart';

abstract class ChatRepository {
  Future<ChatHistoryPage> fetchHistory({
    required String accessToken,
    required String conversationId,
    required String currentUserId,
    int? beforeSequence,
    int limit = 20,
  });

  Future<ChatSyncResult> syncAfter({
    required String accessToken,
    required String conversationId,
    required int afterSequence,
    int limit = 100,
  });

  Future<ChatMessage> sendText({
    required String accessToken,
    required String conversationId,
    required String clientMessageId,
    required String text,
  });

  Future<void> updateReadCursor({
    required String accessToken,
    required String conversationId,
    required int lastReadSequence,
  });
}
