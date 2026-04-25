import 'package:flutter/foundation.dart';
import 'package:production_chat_app/features/friendship/domain/repositories/friendship_repository.dart';
import 'package:production_chat_app/features/profile/domain/entities/discoverable_user.dart';
import 'package:production_chat_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:production_chat_app/shared/network/api_client.dart';

class RelationshipProfileController extends ChangeNotifier {
  RelationshipProfileController({
    required ProfileRepository profileRepository,
    required FriendshipRepository friendshipRepository,
  }) : _profileRepository = profileRepository,
       _friendshipRepository = friendshipRepository;

  final ProfileRepository _profileRepository;
  final FriendshipRepository _friendshipRepository;

  DiscoverableUser? _user;
  bool _isLoading = false;
  String? _errorMessage;

  DiscoverableUser? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load({
    required String accessToken,
    required String handle,
  }) async {
    await _runMutation(() async {
      _user = await _profileRepository.discoverByHandle(
        accessToken: accessToken,
        handle: handle,
      );
    });
  }

  Future<void> sendFriendRequest({
    required String accessToken,
    required String handle,
  }) async {
    await _runMutation(() async {
      await _friendshipRepository.createFriendRequest(
        accessToken: accessToken,
        targetHandle: handle,
      );
      await load(accessToken: accessToken, handle: handle);
    });
  }

  Future<void> acceptRequest({
    required String accessToken,
    required String handle,
    required String requestId,
  }) async {
    await _runMutation(() async {
      await _friendshipRepository.acceptFriendRequest(
        accessToken: accessToken,
        requestId: requestId,
      );
      await load(accessToken: accessToken, handle: handle);
    });
  }

  Future<void> rejectRequest({
    required String accessToken,
    required String handle,
    required String requestId,
  }) async {
    await _runMutation(() async {
      await _friendshipRepository.rejectFriendRequest(
        accessToken: accessToken,
        requestId: requestId,
      );
      await load(accessToken: accessToken, handle: handle);
    });
  }

  Future<void> removeFriend({
    required String accessToken,
    required String handle,
    required String friendUserId,
  }) async {
    await _runMutation(() async {
      await _friendshipRepository.removeFriend(
        accessToken: accessToken,
        friendUserId: friendUserId,
      );
      await load(accessToken: accessToken, handle: handle);
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
