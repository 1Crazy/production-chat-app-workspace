import 'package:production_chat_app/features/conversation/domain/entities/conversation_summary.dart';
import 'package:production_chat_app/features/conversation/domain/repositories/conversation_repository.dart';

class InMemoryConversationRepository implements ConversationRepository {
  @override
  Future<List<ConversationSummary>> fetchRecent({
    required String accessToken,
  }) async {
    return const [];
  }

  @override
  Future<ConversationSummary?> findById({
    required String accessToken,
    required String conversationId,
  }) async {
    return null;
  }

  @override
  Future<String> createOrReuseDirectConversation({
    required String accessToken,
    required String targetHandle,
  }) async {
    return 'conversation-id';
  }

  @override
  Future<String> createGroupConversation({
    required String accessToken,
    required String title,
    required List<String> memberHandles,
  }) async {
    return 'group-conversation-id';
  }
}
