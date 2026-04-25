import 'package:production_chat_app/features/friendship/domain/entities/friendship_status.dart';

class FriendRelationship {
  const FriendRelationship({
    required this.status,
    required this.pendingRequestId,
    required this.canMessage,
  });

  final FriendshipStatus status;
  final String? pendingRequestId;
  final bool canMessage;
}
