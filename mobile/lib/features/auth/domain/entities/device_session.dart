class DeviceSession {
  const DeviceSession({
    required this.id,
    required this.deviceName,
    required this.createdAt,
    required this.lastSeenAt,
    required this.isCurrent,
  });

  final String id;
  final String deviceName;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final bool isCurrent;
}
