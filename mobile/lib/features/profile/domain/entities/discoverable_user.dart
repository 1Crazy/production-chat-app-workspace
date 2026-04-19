class DiscoverableUser {
  const DiscoverableUser({required this.discoverable, required this.profile});

  final bool discoverable;
  final DiscoverableProfile? profile;
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
