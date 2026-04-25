import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_chat_app/features/auth/application/auth_controller.dart';
import 'package:production_chat_app/features/auth/application/auth_scope.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_code_receipt.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_session.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_user.dart';
import 'package:production_chat_app/features/auth/domain/entities/device_session.dart';
import 'package:production_chat_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:production_chat_app/features/auth/presentation/pages/login_page.dart';
import 'package:production_chat_app/shared/notifications/push_registration_service.dart';

void main() {
  testWidgets('login page requests code and fills the debug code', (tester) async {
    final authRepository = _FakeAuthRepository();
    final controller = AuthController(
      authRepository: authRepository,
      pushRegistrationService: _FakePushRegistrationService(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScope(
          controller: controller,
          child: const LoginPage(),
        ),
      ),
    );

    await tester.tap(find.text('获取验证码'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(authRepository.requestedIdentifiers, ['demo_user']);
    expect(find.text('最近一次验证码'), findsOneWidget);
    expect(find.textContaining('账号：demo_user\n验证码：246810'), findsOneWidget);
    expect(find.text('开发验证码：246810'), findsOneWidget);
  });

  testWidgets('login page shows repository errors from login attempts', (tester) async {
    final authRepository = _FakeAuthRepository(loginError: Exception('登录失败'));
    final controller = AuthController(
      authRepository: authRepository,
      pushRegistrationService: _FakePushRegistrationService(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScope(
          controller: controller,
          child: const LoginPage(),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField).at(2), '123456');
    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();

    expect(find.text('Exception: 登录失败'), findsOneWidget);
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.loginError});

  final Object? loginError;
  final List<String> requestedIdentifiers = [];

  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession> login({
    required String identifier,
    required String code,
    required String deviceName,
  }) async {
    if (loginError != null) {
      throw loginError!;
    }

    return _buildSession(deviceName: deviceName);
  }

  @override
  Future<List<DeviceSession>> listSessions({required String accessToken}) async {
    return [
      DeviceSession(
        id: 'session-1',
        deviceName: 'flutter-mobile',
        createdAt: DateTime(2026, 1, 1),
        lastSeenAt: DateTime(2026, 1, 1),
        isCurrent: true,
      ),
    ];
  }

  @override
  Future<void> logout({required String accessToken}) async {}

  @override
  Future<AuthSession> refresh({required String refreshToken}) async {
    return _buildSession(deviceName: 'flutter-mobile');
  }

  @override
  Future<AuthSession> register({
    required String identifier,
    required String code,
    required String nickname,
    required String deviceName,
  }) async {
    return _buildSession(deviceName: deviceName);
  }

  @override
  Future<AuthCodeReceipt> requestCode({required String identifier}) async {
    requestedIdentifiers.add(identifier);
    return const AuthCodeReceipt(
      identifier: 'demo_user',
      debugCode: '246810',
      expiresInSeconds: 600,
    );
  }

  @override
  Future<void> revokeSession({
    required String accessToken,
    required String sessionId,
  }) async {}

  @override
  Future<AuthSession?> restore() async {
    return null;
  }

  AuthSession _buildSession({required String deviceName}) {
    return AuthSession(
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
        deviceName: deviceName,
        createdAt: DateTime(2026, 1, 1),
        lastSeenAt: DateTime(2026, 1, 1),
        isCurrent: true,
      ),
    );
  }
}

class _FakePushRegistrationService implements PushRegistrationService {
  final StreamController<void> _streamController = StreamController<void>.broadcast();

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
