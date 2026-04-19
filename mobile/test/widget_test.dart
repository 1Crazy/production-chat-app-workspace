import 'package:flutter_test/flutter_test.dart';
import 'package:production_chat_app/app/dependencies/app_dependencies.dart';
import 'package:production_chat_app/app/app.dart';
import 'package:production_chat_app/features/auth/application/auth_controller.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_code_receipt.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_session.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_user.dart';
import 'package:production_chat_app/features/auth/domain/entities/device_session.dart';
import 'package:production_chat_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:production_chat_app/features/profile/domain/entities/discoverable_user.dart';
import 'package:production_chat_app/features/profile/domain/entities/user_profile.dart';
import 'package:production_chat_app/features/profile/domain/repositories/profile_repository.dart';
import 'package:production_chat_app/shared/config/app_environment.dart';

void main() {
  testWidgets('app shell renders project name', (tester) async {
    final authController = AuthController(
      authRepository: _FakeAuthRepository(),
    );
    await authController.bootstrap();

    await tester.pumpWidget(
      ProductionChatApp(
        environment: const AppEnvironment(
          appName: 'Production Chat',
          flavor: 'test',
          apiBaseUrl: 'http://localhost:3001',
        ),
        dependencies: AppDependencies(
          authRepository: _FakeAuthRepository(),
          profileRepository: _FakeProfileRepository(),
        ),
        authController: authController,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Production Chat'), findsWidgets);
    expect(find.text('会话'), findsOneWidget);
  });
}

class _FakeAuthRepository implements AuthRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession?> restore() async {
    return _fakeSession();
  }

  @override
  Future<AuthCodeReceipt> requestCode({required String identifier}) async {
    return AuthCodeReceipt(
      identifier: identifier,
      debugCode: '123456',
      expiresInSeconds: 60,
    );
  }

  @override
  Future<AuthSession> register({
    required String identifier,
    required String code,
    required String nickname,
    required String deviceName,
  }) {
    return Future.value(_fakeSession());
  }

  @override
  Future<AuthSession> login({
    required String identifier,
    required String code,
    required String deviceName,
  }) {
    return Future.value(_fakeSession());
  }

  @override
  Future<AuthSession> refresh({required String refreshToken}) {
    return Future.value(_fakeSession());
  }

  @override
  Future<List<DeviceSession>> listSessions({
    required String accessToken,
  }) async {
    return const [];
  }

  @override
  Future<void> logout({required String accessToken}) async {}

  @override
  Future<void> revokeSession({
    required String accessToken,
    required String sessionId,
  }) async {}

  AuthSession _fakeSession() {
    return AuthSession(
      accessToken: 'access',
      refreshToken: 'refresh',
      user: const AuthUser(
        id: 'user-id',
        identifier: 'demo_user',
        nickname: 'Demo User',
        handle: 'demo_user',
        avatarUrl: null,
        discoveryMode: 'public',
      ),
      currentSession: DeviceSession(
        id: 'session-id',
        deviceName: 'test-device',
        createdAt: DateTime(2026, 1, 1),
        lastSeenAt: DateTime(2026, 1, 1),
        isCurrent: true,
      ),
    );
  }
}

class _FakeProfileRepository implements ProfileRepository {
  @override
  Future<DiscoverableUser> discoverByHandle({
    required String accessToken,
    required String handle,
  }) async {
    return const DiscoverableUser(
      discoverable: true,
      profile: DiscoverableProfile(
        id: 'user-id',
        nickname: 'Demo User',
        handle: 'demo_user',
        avatarUrl: null,
      ),
    );
  }

  @override
  Future<UserProfile> fetchCurrent({required String accessToken}) async {
    return const UserProfile(
      id: 'user-id',
      identifier: 'demo_user',
      nickname: 'Demo User',
      handle: 'demo_user',
      avatarUrl: null,
      discoveryMode: 'public',
    );
  }

  @override
  Future<UserProfile> updateCurrent({
    required String accessToken,
    required String nickname,
    required String? avatarUrl,
    required String discoveryMode,
  }) async {
    return UserProfile(
      id: 'user-id',
      identifier: 'demo_user',
      nickname: nickname,
      handle: 'demo_user',
      avatarUrl: avatarUrl,
      discoveryMode: discoveryMode,
    );
  }
}
