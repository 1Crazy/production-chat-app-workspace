import {
  buildConversationRoom,
  buildSessionRoom,
  buildUserRoom,
  REALTIME_EVENTS,
} from '../constants/realtime.constants';
import type {
  ConnectionErrorEvent,
  ConnectionReadyEvent,
  UserPresenceView,
} from '../dto/realtime-event.dto';
import { RealtimeBroadcastService } from '../services/realtime-broadcast.service';
import { RealtimeConnectionService } from '../services/realtime-connection.service';
import { RealtimeHeartbeatService } from '../services/realtime-heartbeat.service';
import { RealtimePresenceService } from '../services/realtime-presence.service';
import type { RealtimeSocketAdapterService } from '../services/realtime-socket-adapter.service';
import { RealtimeTypingService } from '../services/realtime-typing.service';
import {
  type ActiveRealtimeConnection,
  RealtimePresenceStore,
} from '../stores/realtime-presence.store';
import { RealtimeTypingStore } from '../stores/realtime-typing.store';
import type {
  GatewayServer,
  GatewaySocket,
} from '../types/authenticated-socket.type';

import { ChatGateway } from './chat.gateway';

import type { AppConfigService } from '@app/infra/config/app-config.service';
import { InMemoryChatModelRepository } from '@app/infra/database/repositories/in-memory-chat-model.repository';
import type { MetricsRegistryService } from '@app/infra/observability/metrics-registry.service';
import { InMemoryAuthRepository } from '@app/modules/auth/repositories/in-memory-auth.repository';
import { AuthTokenService } from '@app/modules/auth/services/auth-token.service';

class InMemoryRealtimePresenceStore extends RealtimePresenceStore {
  private readonly connectionsBySocketId = new Map<string, ActiveRealtimeConnection>();
  private readonly socketIdsBySessionId = new Map<string, Set<string>>();
  private readonly userIdsBySocketId = new Map<string, string>();

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
    const socketIds = this.socketIdsBySessionId.get(params.sessionId) ?? new Set<string>();
    socketIds.add(params.socketId);
    this.socketIdsBySessionId.set(params.sessionId, socketIds);
    this.userIdsBySocketId.set(params.socketId, params.userId);
  }

  override async touchConnection(): Promise<boolean> {
    return true;
  }

  override async unregisterConnection(
    socketId: string,
  ): Promise<ActiveRealtimeConnection | null> {
    const connection = this.connectionsBySocketId.get(socketId) ?? null;

    if (!connection) {
      return null;
    }

    this.connectionsBySocketId.delete(socketId);
    this.userIdsBySocketId.delete(socketId);
    const socketIds = this.socketIdsBySessionId.get(connection.sessionId);

    if (socketIds) {
      socketIds.delete(socketId);

      if (socketIds.size === 0) {
        this.socketIdsBySessionId.delete(connection.sessionId);
      }
    }

    return connection;
  }

  override async getUserPresence(userId: string): Promise<UserPresenceView> {
    const activeConnections = Array.from(this.connectionsBySocketId.values()).filter(
      (connection) => connection.userId === userId,
    );
    const sessionIds = new Set(activeConnections.map((connection) => connection.sessionId));

    return {
      userId,
      isOnline: activeConnections.length > 0,
      activeConnectionCount: activeConnections.length,
      activeSessionCount: sessionIds.size,
      lastSeenAt: activeConnections.length > 0 ? new Date().toISOString() : null,
    };
  }

  override async listUserPresence(userIds: string[]): Promise<UserPresenceView[]> {
    return Promise.all(userIds.map((userId) => this.getUserPresence(userId)));
  }

  override async listSocketIdsBySessionId(sessionId: string): Promise<string[]> {
    return Array.from(this.socketIdsBySessionId.get(sessionId) ?? []);
  }

  override async countActiveConnections(): Promise<number> {
    return this.connectionsBySocketId.size;
  }
}

class InMemoryRealtimeTypingStore extends RealtimeTypingStore {
  override async setTyping(params: {
    conversationId: string;
    userId: string;
    ttlMs: number;
  }): Promise<Date> {
    return new Date(Date.now() + params.ttlMs);
  }

  override async clearTyping(): Promise<void> {}
}

function createSocket(params: {
  token?: string;
  recovered?: boolean;
}): GatewaySocket & {
  join: jest.Mock<Promise<void>, [string]>;
  emit: jest.Mock<void, [string, unknown]>;
  disconnect: jest.Mock<void, [boolean?]>;
} {
  return {
    id: 'socket-1',
    recovered: params.recovered ?? false,
    data: {},
    handshake: {
      auth: params.token ? { token: params.token } : {},
      query: {},
      headers: {},
    },
    join: jest.fn().mockResolvedValue(undefined),
    emit: jest.fn(),
    disconnect: jest.fn(),
  };
}

describe('ChatGateway', () => {
  function createGatewayFixture() {
    const authRepository = new InMemoryAuthRepository();
    const chatModelRepository = new InMemoryChatModelRepository();
    const realtimePresenceService = new RealtimePresenceService(
      new InMemoryRealtimePresenceStore(),
    );
    const realtimeTypingService = new RealtimeTypingService(
      new InMemoryRealtimeTypingStore(),
    );
    const realtimeSocketAdapterService = {
      apply: jest.fn(),
    } as unknown as RealtimeSocketAdapterService;
    const authTokenService = new AuthTokenService({
      get jwtAccessSecret() {
        return 'access-secret';
      },
      get jwtRefreshSecret() {
        return 'refresh-secret';
      },
    } as unknown as AppConfigService);
    const metricsRegistryService = {
      incrementCounter: jest.fn(),
      setGauge: jest.fn(),
    } as unknown as MetricsRegistryService;
    const realtimeConnectionService = new RealtimeConnectionService(
      authTokenService,
      authRepository,
      chatModelRepository,
      realtimePresenceService,
    );
    const realtimeBroadcastService = new RealtimeBroadcastService(
      realtimePresenceService,
      metricsRegistryService,
    );
    const realtimeHeartbeatService = new RealtimeHeartbeatService(
      realtimePresenceService,
    );
    const gateway = new ChatGateway(
      chatModelRepository,
      realtimeBroadcastService,
      realtimeConnectionService,
      realtimeHeartbeatService,
      realtimePresenceService,
      realtimeSocketAdapterService,
      realtimeTypingService,
      metricsRegistryService,
    );
    const roomEmitter = jest.fn();
    const roomDisconnect = jest.fn();
    const server: GatewayServer = {
      adapter: jest.fn(),
      in: jest.fn().mockReturnValue({
        disconnectSockets: roomDisconnect,
      }),
      to: jest.fn().mockReturnValue({
        emit: roomEmitter,
      }),
      sockets: {
        sockets: new Map(),
      },
    };

    (gateway as unknown as { server: GatewayServer }).server = server;

    return {
      gateway,
      authRepository,
      authTokenService,
      chatModelRepository,
      roomEmitter,
      roomDisconnect,
      server,
      metricsRegistryService,
    };
  }

  it('should authenticate socket and emit a recovery snapshot', async () => {
    const fixture = createGatewayFixture();
    const user = await fixture.authRepository.createUser({
      identifier: 'alice@example.com',
      nickname: 'Alice',
      handle: 'alice_user',
    });
    const peer = await fixture.authRepository.createUser({
      identifier: 'bob@example.com',
      nickname: 'Bob',
      handle: 'bob_user',
    });
    const session = await fixture.authRepository.createSession({
      userId: user.id,
      deviceName: 'alice-phone',
      refreshNonce: fixture.authTokenService.issueRefreshNonce(),
    });
    const conversation = await fixture.chatModelRepository.createConversation({
      type: 'direct',
      createdBy: user.id,
      memberIds: [user.id, peer.id],
    });
    const token = fixture.authTokenService.createAccessToken({
      userId: user.id,
      sessionId: session.id,
    });
    const socket = createSocket({
      token,
      recovered: true,
    });

    await fixture.gateway.handleConnection(socket);

    expect(socket.join).toHaveBeenNthCalledWith(1, buildUserRoom(user.id));
    expect(socket.join).toHaveBeenNthCalledWith(2, buildSessionRoom(session.id));
    expect(socket.join).toHaveBeenNthCalledWith(
      3,
      buildConversationRoom(conversation.id),
    );
    expect(socket.emit).toHaveBeenCalledWith(
      REALTIME_EVENTS.connectionReady,
      expect.objectContaining({
        connectionId: socket.id,
        recovered: true,
      }),
    );

    const payload = socket.emit.mock.calls[0]![1] as ConnectionReadyEvent;

    expect(payload.session.id).toBe(session.id);
    expect(payload.conversationStates).toEqual([
      {
        conversationId: conversation.id,
        latestSequence: 0,
      },
    ]);
    expect(payload.presence).toEqual(
      expect.arrayContaining([
        expect.objectContaining({
          userId: user.id,
          isOnline: true,
        }),
        expect.objectContaining({
          userId: peer.id,
          isOnline: false,
        }),
      ]),
    );
    expect(fixture.server.to).toHaveBeenCalledWith(buildUserRoom(user.id));
    expect(fixture.server.to).toHaveBeenCalledWith(
      buildConversationRoom(conversation.id),
    );
  });

  it('should disconnect the whole session room when adapter support is available', async () => {
    const fixture = createGatewayFixture();

    await fixture.gateway.disconnectSession('session-1', 'logout');

    expect(fixture.server.in).toHaveBeenCalledWith(buildSessionRoom('session-1'));
    expect(fixture.roomDisconnect).toHaveBeenCalledWith(true);
  });

  it('should reject invalid realtime tokens', async () => {
    const fixture = createGatewayFixture();
    const socket = createSocket({
      token: 'invalid-token',
    });

    await fixture.gateway.handleConnection(socket);

    expect(socket.emit).toHaveBeenCalledWith(
      REALTIME_EVENTS.connectionError,
      expect.objectContaining({
        code: 'UNAUTHORIZED',
      }),
    );

    const payload = socket.emit.mock.calls[0]![1] as ConnectionErrorEvent;

    expect(payload.message).toEqual(expect.any(String));
    expect(socket.disconnect).toHaveBeenCalledWith(true);
  });
});
