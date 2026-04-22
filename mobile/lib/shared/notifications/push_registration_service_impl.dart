import 'package:production_chat_app/shared/notifications/notification_remote_data_source.dart';
import 'package:production_chat_app/shared/notifications/push_registration_service.dart';
import 'package:production_chat_app/shared/notifications/push_token_provider.dart';
import 'package:production_chat_app/shared/storage/key_value_store.dart';

class PushRegistrationServiceImpl implements PushRegistrationService {
  static const _privacyModeStorageKey =
      'shared.notifications.privacy_mode_enabled';

  const PushRegistrationServiceImpl({
    required NotificationRemoteDataSource remoteDataSource,
    required PushTokenProvider pushTokenProvider,
    required KeyValueStore keyValueStore,
  }) : _remoteDataSource = remoteDataSource,
       _pushTokenProvider = pushTokenProvider,
       _keyValueStore = keyValueStore;

  final NotificationRemoteDataSource _remoteDataSource;
  final PushTokenProvider _pushTokenProvider;
  final KeyValueStore _keyValueStore;

  @override
  Stream<void> get tokenRefreshStream {
    return _pushTokenProvider.tokenRefreshStream.map((_) {});
  }

  @override
  Future<void> syncPushRegistration({required String accessToken}) async {
    final token = await _pushTokenProvider.fetchDevicePushToken();

    if (token == null) {
      return;
    }

    final privacyModeEnabled = await loadPrivacyModeEnabled();
    await _remoteDataSource.registerPushToken(
      accessToken: accessToken,
      token: token,
      privacyModeEnabled: privacyModeEnabled,
    );
  }

  @override
  Future<bool> loadPrivacyModeEnabled() async {
    return _keyValueStore.readString(_privacyModeStorageKey) == 'true';
  }

  @override
  Future<void> updatePrivacyMode({
    required bool enabled,
    String? accessToken,
  }) async {
    await _keyValueStore.writeString(
      _privacyModeStorageKey,
      enabled ? 'true' : 'false',
    );

    if (accessToken != null && accessToken.isNotEmpty) {
      await syncPushRegistration(accessToken: accessToken);
    }
  }
}
