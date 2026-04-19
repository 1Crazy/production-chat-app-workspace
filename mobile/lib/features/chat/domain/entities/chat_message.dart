class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderName,
    required this.content,
  });

  final String id;
  final String senderName;
  final String content;
}
