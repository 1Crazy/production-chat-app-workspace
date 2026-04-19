import 'package:production_chat_app/features/chat/domain/entities/chat_message.dart';
import 'package:production_chat_app/features/chat/domain/repositories/chat_repository.dart';

class InMemoryChatRepository implements ChatRepository {
  @override
  Future<List<ChatMessage>> fetchHistory() async {
    return const [];
  }
}
