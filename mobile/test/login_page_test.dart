import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:production_chat_app/features/auth/application/auth_controller.dart';
import 'package:production_chat_app/features/auth/application/auth_scope.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_code_purpose.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_code_receipt.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_session.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_user.dart';
import 'package:production_chat_app/features/auth/domain/entities/device_session.dart';
import 'package:production_chat_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:production_chat_app/features/auth/presentation/pages/login_page.dart';
import 'package:production_chat_app/shared/notifications/push_registration_service.dart';

void main() {
  testWidgets('login page requests code and fills the debug code', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository();
    final controller = AuthController(
      authRepository: authRepository,
      pushRegistrationService: _FakePushRegistrationService(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScope(controller: controller, child: const LoginPage()),
      ),
    );

    await tester.tap(find.text('注册'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).at(0), 'demo_user');
    await tester.enterText(find.byType(TextField).at(2), 'Demo12345');
    await tester.tap(find.text('获取验证码'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await tester.pump(const Duration(milliseconds: 300));

    expect(authRepository.requestedIdentifiers, ['demo_user']);
    expect(authRepository.requestedPurposes, [AuthCodePurpose.register]);
    expect(find.text('测试注册验证码：246810'), findsOneWidget);
  });

  testWidgets(
    'login page does not autofill code when backend hides debug code',
    (tester) async {
      final authRepository = _FakeAuthRepository(debugCode: null);
      final controller = AuthController(
        authRepository: authRepository,
        pushRegistrationService: _FakePushRegistrationService(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AuthScope(controller: controller, child: const LoginPage()),
        ),
      );

      await tester.tap(find.text('注册'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.enterText(find.byType(TextField).at(0), 'demo_user');
      await tester.enterText(find.byType(TextField).at(2), 'Demo12345');
      await tester.tap(find.text('获取验证码'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(authRepository.requestedIdentifiers, ['demo_user']);
      expect(find.text('注册验证码已发送'), findsOneWidget);
      expect(find.text('测试注册验证码：246810'), findsNothing);
    },
  );

  testWidgets('login page shows repository errors from login attempts', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository(loginError: Exception('登录失败'));
    final controller = AuthController(
      authRepository: authRepository,
      pushRegistrationService: _FakePushRegistrationService(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScope(controller: controller, child: const LoginPage()),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'demo_user');
    await tester.enterText(find.byType(TextField).at(1), 'demo12345');
    await tester.tap(find.widgetWithText(FilledButton, '登录'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('登录失败'), findsOneWidget);
  });

  testWidgets('login page can reset password and return to login mode', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository();
    final controller = AuthController(
      authRepository: authRepository,
      pushRegistrationService: _FakePushRegistrationService(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScope(controller: controller, child: const LoginPage()),
      ),
    );

    await tester.tap(find.text('忘记密码？'));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField).at(0), 'demo_user');
    await tester.enterText(find.byType(TextField).at(1), 'Reset1234');
    await tester.tap(find.text('获取验证码'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).at(2), '246810');
    await tester.tap(find.text('确认重置密码'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      authRepository.requestedPurposes.last,
      AuthCodePurpose.resetPassword,
    );
    expect(authRepository.resetPasswordCalls, 1);
    expect(find.text('密码已重置，请使用新密码登录'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '登录'), findsOneWidget);
  });

  testWidgets('login page blocks code request until password format is valid', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository();
    final controller = AuthController(
      authRepository: authRepository,
      pushRegistrationService: _FakePushRegistrationService(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScope(controller: controller, child: const LoginPage()),
      ),
    );

    await tester.tap(find.text('注册'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField).at(0), 'demo_user');
    await tester.enterText(find.byType(TextField).at(2), 'short');

    await tester.tap(find.text('获取验证码'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(authRepository.requestedIdentifiers, isEmpty);
    expect(find.text('请先输入至少 8 位的密码，再获取验证码'), findsOneWidget);
  });

  testWidgets('login page clears input values when switching modes', (
    tester,
  ) async {
    final authRepository = _FakeAuthRepository();
    final controller = AuthController(
      authRepository: authRepository,
      pushRegistrationService: _FakePushRegistrationService(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: AuthScope(controller: controller, child: const LoginPage()),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'demo_user');
    await tester.enterText(find.byType(TextField).at(1), 'Demo1234');

    await tester.tap(find.text('注册'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('demo_user'), findsNothing);
    expect(find.text('Demo1234'), findsNothing);
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.loginError, this.debugCode = '246810'});

  final Object? loginError;
  final String? debugCode;
  final List<String> requestedIdentifiers = [];
  final List<AuthCodePurpose> requestedPurposes = [];
  int resetPasswordCalls = 0;

  @override
  Future<void> clear() async {}

  @override
  Future<AuthSession> login({
    required String identifier,
    required String password,
    String? deviceName,
  }) async {
    if (loginError != null) {
      throw loginError!;
    }

    return _buildSession(deviceName: deviceName ?? 'flutter-mobile');
  }

  @override
  Future<List<DeviceSession>> listSessions({
    required String accessToken,
  }) async {
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
    required String password,
    required String nickname,
    String? deviceName,
  }) async {
    return _buildSession(deviceName: deviceName ?? 'flutter-mobile');
  }

  @override
  Future<AuthCodeReceipt> requestCode({
    required String identifier,
    required AuthCodePurpose purpose,
  }) async {
    requestedIdentifiers.add(identifier);
    requestedPurposes.add(purpose);
    return AuthCodeReceipt(
      identifier: 'demo_user',
      purpose: purpose,
      debugCode: debugCode,
      expiresInSeconds: 600,
    );
  }

  @override
  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String password,
  }) async {
    resetPasswordCalls += 1;
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
