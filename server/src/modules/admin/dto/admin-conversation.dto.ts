export interface AdminConversationDetailDto {
  id: string;
  type: 'direct' | 'group';
  title: string | null;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
  latestSequence: number;
  members: Array<{
    userId: string;
    role: 'owner' | 'admin' | 'member';
    joinedAt: string;
  }>;
  latestMessage: {
    id: string;
    senderId: string;
    type: string;
    sequence: number;
    createdAt: string;
  } | null;
}
