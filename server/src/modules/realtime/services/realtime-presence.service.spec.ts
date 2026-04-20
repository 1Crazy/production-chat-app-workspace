import type { UserPresenceView } from '../dto/realtime-event.dto';
import {
  type ActiveRealtimeConnection,
  RealtimePresenceStore,
} from '../stores/realtime-presence.store';

import { RealtimePresenceService } from './realtime-presence.service';

class InMemoryRealtimePresenceStore extends RealtimePresenceStore {
  private readonly connectionsBySocketId = new Map<string, ActiveRealtimeConnection>();
  private readonly socketIdsByUserId = new Map<string, Set<string>>();
  private readonly socketIdsBySessionId = new Map<string, Set<string>>();
  private readonly sessionIdsByUserId = new Map<string, Set<string>>();
  private readonly lastSeenAtByUserId = new Map<string, string>();

  override async registerConnection(
    params: ActiveRealtimeConnection & {
      ttlMs: number;
    },
  ): Promise<void> {
    this.connectionsBySocketId.set(params.socketId, {
      socketId: params.socketId,
      userId: params.userId,
      sessionId: params.sessionId,
      conversationIds: params.conversationIds,
    });
    this.addValue(this.socketIdsByUserId, params.userId, params.socketId);
    this.addValue(this.socketIdsBySessionId, params.sessionId, params.socketId);
    this.addValue(this.sessionIdsByUserId, params.userId, params.sessionId);
    this.lastSeenAtByUserId.set(params.userId, new Date().toISOString());
  }

  override async touchConnection(): Promise<boolean> {
    return true;
  }

  override async unregisterConnection(
    socketId: string,
  ): Promise<ActiveRealtimeConnection | null> {
    const connection = this.connectionsBySocketId.get(socketId);

    if (!connection) {
      return null;
    }

    this.connectionsBySocketId.delete(socketId);
    this.removeValue(this.socketIdsByUserId, connection.userId, socketId);
    this.removeValue(this.socketIdsBySessionId, connection.sessionId, socketId);

    if ((this.socketIdsBySessionId.get(connection.sessionId)?.size ?? 0) === 0) {
      this.removeValue(
        this.sessionIdsByUserId,
        connection.userId,
        connection.sessionId,
      );
    }

    this.lastSeenAtByUserId.set(connection.userId, new Date().toISOString());
    return connection;
  }

  override async getUserPresence(userId: string): Promise<UserPresenceView> {
    return {
      userId,
      isOnline: (this.socketIdsByUserId.get(userId)?.size ?? 0) > 0,
      activeConnectionCount: this.socketIdsByUserId.get(userId)?.size ?? 0,
      activeSessionCount: this.sessionIdsByUserId.get(userId)?.size ?? 0,
      lastSeenAt: this.lastSeenAtByUserId.get(userId) ?? null,
    };
  }

  override async listUserPresence(userIds: string[]): Promise<UserPresenceView[]> {
    return Promise.all(userIds.map((userId) => this.getUserPresence(userId)));
  }

  override async listSocketIdsBySessionId(sessionId: string): Promise<string[]> {
    return Array.from(this.socketIdsBySessionId.get(sessionId) ?? []);
  }

  private addValue(index: Map<string, Set<string>>, key: string, value: string): void {
    const values = index.get(key) ?? new Set<string>();
    values.add(value);
    index.set(key, values);
  }

  private removeValue(
    index: Map<string, Set<string>>,
    key: string,
    value: string,
  ): void {
    const values = index.get(key);

    if (!values) {
      return;
    }

    values.delete(value);

    if (values.size === 0) {
      index.delete(key);
      return;
    }

    index.set(key, values);
  }
}

describe('RealtimePresenceService', () => {
  it('should aggregate presence across multiple sockets and sessions', async () => {
    const service = new RealtimePresenceService(new InMemoryRealtimePresenceStore());

    await service.registerConnection({
      socketId: 'socket-a',
      userId: 'user-1',
      sessionId: 'session-a',
      conversationIds: ['conversation-1'],
      ttlMs: 45000,
    });
    await service.registerConnection({
      socketId: 'socket-b',
      userId: 'user-1',
      sessionId: 'session-b',
      conversationIds: ['conversation-1', 'conversation-2'],
      ttlMs: 45000,
    });

    expect(await service.getUserPresence('user-1')).toMatchObject({
      userId: 'user-1',
      isOnline: true,
      activeConnectionCount: 2,
      activeSessionCount: 2,
    });
    expect(await service.listSocketIdsBySessionId('session-a')).toEqual(['socket-a']);

    await service.unregisterConnection('socket-a');

    expect(await service.getUserPresence('user-1')).toMatchObject({
      userId: 'user-1',
      isOnline: true,
      activeConnectionCount: 1,
      activeSessionCount: 1,
    });

    await service.unregisterConnection('socket-b');

    expect(await service.getUserPresence('user-1')).toMatchObject({
      userId: 'user-1',
      isOnline: false,
      activeConnectionCount: 0,
      activeSessionCount: 0,
    });
    expect((await service.getUserPresence('user-1')).lastSeenAt).toEqual(
      expect.any(String),
    );
  });
});
