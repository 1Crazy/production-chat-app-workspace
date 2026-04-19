import 'package:production_chat_app/features/profile/data/dto/discoverable_user_dto.dart';
import 'package:production_chat_app/features/profile/data/dto/user_profile_dto.dart';
import 'package:production_chat_app/shared/network/api_client.dart';

class ProfileRemoteDataSource {
  const ProfileRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<UserProfileDto> fetchCurrent({required String accessToken}) async {
    final response = await _apiClient.getJson(
      '/users/me',
      accessToken: accessToken,
    );
    return UserProfileDto.fromJson(response);
  }

  Future<UserProfileDto> updateCurrent({
    required String accessToken,
    required String nickname,
    required String? avatarUrl,
    required String discoveryMode,
  }) async {
    final response = await _apiClient.patchJson(
      '/users/me',
      accessToken: accessToken,
      body: {
        'nickname': nickname,
        'avatarUrl': avatarUrl,
        'discoveryMode': discoveryMode,
      },
    );
    return UserProfileDto.fromJson(response);
  }

  Future<DiscoverableUserDto> discoverByHandle({
    required String accessToken,
    required String handle,
  }) async {
    final encodedHandle = Uri.encodeQueryComponent(handle);
    final response = await _apiClient.getJson(
      '/users/discovery?handle=$encodedHandle',
      accessToken: accessToken,
    );
    return DiscoverableUserDto.fromJson(response);
  }
}
