export interface ReadCursorEntity {
  id: string;
  conversationId: string;
  userId: string;
  lastReadSequence: number;
  updatedAt: Date;
}
