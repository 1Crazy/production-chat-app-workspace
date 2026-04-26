import { randomUUID } from 'node:crypto';

import type { FriendRequestEntity } from '../entities/friend-request.entity';
import {
  normalizeFriendshipPair,
  type FriendshipEntity,
} from '../entities/friendship.entity';

import { FriendshipRepository } from './friendship.repository';

export class InMemoryFriendshipRepository extends FriendshipRepository {
  private readonly requestsById = new Map<string, FriendRequestEntity>();
  private readonly friendshipsByKey = new Map<string, FriendshipEntity>();

  override async createFriendRequest(params: {
    requesterId: string;
    addresseeId: string;
    message?: string | null;
  }): Promise<FriendRequestEntity> {
    const now = new Date();
    const request: FriendRequestEntity = {
      id: randomUUID(),
      requesterId: params.requesterId,
      addresseeId: params.addresseeId,
      status: 'pending',
      message: params.message ?? null,
      rejectReason: null,
      createdAt: now,
      updatedAt: now,
      respondedAt: null,
      ignoredByAddresseeAt: null,
      hiddenByRequesterAt: null,
      hiddenByAddresseeAt: null,
    };

    this.requestsById.set(request.id, request);
    return request;
  }

  override async saveFriendRequest(entity: FriendRequestEntity): Promise<void> {
    entity.updatedAt = new Date();
    this.requestsById.set(entity.id, entity);
  }

  override async findFriendRequestById(
    requestId: string,
  ): Promise<FriendRequestEntity | null> {
    return this.requestsById.get(requestId) ?? null;
  }

  override async findPendingRequestBetween(params: {
    leftUserId: string;
    rightUserId: string;
  }): Promise<FriendRequestEntity | null> {
    const requests = Array.from(this.requestsById.values())
      .filter((request) => {
        if (request.status !== 'pending') {
          return false;
        }

        return (
          request.ignoredByAddresseeAt == null &&
          ((request.requesterId === params.leftUserId &&
                request.addresseeId === params.rightUserId) ||
              (request.requesterId === params.rightUserId &&
                request.addresseeId === params.leftUserId))
        );
      })
      .sort((left, right) => {
        return right.createdAt.getTime() - left.createdAt.getTime();
      });

    return requests[0] ?? null;
  }

  override async listIncomingPendingRequests(
    userId: string,
  ): Promise<FriendRequestEntity[]> {
    return Array.from(this.requestsById.values())
      .filter((request) => {
        return request.addresseeId === userId &&
            request.status === 'pending' &&
            request.ignoredByAddresseeAt == null &&
            request.hiddenByAddresseeAt == null;
      })
      .sort((left, right) => {
        return right.createdAt.getTime() - left.createdAt.getTime();
      });
  }

  override async listIncomingRequests(
    userId: string,
  ): Promise<FriendRequestEntity[]> {
    return Array.from(this.requestsById.values())
      .filter((request) => {
        return request.addresseeId === userId;
      })
      .filter((request) => {
        return request.hiddenByAddresseeAt == null;
      })
      .sort((left, right) => {
        return right.createdAt.getTime() - left.createdAt.getTime();
      });
  }

  override async countIncomingPendingRequestsAfter(params: {
    userId: string;
    after?: Date | null;
  }): Promise<number> {
    return Array.from(this.requestsById.values()).filter((request) => {
      return request.addresseeId === params.userId &&
          request.status === 'pending' &&
          request.ignoredByAddresseeAt == null &&
          (params.after == null ||
              request.createdAt.getTime() > params.after.getTime());
    }).length;
  }

  override async listOutgoingRequests(
    userId: string,
  ): Promise<FriendRequestEntity[]> {
    return Array.from(this.requestsById.values())
      .filter((request) => {
        return request.requesterId === userId;
      })
      .filter((request) => {
        return request.hiddenByRequesterAt == null;
      })
      .sort((left, right) => {
        return right.createdAt.getTime() - left.createdAt.getTime();
      });
  }

  override async ignoreIncomingRequest(params: {
    userId: string;
    requestId: string;
  }): Promise<boolean> {
    const request = this.requestsById.get(params.requestId);

    if (!request || request.addresseeId != params.userId) {
      return false;
    }

    request.ignoredByAddresseeAt = new Date();
    request.updatedAt = new Date();
    this.requestsById.set(request.id, request);
    return true;
  }

  override async createFriendship(params: {
    userId: string;
    friendUserId: string;
  }): Promise<FriendshipEntity> {
    const pair = normalizeFriendshipPair(params.userId, params.friendUserId);
    const key = this.buildKey(pair.userAId, pair.userBId);
    const existing = this.friendshipsByKey.get(key);

    if (existing) {
      existing.hiddenByUserAAt = null;
      existing.hiddenByUserBAt = null;
      this.friendshipsByKey.set(key, existing);
      return existing;
    }

    const friendship: FriendshipEntity = {
      id: randomUUID(),
      userAId: pair.userAId,
      userBId: pair.userBId,
      hiddenByUserAAt: null,
      hiddenByUserBAt: null,
      createdAt: new Date(),
    };

    this.friendshipsByKey.set(key, friendship);
    return friendship;
  }

  override async saveFriendship(entity: FriendshipEntity): Promise<void> {
    this.friendshipsByKey.set(this.buildKey(entity.userAId, entity.userBId), entity);
  }

  override async findFriendshipByUserIds(params: {
    userId: string;
    friendUserId: string;
  }): Promise<FriendshipEntity | null> {
    const pair = normalizeFriendshipPair(params.userId, params.friendUserId);
    return this.friendshipsByKey.get(this.buildKey(pair.userAId, pair.userBId)) ?? null;
  }

  override async listFriendshipsForUser(
    userId: string,
  ): Promise<FriendshipEntity[]> {
    return Array.from(this.friendshipsByKey.values()).filter((friendship) => {
      if (friendship.userAId === userId) {
        return friendship.hiddenByUserAAt == null;
      }

      if (friendship.userBId === userId) {
        return friendship.hiddenByUserBAt == null;
      }

      return false;
    });
  }

  override async deleteFriendshipByUserIds(params: {
    userId: string;
    friendUserId: string;
  }): Promise<boolean> {
    const pair = normalizeFriendshipPair(params.userId, params.friendUserId);
    const key = this.buildKey(pair.userAId, pair.userBId);
    const friendship = this.friendshipsByKey.get(key);

    if (!friendship) {
      return false;
    }

    if (params.userId === friendship.userAId) {
      friendship.hiddenByUserAAt = new Date();
    } else {
      friendship.hiddenByUserBAt = new Date();
    }

    this.friendshipsByKey.set(key, friendship);
    return true;
  }

  private buildKey(userAId: string, userBId: string): string {
    return `${userAId}:${userBId}`;
  }
}
