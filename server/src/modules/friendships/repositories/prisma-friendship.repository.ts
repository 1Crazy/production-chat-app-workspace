import { Injectable } from '@nestjs/common';
import type { FriendRequest, Friendship } from '@prisma/client';

import type { FriendRequestEntity } from '../entities/friend-request.entity';
import {
  normalizeFriendshipPair,
  type FriendshipEntity,
} from '../entities/friendship.entity';

import { FriendshipRepository } from './friendship.repository';

import { PrismaService } from '@app/infra/database/prisma.service';

@Injectable()
export class PrismaFriendshipRepository extends FriendshipRepository {
  constructor(private readonly prismaService: PrismaService) {
    super();
  }

  override async createFriendRequest(params: {
    requesterId: string;
    addresseeId: string;
    message?: string | null;
  }): Promise<FriendRequestEntity> {
    const request = await this.prismaService.friendRequest.create({
      data: {
        requesterId: params.requesterId,
        addresseeId: params.addresseeId,
        message: params.message ?? null,
        ignoredByAddresseeAt: null,
      },
    });

    return this.toFriendRequestEntity(request);
  }

  override async saveFriendRequest(entity: FriendRequestEntity): Promise<void> {
    await this.prismaService.friendRequest.update({
      where: {
        id: entity.id,
      },
      data: {
        status: entity.status,
        message: entity.message,
        respondedAt: entity.respondedAt,
        ignoredByAddresseeAt: entity.ignoredByAddresseeAt,
      },
    });
  }

  override async findFriendRequestById(
    requestId: string,
  ): Promise<FriendRequestEntity | null> {
    const request = await this.prismaService.friendRequest.findUnique({
      where: {
        id: requestId,
      },
    });

    return request ? this.toFriendRequestEntity(request) : null;
  }

  override async findPendingRequestBetween(params: {
    leftUserId: string;
    rightUserId: string;
  }): Promise<FriendRequestEntity | null> {
    const request = await this.prismaService.friendRequest.findFirst({
      where: {
        status: 'pending',
        OR: [
          {
            ignoredByAddresseeAt: null,
            requesterId: params.leftUserId,
            addresseeId: params.rightUserId,
          },
          {
            ignoredByAddresseeAt: null,
            requesterId: params.rightUserId,
            addresseeId: params.leftUserId,
          },
        ],
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return request ? this.toFriendRequestEntity(request) : null;
  }

  override async listIncomingPendingRequests(
    userId: string,
  ): Promise<FriendRequestEntity[]> {
    const requests = await this.prismaService.friendRequest.findMany({
      where: {
        addresseeId: userId,
        status: 'pending',
        ignoredByAddresseeAt: null,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return requests.map((request) => this.toFriendRequestEntity(request));
  }

  override async listIncomingRequests(
    userId: string,
  ): Promise<FriendRequestEntity[]> {
    const requests = await this.prismaService.friendRequest.findMany({
      where: {
        addresseeId: userId,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return requests.map((request) => this.toFriendRequestEntity(request));
  }

  override async countIncomingPendingRequestsAfter(params: {
    userId: string;
    after?: Date | null;
  }): Promise<number> {
    return this.prismaService.friendRequest.count({
      where: {
        addresseeId: params.userId,
        status: 'pending',
        ignoredByAddresseeAt: null,
        ...(params.after != null
            ? {
                createdAt: {
                  gt: params.after,
                },
              }
            : {}),
      },
    });
  }

  override async listOutgoingRequests(
    userId: string,
  ): Promise<FriendRequestEntity[]> {
    const requests = await this.prismaService.friendRequest.findMany({
      where: {
        requesterId: userId,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return requests.map((request) => this.toFriendRequestEntity(request));
  }

  override async ignoreIncomingRequest(params: {
    userId: string;
    requestId: string;
  }): Promise<boolean> {
    const updated = await this.prismaService.friendRequest.updateMany({
      where: {
        id: params.requestId,
        addresseeId: params.userId,
        status: 'pending',
        ignoredByAddresseeAt: null,
      },
      data: {
        ignoredByAddresseeAt: new Date(),
      },
    });

    return updated.count > 0;
  }

  override async createFriendship(params: {
    userId: string;
    friendUserId: string;
  }): Promise<FriendshipEntity> {
    const pair = normalizeFriendshipPair(params.userId, params.friendUserId);
    const friendship = await this.prismaService.friendship.upsert({
      where: {
        userAId_userBId: pair,
      },
      update: {},
      create: pair,
    });

    return this.toFriendshipEntity(friendship);
  }

  override async findFriendshipByUserIds(params: {
    userId: string;
    friendUserId: string;
  }): Promise<FriendshipEntity | null> {
    const pair = normalizeFriendshipPair(params.userId, params.friendUserId);
    const friendship = await this.prismaService.friendship.findUnique({
      where: {
        userAId_userBId: pair,
      },
    });

    return friendship ? this.toFriendshipEntity(friendship) : null;
  }

  override async listFriendshipsForUser(
    userId: string,
  ): Promise<FriendshipEntity[]> {
    const friendships = await this.prismaService.friendship.findMany({
      where: {
        OR: [{ userAId: userId }, { userBId: userId }],
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return friendships.map((item) => this.toFriendshipEntity(item));
  }

  override async deleteFriendshipByUserIds(params: {
    userId: string;
    friendUserId: string;
  }): Promise<boolean> {
    const pair = normalizeFriendshipPair(params.userId, params.friendUserId);
    const deleted = await this.prismaService.friendship.deleteMany({
      where: pair,
    });

    return deleted.count > 0;
  }

  private toFriendRequestEntity(request: FriendRequest): FriendRequestEntity {
    return {
      id: request.id,
      requesterId: request.requesterId,
      addresseeId: request.addresseeId,
      status: request.status as FriendRequestEntity['status'],
      message: request.message,
      createdAt: request.createdAt,
      updatedAt: request.updatedAt,
      respondedAt: request.respondedAt,
      ignoredByAddresseeAt: request.ignoredByAddresseeAt,
    };
  }

  private toFriendshipEntity(friendship: Friendship): FriendshipEntity {
    return {
      id: friendship.id,
      userAId: friendship.userAId,
      userBId: friendship.userBId,
      createdAt: friendship.createdAt,
    };
  }
}
