import 'package:production_chat_app/shared/notifications/notification_remote_data_source.dart';
import 'package:production_chat_app/shared/notifications/push_registration_service.dart';
import 'package:production_chat_app/shared/notifications/push_token_provider.dart';

class PushRegistrationServiceImpl implements PushRegistrationService {
  const PushRegistrationServiceImpl({
    required NotificationRemoteDataSource remoteDataSource,
    required PushTokenProvider pushTokenProvider,
  }) : _remoteDataSource = remoteDataSource,
       _pushTokenProvider = pushTokenProvider;

  final NotificationRemoteDataSource _remoteDataSource;
  final PushTokenProvider _pushTokenProvider;

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

    await _remoteDataSource.registerPushToken(
      accessToken: accessToken,
      token: token,
    );
  }
}
