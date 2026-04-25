import 'package:production_chat_app/features/auth/domain/entities/device_session.dart';

class DeviceSessionDto {
  const DeviceSessionDto({
    required this.id,
    required this.deviceName,
    required this.createdAt,
    required this.lastSeenAt,
    required this.isCurrent,
  });

  factory DeviceSessionDto.fromJson(Map<String, dynamic> json) {
    return DeviceSessionDto(
      id: json['id']?.toString() ?? '',
      deviceName: json['deviceName']?.toString() ?? 'unknown-device',
      createdAt: _parseToLocal(json['createdAt']?.toString() ?? ''),
      lastSeenAt: _parseToLocal(json['lastSeenAt']?.toString() ?? ''),
      isCurrent: json['isCurrent'] as bool? ?? false,
    );
  }

  final String id;
  final String deviceName;
  final DateTime createdAt;
  final DateTime lastSeenAt;
  final bool isCurrent;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceName': deviceName,
      'createdAt': createdAt.toIso8601String(),
      'lastSeenAt': lastSeenAt.toIso8601String(),
      'isCurrent': isCurrent,
    };
  }

  DeviceSession toEntity() {
    return DeviceSession(
      id: id,
      deviceName: deviceName,
      createdAt: createdAt,
      lastSeenAt: lastSeenAt,
      isCurrent: isCurrent,
    );
  }

  factory DeviceSessionDto.fromEntity(DeviceSession entity) {
    return DeviceSessionDto(
      id: entity.id,
      deviceName: entity.deviceName,
      createdAt: entity.createdAt,
      lastSeenAt: entity.lastSeenAt,
      isCurrent: entity.isCurrent,
    );
  }

  static DateTime _parseToLocal(String rawValue) {
    return DateTime.parse(rawValue).toLocal();
  }
}
