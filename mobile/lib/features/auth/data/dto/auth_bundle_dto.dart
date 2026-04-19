import 'package:production_chat_app/features/auth/data/dto/device_session_dto.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_session.dart';
import 'package:production_chat_app/features/auth/domain/entities/auth_user.dart';

class AuthBundleDto {
  const AuthBundleDto({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
    required this.currentSession,
  });

  factory AuthBundleDto.fromJson(Map<String, dynamic> json) {
    return AuthBundleDto(
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      user: AuthUserDto.fromJson(json['user'] as Map<String, dynamic>),
      currentSession: DeviceSessionDto.fromJson(
        json['currentSession'] as Map<String, dynamic>,
      ),
    );
  }

  final String accessToken;
  final String refreshToken;
  final AuthUserDto user;
  final DeviceSessionDto currentSession;

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'user': user.toJson(),
      'currentSession': currentSession.toJson(),
    };
  }

  AuthSession toEntity() {
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken,
      user: user.toEntity(),
      currentSession: currentSession.toEntity(),
    );
  }

  factory AuthBundleDto.fromEntity(AuthSession entity) {
    return AuthBundleDto(
      accessToken: entity.accessToken,
      refreshToken: entity.refreshToken,
      user: AuthUserDto.fromEntity(entity.user),
      currentSession: DeviceSessionDto.fromEntity(entity.currentSession),
    );
  }
}

class AuthUserDto {
  const AuthUserDto({
    required this.id,
    required this.identifier,
    required this.nickname,
    required this.handle,
    required this.avatarUrl,
    required this.discoveryMode,
  });

  factory AuthUserDto.fromJson(Map<String, dynamic> json) {
    return AuthUserDto(
      id: json['id']?.toString() ?? '',
      identifier: json['identifier']?.toString() ?? '',
      nickname: json['nickname']?.toString() ?? '',
      handle: json['handle']?.toString() ?? '',
      avatarUrl: json['avatarUrl']?.toString(),
      discoveryMode: json['discoveryMode']?.toString() ?? 'public',
    );
  }

  final String id;
  final String identifier;
  final String nickname;
  final String handle;
  final String? avatarUrl;
  final String discoveryMode;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'identifier': identifier,
      'nickname': nickname,
      'handle': handle,
      'avatarUrl': avatarUrl,
      'discoveryMode': discoveryMode,
    };
  }

  AuthUser toEntity() {
    return AuthUser(
      id: id,
      identifier: identifier,
      nickname: nickname,
      handle: handle,
      avatarUrl: avatarUrl,
      discoveryMode: discoveryMode,
    );
  }

  factory AuthUserDto.fromEntity(AuthUser entity) {
    return AuthUserDto(
      id: entity.id,
      identifier: entity.identifier,
      nickname: entity.nickname,
      handle: entity.handle,
      avatarUrl: entity.avatarUrl,
      discoveryMode: entity.discoveryMode,
    );
  }
}
