import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:production_chat_app/features/auth/application/auth_controller.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_code_purpose.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_code_receipt.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_session.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_user.dart';
import 'package:production_chat_app/features/auth/domain/entities/device_session.dart';
import 'package:production_chat_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:production_chat_app/shared/notifications/push_registration_service.dart';

void main() {
  test(
    'auth controller ignores duplicate logout while request is in flight',
    () async {
      final authRepository = _FakeAuthRepository();
      final controller = AuthController(
        authRepository: authRepository,
        pushRegistrationService: _FakePushRegistrationService(),
      );

      await controller.bootstrap();

      final firstLogout = controller.logout();
      final secondLogout = controller.logout();

      expect(authRepository.logoutCalls, 1);

      authRepository.completeLogout();
      await Future.wait([firstLogout, secondLogout]);

      expect(controller.authSession, isNull);
    },
  );

  test(
    'auth controller clears local session when current session is revoked remotely',
    () async {
      final authRepository = _FakeAuthRepository();
      final controller = AuthController(
        authRepository: authRepository,
        pushRegistrationService: _FakePushRegistrationService(),
      );

      await controller.bootstrap();
      await controller.handleSessionRevoked();

      expect(authRepository.logoutCalls, 0);
      expect(controller.authSession, isNull);
      expect(controller.errorMessage, '当前设备已退出登录');
    },
  );
}

class _FakeAuthRepository implements AuthRepository {
  final Completer<void> _logoutCompleter = Completer<void>();
  int logoutCalls = 0;

  void completeLogout() {
    if (!_logoutCompleter.isCompleted) {
      _logoutCompleter.complete();
    }
  }

  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
    String? deviceName,
  }) async {
    return _session;
  }

  @override
  Future<List<DeviceSession>> listSessions({
    required String accessToken,
  }) async {
    return [_session.currentSession];
  }

  @override
  Future<void> logout({required String accessToken}) async {
    logoutCalls += 1;
    await _logoutCompleter.future;
  }

  @override
  Future<AuthSession> refresh({required String refreshToken}) async {
    return _session;
  }

  @override
  Future<AuthSession> register({
    required String identifier,
    required String code,
    required String password,
    required String nickname,
    String? deviceName,
  }) async {
    return _session;
  }

  @override
  Future<AuthCodeReceipt> requestCode({
    required String identifier,
    required AuthCodePurpose purpose,
  }) async {
    return AuthCodeReceipt(
      identifier: identifier,
      purpose: purpose,
      debugCode: '246810',
      expiresInSeconds: 600,
    );
  }

  @override
  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String password,
  }) async {}

  @override
  Future<void> revokeSession({
    required String accessToken,
    required String sessionId,
  }) async {}

  @override
  Future<AuthSession?> restore() async {
    return _session;
  }

  static final AuthSession _session = AuthSession(
    accessToken: 'access-token',
    refreshToken: 'refresh-token',
    user: const AuthUser(
      id: 'user-1',
      identifier: 'demo_user',
      nickname: 'Demo User',
      handle: 'demo_user',
      avatarUrl: null,
      discoveryMode: 'public',
    ),
    currentSession: DeviceSession(
      id: 'session-1',
      deviceName: 'flutter-web',
      createdAt: DateTime(2026, 1, 1),
      lastSeenAt: DateTime(2026, 1, 1),
      isCurrent: true,
    ),
  );
}

class _FakePushRegistrationService implements PushRegistrationService {
  final StreamController<void> _streamController =
      StreamController<void>.broadcast();

  @override
  Future<bool> loadPrivacyModeEnabled() async => false;

  @override
  Future<void> syncPushRegistration({required String accessToken}) async {}

  @override
  Stream<void> get tokenRefreshStream => _streamController.stream;

  @override
  Future<void> updatePrivacyMode({
    required bool enabled,
    String? accessToken,
  }) async {}
}
