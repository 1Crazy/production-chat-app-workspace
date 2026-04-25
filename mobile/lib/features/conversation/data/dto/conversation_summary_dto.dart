import 'package:production_chat_app/features/conversation/domain/entities/conversation_summary.dart';

class ConversationSummaryDto {
  const ConversationSummaryDto({
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

  factory ConversationSummaryDto.fromJson(Map<String, dynamic> json) {
    return ConversationSummaryDto(
      id: json['id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      memberCount: json['memberCount'] as int,
      lastMessagePreview: json['lastMessagePreview'] as String,
      latestSequence: json['latestSequence'] as int,
      unreadCount: json['unreadCount'] as int,
      updatedAt: _parseToLocal(json['updatedAt'] as String),
      lastMessageAt: json['lastMessageAt'] == null
          ? null
          : _parseToLocal(json['lastMessageAt'] as String),
    );
  }

  factory ConversationSummaryDto.fromConversationViewJson(
    Map<String, dynamic> json,
  ) {
    final members = json['members'] as List<dynamic>? ?? const [];

    return ConversationSummaryDto(
      id: json['id'] as String,
      type: json['type'] as String,
      title: (json['title'] as String?)?.trim().isNotEmpty == true
          ? json['title'] as String
          : '会话',
      memberCount: members.length,
      lastMessagePreview: '',
      latestSequence: json['latestSequence'] as int? ?? 0,
      unreadCount: 0,
      updatedAt: _parseToLocal(json['updatedAt'] as String),
      lastMessageAt: null,
    );
  }

  final String id;
  final String type;
  final String title;
  final int memberCount;
  final String lastMessagePreview;
  final int latestSequence;
  final int unreadCount;
  final DateTime updatedAt;
  final DateTime? lastMessageAt;

  ConversationSummary toEntity() {
    return ConversationSummary(
      id: id,
      type: type,
      title: title,
      memberCount: memberCount,
      lastMessagePreview: lastMessagePreview,
      latestSequence: latestSequence,
      unreadCount: unreadCount,
      updatedAt: updatedAt,
      lastMessageAt: lastMessageAt,
    );
  }

  static DateTime _parseToLocal(String rawValue) {
    return DateTime.parse(rawValue).toLocal();
  }
}
