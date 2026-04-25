import 'package:flutter/foundation.dart';
import 'package:production_chat_app/features/friendship/domain/entities/friend_request_summary.dart';
import 'package:production_chat_app/features/friendship/domain/repositories/friendship_repository.dart';
import 'package:production_chat_app/shared/network/api_client.dart';

class FriendRequestsController extends ChangeNotifier {
  FriendRequestsController({
    required FriendshipRepository friendshipRepository,
  }) : _friendshipRepository = friendshipRepository;

  final FriendshipRepository _friendshipRepository;

  List<FriendRequestSummary> _incomingRequests = const [];
  List<FriendRequestSummary> _outgoingRequests = const [];
  bool _isLoading = false;
  String? _errorMessage;

  List<FriendRequestSummary> get incomingRequests => _incomingRequests;
  List<FriendRequestSummary> get outgoingRequests => _outgoingRequests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load({required String accessToken, bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      _errorMessage = null;
      final responses = await Future.wait([
        _friendshipRepository.fetchIncomingRequests(accessToken: accessToken),
        _friendshipRepository.fetchOutgoingRequests(accessToken: accessToken),
      ]);
      _incomingRequests = responses[0];
      _outgoingRequests = responses[1];
    } catch (error) {
      _errorMessage = formatDisplayError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createFriendRequest({
    required String accessToken,
    required String targetHandle,
    String? message,
  }) async {
    await _runMutation(() async {
      await _friendshipRepository.createFriendRequest(
        accessToken: accessToken,
        targetHandle: targetHandle,
        message: message,
      );
      await load(accessToken: accessToken, silent: true);
    });
  }

  Future<void> acceptRequest({
    required String accessToken,
    required String requestId,
  }) async {
    await _runMutation(() async {
      await _friendshipRepository.acceptFriendRequest(
        accessToken: accessToken,
        requestId: requestId,
      );
      await load(accessToken: accessToken, silent: true);
    });
  }

  Future<void> ignoreRequest({
    required String accessToken,
    required String requestId,
  }) async {
    await _runMutation(() async {
      await _friendshipRepository.ignoreFriendRequest(
        accessToken: accessToken,
        requestId: requestId,
      );
      await load(accessToken: accessToken, silent: true);
    });
  }

  Future<void> rejectRequest({
    required String accessToken,
    required String requestId,
  }) async {
    await _runMutation(() async {
      await _friendshipRepository.rejectFriendRequest(
        accessToken: accessToken,
        requestId: requestId,
      );
      await load(accessToken: accessToken, silent: true);
    });
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
    } catch (error) {
      _errorMessage = formatDisplayError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
