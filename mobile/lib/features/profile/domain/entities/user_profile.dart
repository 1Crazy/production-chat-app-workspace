class UserProfile {
  const UserProfile({
    required this.id,
    required this.identifier,
    required this.nickname,
    required this.handle,
    required this.avatarUrl,
    required this.discoveryMode,
  });

  final String id;
  final String identifier;
  final String nickname;
  final String handle;
  final String? avatarUrl;
  final String discoveryMode;
}
