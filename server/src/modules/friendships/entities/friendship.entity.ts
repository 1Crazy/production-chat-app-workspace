export interface FriendshipEntity {
  id: string;
  userAId: string;
  userBId: string;
  hiddenByUserAAt: Date | null;
  hiddenByUserBAt: Date | null;
  createdAt: Date;
}

export function normalizeFriendshipPair(userId: string, otherUserId: string): {
  userAId: string;
  userBId: string;
} {
  return userId < otherUserId
    ? { userAId: userId, userBId: otherUserId }
    : { userAId: otherUserId, userBId: userId };
}
