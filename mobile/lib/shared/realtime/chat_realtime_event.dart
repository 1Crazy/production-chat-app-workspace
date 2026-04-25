import 'package:production_chat_app/features/chat/domain/entities/chat_message.dart';
import 'package:production_chat_app/features/chat/data/dto/chat_message_dto.dart';

enum ChatRealtimeConnectionState { connecting, connected, disconnected }

class ChatConnectionReadyEvent {
  const ChatConnectionReadyEvent({
    required this.connectionId,
    required this.recovered,
    required this.activeConnectionCount,
    required this.conversationLatestSequenceById,
  });

  factory ChatConnectionReadyEvent.fromJson(Map<String, dynamic> json) {
    final conversationStates =
        (json['conversationStates'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();

    return ChatConnectionReadyEvent(
      connectionId: json['connectionId'] as String,
      recovered: json['recovered'] as bool? ?? false,
      activeConnectionCount: json['activeConnectionCount'] as int? ?? 0,
      conversationLatestSequenceById: {
        for (final item in conversationStates)
          item['conversationId'] as String: item['latestSequence'] as int,
      },
    );
  }

  final String connectionId;
  final bool recovered;
  final int activeConnectionCount;
  final Map<String, int> conversationLatestSequenceById;
}

class ChatMessageCreatedEvent {
  const ChatMessageCreatedEvent({required this.message});

  factory ChatMessageCreatedEvent.fromJson(Map<String, dynamic> json) {
    return ChatMessageCreatedEvent(
      message: ChatMessageDto.fromJson(
        json['message'] as Map<String, dynamic>,
      ).toEntity(),
    );
  }

  final ChatMessage message;
}

class ChatConversationCreatedEvent {
  const ChatConversationCreatedEvent({required this.conversationId});

  factory ChatConversationCreatedEvent.fromJson(Map<String, dynamic> json) {
    final conversation = json['conversation'] as Map<String, dynamic>;

    return ChatConversationCreatedEvent(
      conversationId: conversation['id'] as String,
    );
  }

  final String conversationId;
}

class ChatReadCursorUpdatedEvent {
  const ChatReadCursorUpdatedEvent({
    required this.conversationId,
    required this.userId,
    required this.lastReadSequence,
    required this.unreadCount,
    required this.updatedAt,
  });

  factory ChatReadCursorUpdatedEvent.fromJson(Map<String, dynamic> json) {
    final readCursor = json['readCursor'] as Map<String, dynamic>;

    return ChatReadCursorUpdatedEvent(
      conversationId: readCursor['conversationId'] as String,
      userId: readCursor['userId'] as String,
      lastReadSequence: readCursor['lastReadSequence'] as int,
      unreadCount: readCursor['unreadCount'] as int,
      updatedAt: DateTime.parse(readCursor['updatedAt'] as String).toLocal(),
    );
  }

  final String conversationId;
  final String userId;
  final int lastReadSequence;
  final int unreadCount;
  final DateTime updatedAt;
}

class ChatTypingUpdatedEvent {
  const ChatTypingUpdatedEvent({
    required this.conversationId,
    required this.userId,
    required this.isTyping,
    required this.expiresAt,
  });

  factory ChatTypingUpdatedEvent.fromJson(Map<String, dynamic> json) {
    return ChatTypingUpdatedEvent(
      conversationId: json['conversationId'] as String,
      userId: json['userId'] as String,
      isTyping: json['isTyping'] as bool? ?? false,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String).toLocal(),
    );
  }

  final String conversationId;
  final String userId;
  final bool isTyping;
  final DateTime? expiresAt;
}

class ChatSessionRevokedEvent {
  const ChatSessionRevokedEvent({
    required this.sessionId,
    required this.reason,
  });

  factory ChatSessionRevokedEvent.fromJson(Map<String, dynamic> json) {
    return ChatSessionRevokedEvent(
      sessionId: json['sessionId'] as String,
      reason: json['reason'] as String? ?? 'session_revoked',
    );
  }

  final String sessionId;
  final String reason;
}
