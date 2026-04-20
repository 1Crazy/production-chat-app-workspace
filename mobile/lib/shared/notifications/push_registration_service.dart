abstract class PushRegistrationService {
  Future<void> syncPushRegistration({required String accessToken});

  Stream<void> get tokenRefreshStream;
}
