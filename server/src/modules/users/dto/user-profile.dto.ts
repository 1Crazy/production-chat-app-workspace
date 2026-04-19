import type { AuthUserEntity } from '@app/modules/auth/entities/auth-user.entity';

export interface UserProfileDto {
  id: string;
  identifier: string;
  nickname: string;
  handle: string;
  avatarUrl: string | null;
  discoveryMode: 'public' | 'private';
}

export interface DiscoverableUserDto {
  discoverable: boolean;
  profile: UserDiscoveryProfileDto | null;
}

export interface UserDiscoveryProfileDto {
  id: string;
  nickname: string;
  handle: string;
  avatarUrl: string | null;
}

export function toUserProfileDto(user: AuthUserEntity): UserProfileDto {
  return {
    id: user.id,
    identifier: user.identifier,
    nickname: user.nickname,
    handle: user.handle,
    avatarUrl: user.avatarUrl,
    discoveryMode: user.discoveryMode,
  };
}

export function toUserDiscoveryProfileDto(
  user: AuthUserEntity,
): UserDiscoveryProfileDto {
  return {
    id: user.id,
    nickname: user.nickname,
    handle: user.handle,
    avatarUrl: user.avatarUrl,
  };
}
