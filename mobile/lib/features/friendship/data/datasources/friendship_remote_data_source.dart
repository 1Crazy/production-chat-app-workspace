import 'package:production_chat_app/features/friendship/data/dto/friendship_dto.dart';
import 'package:production_chat_app/shared/network/api_client.dart';

class FriendshipRemoteDataSource {
  const FriendshipRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<List<FriendSummaryDto>> fetchFriends({
    required String accessToken,
  }) async {
    final response = await _apiClient.getJsonList(
      '/friendships',
      accessToken: accessToken,
    );

    return response
        .map((item) => FriendSummaryDto.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }

  Future<List<FriendRequestSummaryDto>> fetchIncomingRequests({
    required String accessToken,
  }) async {
    final response = await _apiClient.getJsonList(
      '/friendships/requests/incoming',
      accessToken: accessToken,
    );

    return response
        .map(
          (item) =>
              FriendRequestSummaryDto.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<int> fetchUnreadIncomingRequestCount({
    required String accessToken,
  }) async {
    final response = await _apiClient.getJson(
      '/friendships/requests/unread-count',
      accessToken: accessToken,
    );

    return (response['unreadCount'] as num?)?.toInt() ?? 0;
  }

  Future<List<FriendRequestSummaryDto>> fetchOutgoingRequests({
    required String accessToken,
  }) async {
    final response = await _apiClient.getJsonList(
      '/friendships/requests/outgoing',
      accessToken: accessToken,
    );

    return response
        .map(
          (item) =>
              FriendRequestSummaryDto.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  Future<void> createFriendRequest({
    required String accessToken,
    required String targetHandle,
    String? message,
  }) async {
    await _apiClient.postJson(
      '/friendships/requests',
      accessToken: accessToken,
      body: {
        'targetHandle': targetHandle,
        if (message != null && message.trim().isNotEmpty) 'message': message,
      },
    );
  }

  Future<void> acceptFriendRequest({
    required String accessToken,
    required String requestId,
  }) async {
    await _apiClient.postJson(
      '/friendships/requests/$requestId/accept',
      accessToken: accessToken,
    );
  }

  Future<void> ignoreFriendRequest({
    required String accessToken,
    required String requestId,
  }) async {
    await _apiClient.postJson(
      '/friendships/requests/$requestId/ignore',
      accessToken: accessToken,
    );
  }

  Future<void> markIncomingRequestsViewed({required String accessToken}) async {
    await _apiClient.postJson(
      '/friendships/requests/mark-viewed',
      accessToken: accessToken,
    );
  }

  Future<void> rejectFriendRequest({
    required String accessToken,
    required String requestId,
    String? rejectReason,
  }) async {
    await _apiClient.postJson(
      '/friendships/requests/$requestId/reject',
      accessToken: accessToken,
      body: {
        if (rejectReason != null && rejectReason.trim().isNotEmpty)
          'rejectReason': rejectReason,
      },
    );
  }

  Future<void> deleteFriendRequestRecord({
    required String accessToken,
    required String requestId,
  }) async {
    await _apiClient.deleteJson(
      '/friendships/requests/$requestId',
      accessToken: accessToken,
    );
  }

  Future<void> removeFriend({
    required String accessToken,
    required String friendUserId,
  }) async {
    await _apiClient.deleteJson(
      '/friendships/$friendUserId',
      accessToken: accessToken,
    );
  }
}
