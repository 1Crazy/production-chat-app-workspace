import { Injectable } from '@nestjs/common';

import type { UpdateMyProfileDto } from '../dto/update-my-profile.dto';
import type { DiscoverableUserDto, UserProfileDto } from '../dto/user-profile.dto';
import {
  toUserDiscoveryProfileDto,
  toUserProfileDto,
} from '../dto/user-profile.dto';

import { RateLimitService } from '@app/infra/abuse/services/rate-limit.service';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import { toFriendshipRelationshipView } from '@app/modules/friendships/dto/friendship.dto';
import { FriendshipsService } from '@app/modules/friendships/services/friendships.service';

@Injectable()
export class UsersService {
  constructor(
    private readonly authIdentityService: AuthIdentityService,
    private readonly friendshipsService: FriendshipsService,
    private readonly rateLimitService: RateLimitService,
  ) {}

  getHealth(): { module: string; status: string } {
    return {
      module: 'users',
      status: 'ready',
    };
  }

  async getMyProfile(userId: string): Promise<UserProfileDto> {
    return toUserProfileDto(await this.authIdentityService.getActiveUserById(userId));
  }

  async updateMyProfile(
    userId: string,
    dto: UpdateMyProfileDto,
  ): Promise<UserProfileDto> {
    return toUserProfileDto(
      await this.authIdentityService.updateProfile(userId, {
        nickname: dto.nickname?.trim(),
        avatarUrl: dto.avatarUrl?.trim() || dto.avatarUrl,
        discoveryMode: dto.discoveryMode,
      }),
    );
  }

  async discoverByHandle(
    requesterUserId: string,
    handle: string,
  ): Promise<DiscoverableUserDto> {
    await this.rateLimitService.consumeOrThrow({
      scope: 'users.discovery',
      actorKey: requesterUserId,
      limit: 30,
      windowMs: 60 * 1000,
      message: '搜索过于频繁，请稍后再试',
      metadata: {
        handle: handle.trim().toLowerCase(),
      },
    });
    const user = await this.authIdentityService.findDiscoverableUserByHandle(
      handle.trim(),
    );

    if (!user) {
      return {
        discoverable: false,
        profile: null,
        relationship: toFriendshipRelationshipView({
          status: 'none',
        }),
      };
    }

    const relationship = await this.friendshipsService.getRelationshipByUserIds(
      requesterUserId,
      user.id,
    );

    if (
      user.id !== requesterUserId &&
      user.discoveryMode === 'private' &&
      relationship.status === 'none'
    ) {
      return {
        discoverable: false,
        profile: null,
        relationship,
      };
    }

    return {
      discoverable: true,
      profile: toUserDiscoveryProfileDto(user),
      relationship,
    };
  }
}
