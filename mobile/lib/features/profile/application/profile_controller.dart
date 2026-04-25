import 'package:flutter/foundation.dart';
import 'package:production_chat_app/features/profile/domain/entities/discoverable_user.dart';
import 'package:production_chat_app/features/profile/domain/entities/user_profile.dart';
import 'package:production_chat_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:production_chat_app/shared/network/api_client.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({required ProfileRepository profileRepository})
    : _profileRepository = profileRepository;

  final ProfileRepository _profileRepository;

  UserProfile? _currentProfile;
  DiscoverableUser? _discoveredUser;
  bool _isBusy = false;
  String? _errorMessage;

  UserProfile? get currentProfile => _currentProfile;
  DiscoverableUser? get discoveredUser => _discoveredUser;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  Future<void> loadCurrentProfile({required String accessToken}) async {
    await _runBusy(() async {
      _currentProfile = await _profileRepository.fetchCurrent(
        accessToken: accessToken,
      );
    });
  }

  Future<void> updateCurrentProfile({
    required String accessToken,
    required String nickname,
    required String? avatarUrl,
    required String discoveryMode,
  }) async {
    await _runBusy(() async {
      _currentProfile = await _profileRepository.updateCurrent(
        accessToken: accessToken,
        nickname: nickname,
        avatarUrl: avatarUrl,
        discoveryMode: discoveryMode,
      );
    });
  }

  Future<void> discoverByHandle({
    required String accessToken,
    required String handle,
  }) async {
    await _runBusy(() async {
      _discoveredUser = await _profileRepository.discoverByHandle(
        accessToken: accessToken,
        handle: handle,
      );
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
    } catch (error) {
      _errorMessage = formatDisplayError(error);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
