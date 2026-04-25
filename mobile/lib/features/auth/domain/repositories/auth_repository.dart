import 'package:production_chat_app/features/auth/domain/entities/auth_code_purpose.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_code_receipt.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_session.dart';
import 'package:production_chat_app/features/auth/domain/entities/device_session.dart';

abstract class AuthRepository {
  Future<AuthCodeReceipt> requestCode({
    required String identifier,
    required AuthCodePurpose purpose,
  });

  Future<AuthSession> register({
    required String identifier,
    required String code,
    required String password,
    required String nickname,
    String? deviceName,
  });

  Future<AuthSession> login({
    required String identifier,
    required String password,
    String? deviceName,
  });

  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String password,
  });

  Future<AuthSession> refresh({required String refreshToken});

  Future<AuthSession?> restore();

  Future<List<DeviceSession>> listSessions({required String accessToken});

  Future<void> revokeSession({
    required String accessToken,
    required String sessionId,
  });

  Future<void> logout({required String accessToken});

  Future<void> clear();
}
