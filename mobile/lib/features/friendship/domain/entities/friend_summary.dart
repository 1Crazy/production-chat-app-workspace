import 'package:production_chat_app/features/friendship/domain/entities/friend_user_profile.dart';

class FriendSummary {
  const FriendSummary({
    required this.friendUserId,
    required this.createdAt,
    required this.profile,
  });

  final String friendUserId;
  final DateTime createdAt;
  final FriendUserProfile profile;
}
