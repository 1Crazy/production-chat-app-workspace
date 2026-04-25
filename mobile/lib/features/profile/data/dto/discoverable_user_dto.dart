import 'package:production_chat_app/features/friendship/data/dto/friendship_dto.dart';
import 'package:production_chat_app/features/profile/domain/entities/discoverable_user.dart';

class DiscoverableUserDto {
  const DiscoverableUserDto({
    required this.discoverable,
    required this.profile,
    required this.relationship,
  });

  factory DiscoverableUserDto.fromJson(Map<String, dynamic> json) {
    return DiscoverableUserDto(
      discoverable: json['discoverable'] as bool? ?? false,
      profile: json['profile'] is Map<String, dynamic>
          ? DiscoverableProfileDto.fromJson(
              json['profile'] as Map<String, dynamic>,
            )
          : null,
      relationship: FriendshipRelationshipDto.fromJson(
        json['relationship'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  final bool discoverable;
  final DiscoverableProfileDto? profile;
  final FriendshipRelationshipDto relationship;

  DiscoverableUser toEntity() {
    return DiscoverableUser(
      discoverable: discoverable,
      profile: profile?.toEntity(),
      relationship: relationship.toEntity(),
    );
  }
}

class DiscoverableProfileDto {
  const DiscoverableProfileDto({
    required this.id,
    required this.nickname,
    required this.handle,
    required this.avatarUrl,
  });

  factory DiscoverableProfileDto.fromJson(Map<String, dynamic> json) {
    return DiscoverableProfileDto(
      id: json['id']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      handle: json['handle']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }

  final String id;
  final String nickname;
  final String handle;
  final String? avatarUrl;

  DiscoverableProfile toEntity() {
    return DiscoverableProfile(
      id: id,
      nickname: nickname,
      handle: handle,
      avatarUrl: avatarUrl,
    );
  }
}
