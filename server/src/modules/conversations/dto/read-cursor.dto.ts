import type { ReadCursorEntity } from '@app/infra/database/entities/read-cursor.entity';

export interface ReadCursorView {
  conversationId: string;
  userId: string;
  lastReadSequence: number;
  unreadCount: number;
  updatedAt: string;
}

export function toReadCursorView(
  cursor: ReadCursorEntity,
  unreadCount: number,
): ReadCursorView {
  return {
    conversationId: cursor.conversationId,
    userId: cursor.userId,
    lastReadSequence: cursor.lastReadSequence,
    unreadCount,
    updatedAt: cursor.updatedAt.toISOString(),
  };
}
