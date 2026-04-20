class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.type,
    required this.title,
    required this.memberCount,
    required this.lastMessagePreview,
    required this.latestSequence,
    required this.unreadCount,
    required this.updatedAt,
    required this.lastMessageAt,
  });

  final String id;
  final String type;
  final String title;
  final int memberCount;
  final String lastMessagePreview;
  final int latestSequence;
  final int unreadCount;
  final DateTime updatedAt;
  final DateTime? lastMessageAt;

  ConversationSummary copyWith({
    String? id,
    String? type,
    String? title,
    int? memberCount,
    String? lastMessagePreview,
    int? latestSequence,
    int? unreadCount,
    DateTime? updatedAt,
    DateTime? lastMessageAt,
  }) {
    return ConversationSummary(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      memberCount: memberCount ?? this.memberCount,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      latestSequence: latestSequence ?? this.latestSequence,
      unreadCount: unreadCount ?? this.unreadCount,
      updatedAt: updatedAt ?? this.updatedAt,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
    );
  }
}
