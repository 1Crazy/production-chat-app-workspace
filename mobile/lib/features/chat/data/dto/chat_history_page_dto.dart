import 'package:production_chat_app/features/chat/data/dto/chat_message_dto.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_history_page.dart';
import 'package:production_chat_app/features/chat/domain/entities/chat_sync_result.dart';

class ChatHistoryPageDto {
  const ChatHistoryPageDto({
    required this.messages,
    required this.latestSequence,
    required this.readCursors,
    required this.memberProfiles,
    required this.nextBeforeSequence,
  });

  factory ChatHistoryPageDto.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>;
    final nextCursor = json['nextCursor'] as Map<String, dynamic>?;
    final readCursors = json['readCursors'] as List<dynamic>? ?? const [];
    final memberProfiles = json['memberProfiles'] as List<dynamic>? ?? const [];

    return ChatHistoryPageDto(
      messages: items
          .map((item) {
            return ChatMessageDto.fromJson(item as Map<String, dynamic>);
          })
          .toList(growable: false),
      latestSequence: json['latestSequence'] as int,
      readCursors: readCursors
          .map((item) => item as Map<String, dynamic>)
          .toList(growable: false),
      memberProfiles: memberProfiles
          .map((item) => item as Map<String, dynamic>)
          .toList(growable: false),
      nextBeforeSequence: nextCursor?['beforeSequence'] as int?,
    );
  }

  final List<ChatMessageDto> messages;
  final int latestSequence;
  final List<Map<String, dynamic>> readCursors;
  final List<Map<String, dynamic>> memberProfiles;
  final int? nextBeforeSequence;

  ChatHistoryPage toEntity({required String currentUserId}) {
    final peerReadSequenceByUserId = <String, int>{};
    final memberDisplayNameByUserId = <String, String>{};
    final memberHandleByUserId = <String, String>{};
    final memberAvatarUrlByUserId = <String, String?>{};
    final peerReadUpdatedAtByUserId = <String, DateTime>{};

    for (final profile in memberProfiles) {
      memberDisplayNameByUserId[profile['id'] as String] =
          profile['nickname'] as String;
      memberHandleByUserId[profile['id'] as String] =
          profile['handle'] as String;
      memberAvatarUrlByUserId[profile['id'] as String] =
          profile['avatarUrl'] as String?;
    }

    for (final cursor in readCursors) {
      final userId = cursor['userId'] as String;

      if (userId == currentUserId) {
        continue;
      }

      peerReadSequenceByUserId[userId] = cursor['lastReadSequence'] as int;
      peerReadUpdatedAtByUserId[userId] = DateTime.parse(
        cursor['updatedAt'] as String,
      );
    }

    return ChatHistoryPage(
      messages: messages.map((item) => item.toEntity()).toList(growable: false),
      latestSequence: latestSequence,
      peerReadSequenceByUserId: peerReadSequenceByUserId,
      memberDisplayNameByUserId: memberDisplayNameByUserId,
      memberHandleByUserId: memberHandleByUserId,
      memberAvatarUrlByUserId: memberAvatarUrlByUserId,
      peerReadUpdatedAtByUserId: peerReadUpdatedAtByUserId,
      nextBeforeSequence: nextBeforeSequence,
    );
  }
}

class ChatSyncResultDto {
  const ChatSyncResultDto({
    required this.messages,
    required this.latestSequence,
    required this.nextAfterSequence,
    required this.hasMore,
  });

  factory ChatSyncResultDto.fromJson(Map<String, dynamic> json) {
    final items = json['items'] as List<dynamic>;

    return ChatSyncResultDto(
      messages: items
          .map((item) {
            return ChatMessageDto.fromJson(item as Map<String, dynamic>);
          })
          .toList(growable: false),
      latestSequence: json['latestSequence'] as int,
      nextAfterSequence: json['nextAfterSequence'] as int,
      hasMore: json['hasMore'] as bool,
    );
  }

  final List<ChatMessageDto> messages;
  final int latestSequence;
  final int nextAfterSequence;
  final bool hasMore;

  ChatSyncResult toEntity() {
    return ChatSyncResult(
      messages: messages.map((item) => item.toEntity()).toList(growable: false),
      latestSequence: latestSequence,
      nextAfterSequence: nextAfterSequence,
      hasMore: hasMore,
    );
  }
}
