import 'package:flutter/foundation.dart';
import 'package:production_chat_app/features/friendship/domain/entities/friend_summary.dart';
import 'package:production_chat_app/features/friendship/domain/repositories/friendship_repository.dart';
import 'package:production_chat_app/shared/network/api_client.dart';

class FriendshipContactsController extends ChangeNotifier {
  FriendshipContactsController({
    required FriendshipRepository friendshipRepository,
  }) : _friendshipRepository = friendshipRepository;

  final FriendshipRepository _friendshipRepository;

  List<FriendSummary> _friends = const [];
  bool _isLoading = false;
  String? _errorMessage;

  List<FriendSummary> get friends => _friends;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> load({required String accessToken, bool silent = false}) async {
    if (!silent) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      _errorMessage = null;
      _friends = await _friendshipRepository.fetchFriends(
        accessToken: accessToken,
      );
    } catch (error) {
      _errorMessage = formatDisplayError(error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
