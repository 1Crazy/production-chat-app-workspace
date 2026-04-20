export abstract class MessageIdempotencyStore {
  abstract getBoundMessageId(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
  }): Promise<string | null>;

  abstract reserve(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
  }): Promise<boolean>;

  abstract bind(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
    messageId: string;
  }): Promise<void>;

  abstract release(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
  }): Promise<void>;
}
