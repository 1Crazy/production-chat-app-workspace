class AuthCodeReceipt {
  const AuthCodeReceipt({
    required this.identifier,
    required this.debugCode,
    required this.expiresInSeconds,
  });

  final String identifier;
  final String debugCode;
  final int expiresInSeconds;
}
