import 'package:production_chat_app/features/friendship/domain/entities/friend_relationship.dart';

class DiscoverableUser {
  const DiscoverableUser({
    required this.discoverable,
    required this.profile,
    required this.relationship,
  });

  final bool discoverable;
  final DiscoverableProfile? profile;
  final FriendRelationship relationship;
}

class DiscoverableProfile {
  const DiscoverableProfile({
    required this.id,
    required this.nickname,
    required this.handle,
    required this.avatarUrl,
  });

  final String id;
  final String nickname;
  final String handle;
  final String? avatarUrl;
}
