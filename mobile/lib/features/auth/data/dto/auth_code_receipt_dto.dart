import 'package:production_chat_app/features/auth/domain/entities/auth_code_receipt.dart';

class AuthCodeReceiptDto {
  const AuthCodeReceiptDto({
    required this.identifier,
    required this.debugCode,
    required this.expiresInSeconds,
  });

  factory AuthCodeReceiptDto.fromJson(Map<String, dynamic> json) {
    return AuthCodeReceiptDto(
      identifier: json['identifier']?.toString() ?? '',
      debugCode: json['debugCode']?.toString() ?? '',
      expiresInSeconds: (json['expiresInSeconds'] as num?)?.toInt() ?? 0,
    );
  }

  final String identifier;
  final String debugCode;
  final int expiresInSeconds;

  AuthCodeReceipt toEntity() {
    return AuthCodeReceipt(
      identifier: identifier,
      debugCode: debugCode,
      expiresInSeconds: expiresInSeconds,
    );
  }
}
