import type { ConversationType } from '@app/infra/database/entities/conversation.entity';

export interface ConversationSummaryView {
  id: string;
  type: ConversationType;
  title: string;
  memberCount: number;
  latestSequence: number;
  lastMessagePreview: string;
  lastMessageAt: string | null;
  unreadCount: number;
  updatedAt: string;
}

export function toConversationSummaryView(params: {
  id: string;
  type: ConversationType;
  title: string;
  memberCount: number;
  latestSequence: number;
  lastMessagePreview: string;
  lastMessageAt: Date | null;
  unreadCount: number;
  updatedAt: Date;
}): ConversationSummaryView {
  return {
    id: params.id,
    type: params.type,
    title: params.title,
    memberCount: params.memberCount,
    latestSequence: params.latestSequence,
    lastMessagePreview: params.lastMessagePreview,
    lastMessageAt: params.lastMessageAt?.toISOString() ?? null,
    unreadCount: params.unreadCount,
    updatedAt: params.updatedAt.toISOString(),
  };
}
