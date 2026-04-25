import 'package:production_chat_app/features/auth/domain/entities/auth_code_purpose.dart';

class AuthCodeReceipt {
  const AuthCodeReceipt({
    required this.identifier,
    required this.purpose,
    this.debugCode,
    required this.expiresInSeconds,
  });

  final String identifier;
  final AuthCodePurpose purpose;
  final String? debugCode;
  final int expiresInSeconds;
}
