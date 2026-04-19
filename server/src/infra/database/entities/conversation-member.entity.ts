export type ConversationMemberRole = 'owner' | 'admin' | 'member';

export interface ConversationMemberEntity {
  id: string;
  conversationId: string;
  userId: string;
  role: ConversationMemberRole;
  joinedAt: Date;
}
