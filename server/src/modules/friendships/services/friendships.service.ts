import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { CreateFriendRequestDto } from '../dto/create-friend-request.dto';
import {
  friendshipStatuses,
  toFriendRequestView,
  toFriendshipRelationshipView,
  toFriendshipView,
  type FriendshipRelationshipView,
} from '../dto/friendship.dto';
import { FriendshipRepository } from '../repositories/friendship.repository';

import { RateLimitService } from '@app/infra/abuse/services/rate-limit.service';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import { toUserDiscoveryProfileDto } from '@app/modules/users/dto/user-profile.dto';

@Injectable()
export class FriendshipsService {
  constructor(
    private readonly friendshipRepository: FriendshipRepository,
    private readonly authIdentityService: AuthIdentityService,
    private readonly rateLimitService: RateLimitService,
  ) {}

  getHealth(): { module: string; status: string } {
    return {
      module: 'friendships',
      status: 'ready',
    };
  }

  async listFriends(userId: string) {
    await this.authIdentityService.getActiveUserById(userId);
    const friendships = await this.friendshipRepository.listFriendshipsForUser(
      userId,
    );

    return Promise.all(
      friendships.map(async (friendship) => {
        const friendUserId =
          friendship.userAId === userId ? friendship.userBId : friendship.userAId;
        const friend = await this.authIdentityService.getActiveUserById(friendUserId);

        return toFriendshipView({
          friendUserId,
          createdAt: friendship.createdAt,
          profile: toUserDiscoveryProfileDto(friend),
        });
      }),
    );
  }

  async listIncomingRequests(userId: string) {
    await this.authIdentityService.getActiveUserById(userId);
    const requests = await this.friendshipRepository.listIncomingRequests(userId);

    return Promise.all(
      requests.map(async (request) => {
        const counterparty = await this.authIdentityService.getActiveUserById(
          request.requesterId,
        );

        return toFriendRequestView({
          request,
          direction: 'incoming',
          counterparty: toUserDiscoveryProfileDto(counterparty),
        });
      }),
    );
  }

  async listOutgoingRequests(userId: string) {
    await this.authIdentityService.getActiveUserById(userId);
    const requests = await this.friendshipRepository.listOutgoingRequests(userId);

    return Promise.all(
      requests.map(async (request) => {
        const counterparty = await this.authIdentityService.getActiveUserById(
          request.addresseeId,
        );

        return toFriendRequestView({
          request,
          direction: 'outgoing',
          counterparty: toUserDiscoveryProfileDto(counterparty),
        });
      }),
    );
  }

  async getUnreadIncomingRequestCount(userId: string): Promise<{
    unreadCount: number;
  }> {
    const user = await this.authIdentityService.getActiveUserById(userId);
    return {
      unreadCount: await this.friendshipRepository.countIncomingPendingRequestsAfter({
        userId,
        after: user.friendRequestLastViewedAt,
      }),
    };
  }

  async createFriendRequest(
    requesterUserId: string,
    dto: CreateFriendRequestDto,
  ) {
    await this.rateLimitService.consumeOrThrow({
      scope: 'friendships.request',
      actorKey: requesterUserId,
      limit: 20,
      windowMs: 60 * 60 * 1000,
      message: '好友申请过于频繁，请稍后再试',
      metadata: {
        targetHandle: dto.targetHandle.trim(),
      },
    });
    const requester =
      await this.authIdentityService.getActiveUserById(requesterUserId);
    const targetUser = await this.authIdentityService.findActiveUserByHandle(
      dto.targetHandle.trim(),
    );

    if (!targetUser) {
      throw new NotFoundException('目标用户不存在或已失效');
    }

    if (targetUser.id === requester.id) {
      throw new BadRequestException('不能添加自己为好友');
    }

    if (targetUser.discoveryMode === 'private') {
      throw new ForbiddenException('目标用户未开放好友添加');
    }

    if (
      await this.friendshipRepository.findFriendshipByUserIds({
        userId: requester.id,
        friendUserId: targetUser.id,
      })
    ) {
      throw new ConflictException('你们已经是好友');
    }

    const pendingRequest =
      await this.friendshipRepository.findPendingRequestBetween({
        leftUserId: requester.id,
        rightUserId: targetUser.id,
      });

    if (pendingRequest) {
      if (pendingRequest.requesterId === requester.id) {
        throw new ConflictException('好友申请已发送，等待对方处理');
      }

      throw new ConflictException('对方已向你发出好友申请，请先处理');
    }

    const request = await this.friendshipRepository.createFriendRequest({
      requesterId: requester.id,
      addresseeId: targetUser.id,
      message: dto.message?.trim() || null,
    });

    return toFriendRequestView({
      request,
      direction: 'outgoing',
      counterparty: toUserDiscoveryProfileDto(targetUser),
    });
  }

  async acceptFriendRequest(userId: string, requestId: string) {
    const request = await this.getPendingIncomingRequestOrThrow(userId, requestId);
    request.status = 'accepted';
    request.respondedAt = new Date();
    await this.friendshipRepository.saveFriendRequest(request);
    await this.friendshipRepository.createFriendship({
      userId: request.requesterId,
      friendUserId: request.addresseeId,
    });

    return {
      success: true,
      requestId,
    };
  }

  async rejectFriendRequest(userId: string, requestId: string) {
    const request = await this.getPendingIncomingRequestOrThrow(userId, requestId);
    request.status = 'rejected';
    request.respondedAt = new Date();
    await this.friendshipRepository.saveFriendRequest(request);

    return {
      success: true,
      requestId,
    };
  }

  async ignoreFriendRequest(userId: string, requestId: string) {
    const request = await this.getPendingIncomingRequestOrThrow(userId, requestId);
    const ignored = await this.friendshipRepository.ignoreIncomingRequest({
      userId,
      requestId: request.id,
    });

    if (!ignored) {
      throw new ConflictException('好友申请已处理');
    }

    return {
      success: true,
      requestId,
    };
  }

  async markRequestsViewed(userId: string): Promise<{ success: boolean }> {
    await this.authIdentityService.markFriendRequestsViewed(userId);
    return {
      success: true,
    };
  }

  async removeFriend(userId: string, friendUserId: string) {
    await this.authIdentityService.getActiveUserById(userId);
    await this.authIdentityService.getActiveUserById(friendUserId);
    const deleted = await this.friendshipRepository.deleteFriendshipByUserIds({
      userId,
      friendUserId,
    });

    if (!deleted) {
      throw new NotFoundException('好友关系不存在');
    }

    return {
      success: true,
      friendUserId,
    };
  }

  async getRelationshipByUserIds(
    requesterUserId: string,
    targetUserId: string,
  ): Promise<FriendshipRelationshipView> {
    if (requesterUserId === targetUserId) {
      return toFriendshipRelationshipView({
        status: friendshipStatuses[0],
      });
    }

    if (
      await this.friendshipRepository.findFriendshipByUserIds({
        userId: requesterUserId,
        friendUserId: targetUserId,
      })
    ) {
      return toFriendshipRelationshipView({
        status: 'friends',
      });
    }

    const pendingRequest =
      await this.friendshipRepository.findPendingRequestBetween({
        leftUserId: requesterUserId,
        rightUserId: targetUserId,
      });

    if (!pendingRequest) {
      return toFriendshipRelationshipView({
        status: 'none',
      });
    }

    return toFriendshipRelationshipView({
      status:
        pendingRequest.requesterId === requesterUserId
          ? 'outgoing_pending'
          : 'incoming_pending',
      pendingRequestId: pendingRequest.id,
    });
  }

  async assertDirectConversationAllowed(
    requesterUserId: string,
    targetUserId: string,
  ): Promise<void> {
    const relationship = await this.getRelationshipByUserIds(
      requesterUserId,
      targetUserId,
    );

    if (relationship.status !== 'friends') {
      throw new ForbiddenException('仅支持与好友发起单聊');
    }
  }

  private async getPendingIncomingRequestOrThrow(
    userId: string,
    requestId: string,
  ) {
    const request = await this.friendshipRepository.findFriendRequestById(
      requestId,
    );

    if (!request || request.addresseeId !== userId) {
      throw new NotFoundException('好友申请不存在');
    }

    if (request.status !== 'pending') {
      throw new ConflictException('好友申请已处理');
    }

    return request;
  }
}
