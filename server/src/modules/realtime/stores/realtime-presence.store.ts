import type { UserPresenceView } from '../dto/realtime-event.dto';

export interface ActiveRealtimeConnection {
  socketId: string;
  userId: string;
  sessionId: string;
  conversationIds: string[];
}

export abstract class RealtimePresenceStore {
  abstract registerConnection(
    params: ActiveRealtimeConnection & {
      ttlMs: number;
    },
  ): Promise<void>;

  abstract touchConnection(params: {
    socketId: string;
    ttlMs: number;
  }): Promise<boolean>;

  abstract unregisterConnection(
    socketId: string,
  ): Promise<ActiveRealtimeConnection | null>;

  abstract getUserPresence(userId: string): Promise<UserPresenceView>;

  abstract listUserPresence(userIds: string[]): Promise<UserPresenceView[]>;

  abstract listSocketIdsBySessionId(sessionId: string): Promise<string[]>;
}
