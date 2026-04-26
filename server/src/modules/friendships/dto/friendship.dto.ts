import type { FriendRequestEntity } from '../entities/friend-request.entity';

import type { UserDiscoveryProfileDto } from '@app/modules/users/dto/user-profile.dto';

export const friendshipStatuses = [
  'self',
  'none',
  'outgoing_pending',
  'incoming_pending',
  'friends',
] as const;

export type FriendshipStatus = (typeof friendshipStatuses)[number];

export interface FriendshipRelationshipView {
  status: FriendshipStatus;
  pendingRequestId: string | null;
  canMessage: boolean;
}

export interface FriendshipView {
  friendUserId: string;
  createdAt: string;
  profile: UserDiscoveryProfileDto;
}

export interface FriendRequestView {
  id: string;
  direction: 'incoming' | 'outgoing';
  status: 'pending' | 'accepted' | 'rejected' | 'ignored';
  message: string | null;
  rejectReason: string | null;
  createdAt: string;
  respondedAt: string | null;
  counterparty: UserDiscoveryProfileDto;
}

export function toFriendshipRelationshipView(params: {
  status: FriendshipStatus;
  pendingRequestId?: string | null;
}): FriendshipRelationshipView {
  return {
    status: params.status,
    pendingRequestId: params.pendingRequestId ?? null,
    canMessage: params.status === 'friends',
  };
}

export function toFriendshipView(params: {
  friendUserId: string;
  createdAt: Date;
  profile: UserDiscoveryProfileDto;
}): FriendshipView {
  return {
    friendUserId: params.friendUserId,
    createdAt: params.createdAt.toISOString(),
    profile: params.profile,
  };
}

export function toFriendRequestView(params: {
  request: FriendRequestEntity;
  direction: 'incoming' | 'outgoing';
  counterparty: UserDiscoveryProfileDto;
}): FriendRequestView {
  const effectiveStatus =
    params.direction == 'incoming' &&
        params.request.status == 'pending' &&
        params.request.ignoredByAddresseeAt != null
    ? 'ignored'
    : params.request.status;

  return {
    id: params.request.id,
    direction: params.direction,
    status: effectiveStatus,
    message: params.request.message,
    rejectReason: params.request.rejectReason,
    createdAt: params.request.createdAt.toISOString(),
    respondedAt: params.request.respondedAt?.toISOString() ?? null,
    counterparty: params.counterparty,
  };
}
