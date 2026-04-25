import 'package:production_chat_app/features/friendship/data/datasources/friendship_remote_data_source.dart';
import 'package:production_chat_app/features/friendship/domain/entities/friend_request_summary.dart';
import 'package:production_chat_app/features/friendship/domain/entities/friend_summary.dart';
import 'package:production_chat_app/features/friendship/domain/repositories/friendship_repository.dart';

class FriendshipRepositoryImpl implements FriendshipRepository {
  const FriendshipRepositoryImpl({
    required FriendshipRemoteDataSource remoteDataSource,
  }) : _remoteDataSource = remoteDataSource;

  final FriendshipRemoteDataSource _remoteDataSource;

  @override
  Future<List<FriendSummary>> fetchFriends({required String accessToken}) async {
    final dtos = await _remoteDataSource.fetchFriends(accessToken: accessToken);
    return dtos.map((item) => item.toEntity()).toList(growable: false);
  }

  @override
  Future<List<FriendRequestSummary>> fetchIncomingRequests({
    required String accessToken,
  }) async {
    final dtos = await _remoteDataSource.fetchIncomingRequests(
      accessToken: accessToken,
    );
    return dtos.map((item) => item.toEntity()).toList(growable: false);
  }

  @override
  Future<int> fetchUnreadIncomingRequestCount({
    required String accessToken,
  }) {
    return _remoteDataSource.fetchUnreadIncomingRequestCount(
      accessToken: accessToken,
    );
  }

  @override
  Future<List<FriendRequestSummary>> fetchOutgoingRequests({
    required String accessToken,
  }) async {
    final dtos = await _remoteDataSource.fetchOutgoingRequests(
      accessToken: accessToken,
    );
    return dtos.map((item) => item.toEntity()).toList(growable: false);
  }

  @override
  Future<void> createFriendRequest({
    required String accessToken,
    required String targetHandle,
    String? message,
  }) {
    return _remoteDataSource.createFriendRequest(
      accessToken: accessToken,
      targetHandle: targetHandle,
      message: message,
    );
  }

  @override
  Future<void> acceptFriendRequest({
    required String accessToken,
    required String requestId,
  }) {
    return _remoteDataSource.acceptFriendRequest(
      accessToken: accessToken,
      requestId: requestId,
    );
  }

  @override
  Future<void> ignoreFriendRequest({
    required String accessToken,
    required String requestId,
  }) {
    return _remoteDataSource.ignoreFriendRequest(
      accessToken: accessToken,
      requestId: requestId,
    );
  }

  @override
  Future<void> markIncomingRequestsViewed({
    required String accessToken,
  }) {
    return _remoteDataSource.markIncomingRequestsViewed(
      accessToken: accessToken,
    );
  }

  @override
  Future<void> rejectFriendRequest({
    required String accessToken,
    required String requestId,
  }) {
    return _remoteDataSource.rejectFriendRequest(
      accessToken: accessToken,
      requestId: requestId,
    );
  }

  @override
  Future<void> removeFriend({
    required String accessToken,
    required String friendUserId,
  }) {
    return _remoteDataSource.removeFriend(
      accessToken: accessToken,
      friendUserId: friendUserId,
    );
  }
}
