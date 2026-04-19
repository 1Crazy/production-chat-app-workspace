import '../entities/conversation_summary.dart';

abstract class ConversationRepository {
  Future<List<ConversationSummary>> fetchRecent();
}
