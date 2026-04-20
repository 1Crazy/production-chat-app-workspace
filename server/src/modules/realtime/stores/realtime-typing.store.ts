export abstract class RealtimeTypingStore {
  abstract setTyping(params: {
    conversationId: string;
    userId: string;
    ttlMs: number;
  }): Promise<Date>;

  abstract clearTyping(params: {
    conversationId: string;
    userId: string;
  }): Promise<void>;
}
