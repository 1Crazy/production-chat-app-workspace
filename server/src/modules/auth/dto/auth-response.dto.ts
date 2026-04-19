import type { AuthUserEntity } from '../entities/auth-user.entity';
import type { DeviceSessionEntity } from '../entities/device-session.entity';

export interface AuthResponseDto {
  accessToken: string;
  refreshToken: string;
  user: AuthUserView;
  currentSession: DeviceSessionView;
}

export interface AuthUserView {
  id: string;
  identifier: string;
  nickname: string;
  handle: string;
  avatarUrl: string | null;
  discoveryMode: 'public' | 'private';
}

export interface DeviceSessionView {
  id: string;
  deviceName: string;
  createdAt: string;
  lastSeenAt: string;
  isCurrent: boolean;
}

export function toAuthUserView(user: AuthUserEntity): AuthUserView {
  return {
    id: user.id,
    identifier: user.identifier,
    nickname: user.nickname,
    handle: user.handle,
    avatarUrl: user.avatarUrl,
    discoveryMode: user.discoveryMode,
  };
}

export function toDeviceSessionView(
  session: DeviceSessionEntity,
  currentSessionId: string,
): DeviceSessionView {
  return {
    id: session.id,
    deviceName: session.deviceName,
    createdAt: session.createdAt.toISOString(),
    lastSeenAt: session.lastSeenAt.toISOString(),
    isCurrent: session.id === currentSessionId,
  };
}
