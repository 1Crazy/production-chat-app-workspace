import type { FriendRequestEntity } from '../entities/friend-request.entity';
import type { FriendshipEntity } from '../entities/friendship.entity';

export abstract class FriendshipRepository {
  abstract createFriendRequest(params: {
    requesterId: string;
    addresseeId: string;
    message?: string | null;
  }): Promise<FriendRequestEntity>;

  abstract saveFriendRequest(entity: FriendRequestEntity): Promise<void>;

  abstract findFriendRequestById(
    requestId: string,
  ): Promise<FriendRequestEntity | null>;

  abstract findPendingRequestBetween(params: {
    leftUserId: string;
    rightUserId: string;
  }): Promise<FriendRequestEntity | null>;

  abstract listIncomingPendingRequests(
    userId: string,
  ): Promise<FriendRequestEntity[]>;

  abstract listIncomingRequests(
    userId: string,
  ): Promise<FriendRequestEntity[]>;

  abstract countIncomingPendingRequestsAfter(params: {
    userId: string;
    after?: Date | null;
  }): Promise<number>;

  abstract listOutgoingRequests(
    userId: string,
  ): Promise<FriendRequestEntity[]>;

  abstract ignoreIncomingRequest(params: {
    userId: string;
    requestId: string;
  }): Promise<boolean>;

  abstract createFriendship(params: {
    userId: string;
    friendUserId: string;
  }): Promise<FriendshipEntity>;

  abstract findFriendshipByUserIds(params: {
    userId: string;
    friendUserId: string;
  }): Promise<FriendshipEntity | null>;

  abstract listFriendshipsForUser(userId: string): Promise<FriendshipEntity[]>;

  abstract deleteFriendshipByUserIds(params: {
    userId: string;
    friendUserId: string;
  }): Promise<boolean>;
}
