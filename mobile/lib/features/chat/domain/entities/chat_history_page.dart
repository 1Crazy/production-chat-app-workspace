import 'package:production_chat_app/features/chat/domain/entities/chat_message.dart';

class ChatHistoryPage {
  const ChatHistoryPage({
    required this.messages,
    required this.latestSequence,
    required this.peerReadSequenceByUserId,
    required this.memberDisplayNameByUserId,
    required this.memberHandleByUserId,
    required this.memberAvatarUrlByUserId,
    required this.peerReadUpdatedAtByUserId,
    required this.nextBeforeSequence,
  });

  final List<ChatMessage> messages;
  final int latestSequence;
  final Map<String, int> peerReadSequenceByUserId;
  final Map<String, String> memberDisplayNameByUserId;
  final Map<String, String> memberHandleByUserId;
  final Map<String, String?> memberAvatarUrlByUserId;
  final Map<String, DateTime> peerReadUpdatedAtByUserId;
  final int? nextBeforeSequence;
}
