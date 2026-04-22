abstract class PushRegistrationService {
  Future<void> syncPushRegistration({required String accessToken});

  Stream<void> get tokenRefreshStream;

  Future<bool> loadPrivacyModeEnabled();

  Future<void> updatePrivacyMode({
    required bool enabled,
    String? accessToken,
  });
}
