import { Injectable } from '@nestjs/common';

import type { UserPresenceView } from '../dto/realtime-event.dto';

import {
  ActiveRealtimeConnection,
  RealtimePresenceStore,
} from './realtime-presence.store';

import { RedisService } from '@app/infra/cache/redis.service';

@Injectable()
export class RedisRealtimePresenceStore extends RealtimePresenceStore {
  constructor(private readonly redisService: RedisService) {
    super();
  }

  override async registerConnection(
    params: ActiveRealtimeConnection & {
      ttlMs: number;
    },
  ): Promise<void> {
    const nowIso = new Date().toISOString();
    const pipeline = this.redisService.instance.pipeline();

    pipeline.hset(this.socketKey(params.socketId), {
      socketId: params.socketId,
      userId: params.userId,
      sessionId: params.sessionId,
      conversationIds: JSON.stringify(params.conversationIds),
      heartbeatAt: nowIso,
    });
    pipeline.pexpire(this.socketKey(params.socketId), params.ttlMs);
    pipeline.sadd(this.userSocketsKey(params.userId), params.socketId);
    pipeline.sadd(this.sessionSocketsKey(params.sessionId), params.socketId);
    pipeline.set(this.lastSeenKey(params.userId), nowIso);

    await pipeline.exec();
  }

  override async touchConnection(params: {
    socketId: string;
    ttlMs: number;
  }): Promise<boolean> {
    const key = this.socketKey(params.socketId);
    const exists = await this.redisService.instance.exists(key);

    if (exists === 0) {
      return false;
    }

    await this.redisService.instance
      .multi()
      .hset(key, 'heartbeatAt', new Date().toISOString())
      .pexpire(key, params.ttlMs)
      .exec();

    return true;
  }

  override async unregisterConnection(
    socketId: string,
  ): Promise<ActiveRealtimeConnection | null> {
    const rawConnection = await this.redisService.instance.hgetall(
      this.socketKey(socketId),
    );

    if (Object.keys(rawConnection).length === 0) {
      return null;
    }

    const connection = this.toConnection(rawConnection);
    const nowIso = new Date().toISOString();
    const pipeline = this.redisService.instance.pipeline();

    pipeline.del(this.socketKey(socketId));
    pipeline.srem(this.userSocketsKey(connection.userId), socketId);
    pipeline.srem(this.sessionSocketsKey(connection.sessionId), socketId);
    pipeline.set(this.lastSeenKey(connection.userId), nowIso);

    await pipeline.exec();

    const [remainingSessionSockets, remainingUserSockets] = await Promise.all([
      this.redisService.instance.scard(
        this.sessionSocketsKey(connection.sessionId),
      ),
      this.redisService.instance.scard(this.userSocketsKey(connection.userId)),
    ]);

    if (remainingSessionSockets === 0) {
      await this.redisService.instance.del(
        this.sessionSocketsKey(connection.sessionId),
      );
    }

    if (remainingUserSockets === 0) {
      await this.redisService.instance.del(this.userSocketsKey(connection.userId));
    }

    return connection;
  }

  override async getUserPresence(userId: string): Promise<UserPresenceView> {
    const socketIds = await this.redisService.instance.smembers(
      this.userSocketsKey(userId),
    );
    const activeConnections = await this.resolveActiveConnectionsForUser(
      userId,
      socketIds,
    );
    const activeSessionCount = new Set(
      activeConnections.map((connection) => connection.sessionId),
    ).size;
    const lastSeenAt = await this.redisService.instance.get(this.lastSeenKey(userId));

    return {
      userId,
      isOnline: activeConnections.length > 0,
      activeConnectionCount: activeConnections.length,
      activeSessionCount,
      lastSeenAt,
    };
  }

  override async listUserPresence(userIds: string[]): Promise<UserPresenceView[]> {
    return Promise.all(
      Array.from(new Set(userIds)).map((userId) => this.getUserPresence(userId)),
    );
  }

  override async listSocketIdsBySessionId(sessionId: string): Promise<string[]> {
    const socketIds = await this.redisService.instance.smembers(
      this.sessionSocketsKey(sessionId),
    );
    const activeSocketIds = await this.resolveExistingSocketIds(socketIds);

    if (activeSocketIds.length !== socketIds.length) {
      const staleSocketIds = socketIds.filter((socketId) => {
        return !activeSocketIds.includes(socketId);
      });

      if (staleSocketIds.length > 0) {
        await this.redisService.instance.srem(
          this.sessionSocketsKey(sessionId),
          ...staleSocketIds,
        );
      }
    }

    return activeSocketIds;
  }

  private toConnection(rawConnection: Record<string, string>): ActiveRealtimeConnection {
    return {
      socketId: rawConnection.socketId ?? '',
      userId: rawConnection.userId ?? '',
      sessionId: rawConnection.sessionId ?? '',
      conversationIds: this.parseConversationIds(rawConnection.conversationIds),
    };
  }

  private parseConversationIds(value: string | undefined): string[] {
    if (!value) {
      return [];
    }

    try {
      const parsed = JSON.parse(value);
      return Array.isArray(parsed)
        ? parsed.filter((item): item is string => typeof item === 'string')
        : [];
    } catch {
      return [];
    }
  }

  private socketKey(socketId: string): string {
    return `chat:presence:socket:${socketId}`;
  }

  private userSocketsKey(userId: string): string {
    return `chat:presence:user:${userId}:sockets`;
  }

  private userSessionsKey(userId: string): string {
    return `chat:presence:user:${userId}:sessions`;
  }
  private sessionSocketsKey(sessionId: string): string {
    return `chat:presence:session:${sessionId}:sockets`;
  }

  private lastSeenKey(userId: string): string {
    return `chat:presence:user:${userId}:last-seen`;
  }

  private async resolveActiveConnectionsForUser(
    userId: string,
    socketIds: string[],
  ): Promise<ActiveRealtimeConnection[]> {
    const rawConnections = await this.fetchSocketPayloads(socketIds);
    const activeConnections = rawConnections
      .map((connection) => {
        return connection ? this.toConnection(connection) : null;
      })
      .filter((connection): connection is ActiveRealtimeConnection => {
        return connection != null && connection.userId === userId;
      });

    const activeSocketIds = new Set(activeConnections.map((connection) => connection.socketId));
    const staleSocketIds = socketIds.filter((socketId) => !activeSocketIds.has(socketId));

    if (staleSocketIds.length > 0) {
      await this.redisService.instance.srem(this.userSocketsKey(userId), ...staleSocketIds);
    }

    return activeConnections;
  }

  private async resolveExistingSocketIds(socketIds: string[]): Promise<string[]> {
    const rawConnections = await this.fetchSocketPayloads(socketIds);

    return rawConnections
      .map((connection, index) => {
        return connection ? socketIds[index] ?? null : null;
      })
      .filter((socketId): socketId is string => socketId != null);
  }

  private async fetchSocketPayloads(
    socketIds: string[],
  ): Promise<Array<Record<string, string> | null>> {
    if (socketIds.length === 0) {
      return [];
    }

    const pipeline = this.redisService.instance.pipeline();

    socketIds.forEach((socketId) => {
      pipeline.hgetall(this.socketKey(socketId));
    });

    const results = await pipeline.exec();

    return (results ?? []).map((result) => {
      const payload = result?.[1];

      if (!payload || typeof payload !== 'object' || Array.isArray(payload)) {
        return null;
      }

      return Object.keys(payload).length > 0
        ? (payload as Record<string, string>)
        : null;
    });
  }
}
