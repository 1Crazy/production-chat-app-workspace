import 'package:production_chat_app/shared/network/api_client.dart';
import 'package:production_chat_app/shared/notifications/device_push_token.dart';
import 'package:production_chat_app/shared/notifications/notification_sync_state.dart';

class NotificationRemoteDataSource {
  const NotificationRemoteDataSource({required ApiClient apiClient})
    : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<void> registerPushToken({
    required String accessToken,
    required DevicePushToken token,
    required bool privacyModeEnabled,
  }) async {
    await _apiClient.postJson(
      '/notifications/push-registrations',
      accessToken: accessToken,
      body: {
        'provider': token.provider,
        'token': token.token,
        'pushEnvironment': token.pushEnvironment,
        'privacyModeEnabled': privacyModeEnabled,
      },
    );
  }

  Future<NotificationSyncState> syncState({
    required String accessToken,
    required List<Map<String, Object?>> conversationStates,
    String? pushMessageId,
  }) async {
    final response = await _apiClient.postJson(
      '/notifications/sync-state',
      accessToken: accessToken,
      body: {
        'conversationStates': conversationStates,
        if (pushMessageId != null && pushMessageId.isNotEmpty)
          'pushMessageId': pushMessageId,
      },
    );

    return NotificationSyncState.fromJson(response);
  }
}
