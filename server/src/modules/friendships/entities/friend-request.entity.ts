export const friendRequestStatuses = ['pending', 'accepted', 'rejected'] as const;

export type FriendRequestStatus = (typeof friendRequestStatuses)[number];

export interface FriendRequestEntity {
  id: string;
  requesterId: string;
  addresseeId: string;
  status: FriendRequestStatus;
  message: string | null;
  createdAt: Date;
  updatedAt: Date;
  respondedAt: Date | null;
  ignoredByAddresseeAt: Date | null;
}
