import 'package:production_chat_app/features/friendship/domain/entities/friend_request_summary.dart';
import 'package:production_chat_app/features/friendship/domain/entities/friend_summary.dart';

abstract class FriendshipRepository {
  Future<List<FriendSummary>> fetchFriends({required String accessToken});

  Future<List<FriendRequestSummary>> fetchIncomingRequests({
    required String accessToken,
  });

  Future<int> fetchUnreadIncomingRequestCount({
    required String accessToken,
  });

  Future<List<FriendRequestSummary>> fetchOutgoingRequests({
    required String accessToken,
  });

  Future<void> createFriendRequest({
    required String accessToken,
    required String targetHandle,
    String? message,
  });

  Future<void> acceptFriendRequest({
    required String accessToken,
    required String requestId,
  });

  Future<void> ignoreFriendRequest({
    required String accessToken,
    required String requestId,
  });

  Future<void> markIncomingRequestsViewed({
    required String accessToken,
  });

  Future<void> rejectFriendRequest({
    required String accessToken,
    required String requestId,
  });

  Future<void> removeFriend({
    required String accessToken,
    required String friendUserId,
  });
}
