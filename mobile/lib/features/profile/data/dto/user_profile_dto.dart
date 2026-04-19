import 'package:production_chat_app/features/profile/domain/entities/user_profile.dart';

class UserProfileDto {
  const UserProfileDto({
    required this.id,
    required this.identifier,
    required this.nickname,
    required this.handle,
    required this.avatarUrl,
    required this.discoveryMode,
  });

  factory UserProfileDto.fromJson(Map<String, dynamic> json) {
    return UserProfileDto(
      id: json['id']?.toString() ?? '',
      identifier: json['identifier']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      handle: json['handle']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),
      discoveryMode: json['discoveryMode']?.toString() ?? 'public',
    );
  }

  final String id;
  final String identifier;
  final String nickname;
  final String handle;
  final String? avatarUrl;
  final String discoveryMode;

  UserProfile toEntity() {
    return UserProfile(
      id: id,
      identifier: identifier,
      nickname: nickname,
      handle: handle,
      avatarUrl: avatarUrl,
      discoveryMode: discoveryMode,
    );
  }
}
