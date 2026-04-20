import {
  ForbiddenException,
  Logger,
  OnModuleDestroy,
  UnauthorizedException,
} from '@nestjs/common';
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  OnGatewayInit,
  SubscribeMessage,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';

import {
  buildConversationRoom,
  buildSessionRoom,
  buildUserRoom,
  REALTIME_EVENTS,
  REALTIME_NAMESPACE,
} from '../constants/realtime.constants';
import type {
  ConnectionErrorEvent,
  ConnectionReadyEvent,
  ConversationCreatedEvent,
  MessageCreatedEvent,
  ReadCursorUpdatedEvent,
  SessionRevokedEvent,
  TypingUpdatedEvent,
} from '../dto/realtime-event.dto';
import { SetTypingDto } from '../dto/set-typing.dto';
import { RealtimePresenceService } from '../services/realtime-presence.service';
import { RealtimeSocketAdapterService } from '../services/realtime-socket-adapter.service';
import { RealtimeTypingService } from '../services/realtime-typing.service';
import type {
  AuthenticatedSocket,
  GatewayServer,
  GatewaySocket,
  SocketAuthContext,
} from '../types/authenticated-socket.type';

import { ChatModelRepository } from '@app/infra/database/repositories/chat-model.repository';
import {
  toAuthUserView,
  toDeviceSessionView,
} from '@app/modules/auth/dto/auth-response.dto';
import { AuthRepository } from '@app/modules/auth/repositories/auth.repository';
import { AuthTokenService } from '@app/modules/auth/services/auth-token.service';
import type { ConversationView } from '@app/modules/conversations/dto/conversation.dto';
import type { ReadCursorView } from '@app/modules/conversations/dto/read-cursor.dto';
import type { MessageView } from '@app/modules/messages/dto/message.dto';

@WebSocketGateway({
  namespace: REALTIME_NAMESPACE,
  cors: {
    origin: true,
    credentials: true,
  },
  // 启用 Socket.IO 的断线恢复，让弱网重连时可以恢复房间和 socket data。
  connectionStateRecovery: {
    maxDisconnectionDuration: 2 * 60 * 1000,
    skipMiddlewares: false,
  },
})
export class ChatGateway
  implements OnGatewayConnection, OnGatewayDisconnect, OnGatewayInit, OnModuleDestroy
{
  @WebSocketServer()
  private server!: GatewayServer;

  private readonly logger = new Logger(ChatGateway.name);
  private readonly presenceHeartbeatTimers = new Map<string, NodeJS.Timeout>();
  private readonly presenceHeartbeatIntervalMs = 15 * 1000;
  private readonly presenceTtlMs = 45 * 1000;

  constructor(
    private readonly authTokenService: AuthTokenService,
    private readonly authRepository: AuthRepository,
    private readonly chatModelRepository: ChatModelRepository,
    private readonly realtimePresenceService: RealtimePresenceService,
    private readonly realtimeSocketAdapterService: RealtimeSocketAdapterService,
    private readonly realtimeTypingService: RealtimeTypingService,
  ) {}

  afterInit(server: GatewayServer): void {
    this.realtimeSocketAdapterService.apply(server);
  }

  onModuleDestroy(): void {
    for (const socketId of this.presenceHeartbeatTimers.keys()) {
      this.stopPresenceHeartbeat(socketId);
    }
  }

  // 建连时同时完成三件事：鉴权、房间恢复/加入、向客户端返回当前恢复快照。
  async handleConnection(client: GatewaySocket): Promise<void> {
    try {
      const authenticatedClient = client as AuthenticatedSocket;
      const auth = await this.authenticateClient(authenticatedClient);
      const conversationIds =
        await this.chatModelRepository.listConversationIdsForUser(auth.user.id);

      authenticatedClient.data.auth = auth;
      await this.realtimePresenceService.registerConnection({
        socketId: client.id,
        userId: auth.user.id,
        sessionId: auth.session.id,
        conversationIds,
        ttlMs: this.presenceTtlMs,
      });
      this.startPresenceHeartbeat(client.id);

      await client.join(buildUserRoom(auth.user.id));
      await client.join(buildSessionRoom(auth.session.id));
      await Promise.all(
        conversationIds.map((conversationId) => {
          return client.join(buildConversationRoom(conversationId));
        }),
      );

      authenticatedClient.emit(
        REALTIME_EVENTS.connectionReady,
        await this.buildConnectionReadyEvent(authenticatedClient, conversationIds),
      );
      // presence 变更要广播到用户自己的房间和相关会话房间，保证多端与会话内成员都能感知。
      await this.broadcastPresenceUpdate(auth.user.id, conversationIds);
    } catch (error) {
      const message =
        error instanceof Error ? error.message : '实时连接初始化失败';

      this.emitConnectionError(client, {
        code: error instanceof UnauthorizedException ? 'UNAUTHORIZED' : 'UNKNOWN',
        message,
      });
      this.logger.warn(`Rejecting realtime socket ${client.id}: ${message}`);
      client.disconnect(true);
    }
  }

  async handleDisconnect(client: GatewaySocket): Promise<void> {
    this.stopPresenceHeartbeat(client.id);
    const connection = await this.realtimePresenceService.unregisterConnection(
      client.id,
    );

    if (!connection) {
      return;
    }

    await this.broadcastPresenceUpdate(connection.userId, connection.conversationIds);
  }

  @SubscribeMessage('typing.set')
  async handleTypingSet(
    @ConnectedSocket() client: GatewaySocket,
    @MessageBody() dto: SetTypingDto,
  ): Promise<void> {
    const auth = this.getClientAuthOrThrow(client);

    await this.refreshPresenceHeartbeat(client.id);

    await this.assertConversationMembership(auth.user.id, dto.conversationId);
    const event = await this.realtimeTypingService.setTyping({
      conversationId: dto.conversationId,
      userId: auth.user.id,
      isTyping: dto.isTyping,
      onExpired: (expiredEvent) => {
        void this.emitTypingUpdated(expiredEvent);
      },
    });

    await this.emitTypingUpdated(event);
  }

  emitConversationCreated(conversation: ConversationView): void {
    const payload: ConversationCreatedEvent = {
      conversation,
    };

    for (const member of conversation.members) {
      this.server
        .to(buildUserRoom(member.userId))
        .emit(REALTIME_EVENTS.conversationCreated, payload);
    }
  }

  emitMessageCreated(message: MessageView): void {
    const payload: MessageCreatedEvent = {
      message,
    };

    this.server
      .to(buildConversationRoom(message.conversationId))
      .emit(REALTIME_EVENTS.messageCreated, payload);
  }

  async emitReadCursorUpdated(readCursor: ReadCursorView): Promise<void> {
    const payload: ReadCursorUpdatedEvent = {
      readCursor,
    };

    await this.emitToConversationMembers({
      conversationId: readCursor.conversationId,
      eventName: REALTIME_EVENTS.readCursorUpdated,
      payload,
      excludedUserId: readCursor.userId,
    });
  }

  async disconnectSession(
    sessionId: string,
    reason = 'session_revoked',
  ): Promise<void> {
    const payload: SessionRevokedEvent = {
      sessionId,
      reason,
    };

    this.server
      .to(buildSessionRoom(sessionId))
      .emit(REALTIME_EVENTS.sessionRevoked, payload);

    if (typeof this.server.in === 'function') {
      this.server.in(buildSessionRoom(sessionId)).disconnectSockets(true);
      return;
    }

    for (const socketId of await this.realtimePresenceService.listSocketIdsBySessionId(sessionId)) {
      this.stopPresenceHeartbeat(socketId);
      this.server.sockets.sockets.get(socketId)?.disconnect(true);
    }
  }

  private async authenticateClient(
    client: AuthenticatedSocket,
  ): Promise<SocketAuthContext> {
    const token = this.extractAccessToken(client);
    const payload = this.authTokenService.verifyAccessToken(token);
    const session = await this.authRepository.findActiveSessionById(payload.sid);
    const user = await this.authRepository.findActiveUserById(payload.sub);

    if (!session || !user || session.userId !== user.id) {
      throw new UnauthorizedException('实时登录状态已失效');
    }

    session.lastSeenAt = new Date();
    await this.authRepository.saveSession(session);

    return {
      user,
      session,
    };
  }

  private getClientAuthOrThrow(client: GatewaySocket): SocketAuthContext {
    const auth = (client as AuthenticatedSocket).data.auth;

    if (!auth) {
      throw new UnauthorizedException('实时连接上下文缺失');
    }

    return auth;
  }

  private async assertConversationMembership(
    userId: string,
    conversationId: string,
  ): Promise<void> {
    await this.chatModelRepository.getConversationOrThrow(conversationId);

    if (!(await this.chatModelRepository.isConversationMember(conversationId, userId))) {
      throw new ForbiddenException('你不是该会话成员');
    }
  }

  // 兼容 auth.token、Bearer header 和 query token，方便移动端和调试工具接入。
  private extractAccessToken(client: GatewaySocket): string {
    const tokenFromAuth = this.readSingleHandshakeValue(client.handshake.auth.token);
    const tokenFromQuery = this.readSingleHandshakeValue(
      client.handshake.query.token,
    );
    const authorizationHeader = client.handshake.headers.authorization;
    const tokenFromHeader =
      typeof authorizationHeader === 'string' &&
      authorizationHeader.startsWith('Bearer ')
        ? authorizationHeader.replace('Bearer ', '').trim()
        : null;
    const token = tokenFromAuth ?? tokenFromHeader ?? tokenFromQuery;

    if (!token) {
      throw new UnauthorizedException('缺少实时连接令牌');
    }

    return token;
  }

  private readSingleHandshakeValue(value: unknown): string | null {
    if (typeof value === 'string') {
      return value.trim();
    }

    if (Array.isArray(value) && typeof value[0] === 'string') {
      return value[0].trim();
    }

    return null;
  }

  private async buildConnectionReadyEvent(
    client: AuthenticatedSocket,
    conversationIds: string[],
  ): Promise<ConnectionReadyEvent> {
    const auth = this.getClientAuthOrThrow(client);

    const relatedUserIds = new Set<string>([auth.user.id]);

    for (const conversationId of conversationIds) {
      for (const userId of await this.chatModelRepository.listConversationMemberUserIds(
        conversationId,
      )) {
        relatedUserIds.add(userId);
      }
    }

    return {
      connectionId: client.id,
      recovered: client.recovered,
      serverTime: new Date().toISOString(),
      user: toAuthUserView(auth.user),
      session: toDeviceSessionView(auth.session, auth.session.id),
      activeConnectionCount: (
        await this.realtimePresenceService.getUserPresence(auth.user.id)
      ).activeConnectionCount,
      conversationStates: await Promise.all(
        conversationIds.map(async (conversationId) => {
          const conversation =
            await this.chatModelRepository.getConversationOrThrow(
              conversationId,
            );

          return {
            conversationId,
            latestSequence: conversation.latestSequence,
          };
        }),
      ),
      presence: await this.realtimePresenceService.listUserPresence(
        Array.from(relatedUserIds),
      ),
    };
  }

  private async broadcastPresenceUpdate(
    userId: string,
    conversationIds: string[],
  ): Promise<void> {
    const presence = await this.realtimePresenceService.getUserPresence(userId);

    this.server
      .to(buildUserRoom(userId))
      .emit(REALTIME_EVENTS.presenceUpdated, presence);

    for (const conversationId of new Set(conversationIds)) {
      this.server
        .to(buildConversationRoom(conversationId))
        .emit(REALTIME_EVENTS.presenceUpdated, presence);
    }
  }

  private async emitTypingUpdated(event: TypingUpdatedEvent): Promise<void> {
    await this.emitToConversationMembers({
      conversationId: event.conversationId,
      eventName: REALTIME_EVENTS.typingUpdated,
      payload: event,
      excludedUserId: event.userId,
    });
  }

  // 输入中、已读等状态事件只需要发给会话里的其他成员，不应重复回送给当前操作者。
  private async emitToConversationMembers(params: {
    conversationId: string;
    eventName: string;
    payload: unknown;
    excludedUserId?: string;
  }): Promise<void> {
    for (const userId of await this.chatModelRepository.listConversationMemberUserIds(
      params.conversationId,
    )) {
      if (userId === params.excludedUserId) {
        continue;
      }

      this.server
        .to(buildUserRoom(userId))
        .emit(params.eventName, params.payload);
    }
  }

  private emitConnectionError(
    client: GatewaySocket,
    payload: ConnectionErrorEvent,
  ): void {
    client.emit(REALTIME_EVENTS.connectionError, payload);
  }

  private startPresenceHeartbeat(socketId: string): void {
    this.stopPresenceHeartbeat(socketId);
    const timer = setInterval(() => {
      void this.refreshPresenceHeartbeat(socketId);
    }, this.presenceHeartbeatIntervalMs);

    timer.unref?.();
    this.presenceHeartbeatTimers.set(socketId, timer);
  }

  private stopPresenceHeartbeat(socketId: string): void {
    const timer = this.presenceHeartbeatTimers.get(socketId);

    if (!timer) {
      return;
    }

    clearInterval(timer);
    this.presenceHeartbeatTimers.delete(socketId);
  }

  private async refreshPresenceHeartbeat(socketId: string): Promise<void> {
    const touched = await this.realtimePresenceService.touchConnection({
      socketId,
      ttlMs: this.presenceTtlMs,
    });

    if (!touched) {
      this.stopPresenceHeartbeat(socketId);
    }
  }
}
