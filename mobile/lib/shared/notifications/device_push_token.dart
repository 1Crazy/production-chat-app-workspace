class DevicePushToken {
  const DevicePushToken({
    required this.provider,
    required this.token,
    required this.pushEnvironment,
  });

  factory DevicePushToken.fromJson(Map<Object?, Object?> json) {
    return DevicePushToken(
      provider: json['provider'] as String,
      token: json['token'] as String,
      pushEnvironment: json['pushEnvironment'] as String,
    );
  }

  final String provider;
  final String token;
  final String pushEnvironment;
}
