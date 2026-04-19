import 'package:production_chat_app/features/conversation/domain/entities/conversation_summary.dart';
import 'package:production_chat_app/features/conversation/domain/repositories/conversation_repository.dart';

class InMemoryConversationRepository implements ConversationRepository {
  @override
  Future<List<ConversationSummary>> fetchRecent() async {
    return const [];
  }
}
