import 'package:production_chat_app/features/profile/data/datasources/profile_remote_data_source.dart';
import 'package:production_chat_app/features/profile/domain/entities/discoverable_user.dart';
import 'package:production_chat_app/features/profile/domain/entities/user_profile.dart';
import 'package:production_chat_app/features/profile/domain/repositories/profile_repository.dart';

class ProfileRepositoryImpl implements ProfileRepository {
  const ProfileRepositoryImpl({
    required ProfileRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final ProfileRemoteDataSource _remoteDataSource;

  @override
  Future<UserProfile> fetchCurrent({required String accessToken}) async {
    final dto = await _remoteDataSource.fetchCurrent(accessToken: accessToken);
    return dto.toEntity();
  }

  @override
  Future<UserProfile> updateCurrent({
    required String accessToken,
    required String nickname,
    required String? avatarUrl,
    required String discoveryMode,
  }) async {
    final dto = await _remoteDataSource.updateCurrent(
      accessToken: accessToken,
      nickname: nickname,
      avatarUrl: avatarUrl,
      discoveryMode: discoveryMode,
    );
    return dto.toEntity();
  }

  @override
  Future<DiscoverableUser> discoverByHandle({
    required String accessToken,
    required String handle,
  }) async {
    final dto = await _remoteDataSource.discoverByHandle(
      accessToken: accessToken,
      handle: handle,
    );
    return dto.toEntity();
  }
}
