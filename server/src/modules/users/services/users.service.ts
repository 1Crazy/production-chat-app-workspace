import { Injectable } from '@nestjs/common';

import type { UpdateMyProfileDto } from '../dto/update-my-profile.dto';
import type { DiscoverableUserDto, UserProfileDto } from '../dto/user-profile.dto';
import {
  toUserDiscoveryProfileDto,
  toUserProfileDto,
} from '../dto/user-profile.dto';

import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';

@Injectable()
export class UsersService {
  constructor(
    private readonly authIdentityService: AuthIdentityService,
  ) {}

  getHealth(): { module: string; status: string } {
    return {
      module: 'users',
      status: 'ready',
    };
  }

  getMyProfile(userId: string): UserProfileDto {
    return toUserProfileDto(this.authIdentityService.getActiveUserById(userId));
  }

  updateMyProfile(
    userId: string,
    dto: UpdateMyProfileDto,
  ): UserProfileDto {
    return toUserProfileDto(
      this.authIdentityService.updateProfile(userId, {
        nickname: dto.nickname?.trim(),
        avatarUrl: dto.avatarUrl?.trim() || dto.avatarUrl,
        discoveryMode: dto.discoveryMode,
      }),
    );
  }

  discoverByHandle(
    requesterUserId: string,
    handle: string,
  ): DiscoverableUserDto {
    const user = this.authIdentityService.findDiscoverableUserByHandle(
      handle.trim(),
    );

    if (!user) {
      return {
        discoverable: false,
        profile: null,
      };
    }

    if (user.id !== requesterUserId && user.discoveryMode === 'private') {
      return {
        discoverable: false,
        profile: null,
      };
    }

    return {
      discoverable: true,
      profile: toUserDiscoveryProfileDto(user),
    };
  }
}
