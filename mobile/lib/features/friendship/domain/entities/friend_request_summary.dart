import 'package:production_chat_app/features/friendship/domain/entities/friend_user_profile.dart';

enum FriendRequestDirection { incoming, outgoing }

class FriendRequestSummary {
  const FriendRequestSummary({
    required this.id,
    required this.direction,
    required this.status,
    required this.message,
    required this.createdAt,
    required this.respondedAt,
    required this.counterparty,
  });

  final String id;
  final FriendRequestDirection direction;
  final String status;
  final String? message;
  final DateTime createdAt;
  final DateTime? respondedAt;
  final FriendUserProfile counterparty;
}
