import 'package:production_chat_app/features/auth/domain/entities/auth_user.dart';
import 'package:production_chat_app/features/auth/domain/entities/device_session.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    required this.currentSession,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;
  final DeviceSession currentSession;
}
