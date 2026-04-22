class NotificationSyncConversationState {
  const NotificationSyncConversationState({
    required this.conversationId,
    required this.latestSequence,
  });

  final String conversationId;
  final int latestSequence;
}

class NotificationSyncState {
  const NotificationSyncState({
    required this.unreadBadgeCount,
    required this.conversationStates,
    required this.recoveredPushMessageId,
  });

  factory NotificationSyncState.fromJson(Map<String, dynamic> json) {
    final conversations = (json['conversations'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((item) {
          return NotificationSyncConversationState(
            conversationId: item['id'] as String,
            latestSequence: item['latestSequence'] as int? ?? 0,
          );
        })
        .toList(growable: false);

    return NotificationSyncState(
      unreadBadgeCount: json['unreadBadgeCount'] as int? ?? 0,
      conversationStates: conversations,
      recoveredPushMessageId: json['recoveredPushMessageId'] as String?,
    );
  }

  final int unreadBadgeCount;
  final List<NotificationSyncConversationState> conversationStates;
  final String? recoveredPushMessageId;
}
