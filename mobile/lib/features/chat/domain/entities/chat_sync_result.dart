import 'package:production_chat_app/features/chat/domain/entities/chat_message.dart';

class ChatSyncResult {
  const ChatSyncResult({
    required this.messages,
    required this.latestSequence,
    required this.nextAfterSequence,
    required this.hasMore,
  });

  final List<ChatMessage> messages;
  final int latestSequence;
  final int nextAfterSequence;
  final bool hasMore;
}
