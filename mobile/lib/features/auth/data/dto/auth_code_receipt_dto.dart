import 'package:production_chat_app/features/auth/domain/entities/auth_code_purpose.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_code_receipt.dart';

class AuthCodeReceiptDto {
  const AuthCodeReceiptDto({
    required this.identifier,
    required this.purpose,
    required this.debugCode,
    required this.expiresInSeconds,
  });

  factory AuthCodeReceiptDto.fromJson(Map<String, dynamic> json) {
    return AuthCodeReceiptDto(
      identifier: json['identifier']?.toString() ?? '',
      purpose: AuthCodePurposeX.fromWireValue(
        json['purpose']?.toString() ?? 'register',
      ),
      debugCode: json['debugCode']?.toString() ?? '',
      expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  final String identifier;
  final AuthCodePurpose purpose;
  final String debugCode;
  final int expiresInSeconds;

  AuthCodeReceipt toEntity() {
    return AuthCodeReceipt(
      identifier: identifier,
      purpose: purpose,
      debugCode: debugCode,
      expiresInSeconds: expiresInSeconds,
    );
  }
}
