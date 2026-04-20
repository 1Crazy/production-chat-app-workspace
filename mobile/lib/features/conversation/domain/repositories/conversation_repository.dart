import '../entities/conversation_summary.dart';

abstract class ConversationRepository {
  Future<List<ConversationSummary>> fetchRecent({required String accessToken});

  Future<ConversationSummary?> findById({
    required String accessToken,
    required String conversationId,
  });

  Future<String> createOrReuseDirectConversation({
    required String accessToken,
    required String targetHandle,
  });
}
