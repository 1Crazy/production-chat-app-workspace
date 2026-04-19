import 'package:production_chat_app/features/profile/domain/entities/discoverable_user.dart';
import 'package:production_chat_app/features/profile/domain/entities/user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile> fetchCurrent({required String accessToken});

  Future<UserProfile> updateCurrent({
    required String accessToken,
    required String nickname,
    required String? avatarUrl,
    required String discoveryMode,
  });

  Future<DiscoverableUser> discoverByHandle({
    required String accessToken,
    required String handle,
  });
}
