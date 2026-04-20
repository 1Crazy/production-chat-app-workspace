import 'package:production_chat_app/shared/network/api_client.dart';
import 'package:production_chat_app/shared/notifications/device_push_token.dart';

class NotificationRemoteDataSource {
  const NotificationRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<void> registerPushToken({
    required String accessToken,
    required DevicePushToken token,
  }) async {
    await _apiClient.postJson(
      '/notifications/push-registrations',
      accessToken: accessToken,
      body: {
        'provider': token.provider,
        'token': token.token,
        'pushEnvironment': token.pushEnvironment,
      },
    );
  }
}
