class ChatReadReceiptMember {
  const ChatReadReceiptMember({
    required this.userId,
    required this.displayName,
    required this.handle,
    required this.hasRead,
    this.avatarUrl,
    this.readAt,
  });

  final String userId;
  final String displayName;
  final String handle;
  final bool hasRead;
  final String? avatarUrl;
  final DateTime? readAt;
}
