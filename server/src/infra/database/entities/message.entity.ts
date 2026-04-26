export type MessageType = 'text' | 'image' | 'audio' | 'file' | 'system';
export type MessageStatus = 'processing' | 'sent' | 'failed';

export interface MessageEntity {
  id: string;
  conversationId: string;
  senderId: string;
  clientMessageId: string;
  type: MessageType;
  status: MessageStatus;
  sequence: number;
  content: Record<string, unknown>;
  failureReason: string | null;
  createdAt: Date;
  updatedAt: Date;
}
