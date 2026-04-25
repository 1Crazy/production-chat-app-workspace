import {
  ForbiddenException,
  Logger,
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
  ConversationCreatedEvent,
  MessageCreatedEvent,
  ReadCursorUpdatedEvent,
  SessionRevokedEvent,
  TypingUpdatedEvent,
} from '../dto/realtime-event.dto';
import { SetTypingDto } from '../dto/set-typing.dto';
import { RealtimeBroadcastService } from '../services/realtime-broadcast.service';
import { RealtimeConnectionService } from '../services/realtime-connection.service';
import { RealtimeHeartbeatService } from '../services/realtime-heartbeat.service';
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
import { MetricsRegistryService } from '@app/infra/observability/metrics-registry.service';
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
  implements OnGatewayConnection, OnGatewayDisconnect, OnGatewayInit
{
  @WebSocketServer()
  private server!: GatewayServer;

  private readonly logger = new Logger(ChatGateway.name);
  private readonly presenceTtlMs = 45 * 1000;

  constructor(
    private readonly chatModelRepository: ChatModelRepository,
    private readonly realtimeBroadcastService: RealtimeBroadcastService,
    private readonly realtimeConnectionService: RealtimeConnectionService,
    private readonly realtimeHeartbeatService: RealtimeHeartbeatService,
    private readonly realtimePresenceService: RealtimePresenceService,
    private readonly realtimeSocketAdapterService: RealtimeSocketAdapterService,
    private readonly realtimeTypingService: RealtimeTypingService,
    private readonly metricsRegistryService: MetricsRegistryService,
  ) {}

  afterInit(server: GatewayServer): void {
    this.realtimeSocketAdapterService.apply(server);
  }

  async handleConnection(client: GatewaySocket): Promise<void> {
    try {
      const connection = await this.realtimeConnectionService.acceptConnection({
        client,
        presenceTtlMs: this.presenceTtlMs,
      });
      this.realtimeHeartbeatService.start(client.id, this.presenceTtlMs);

      await this.realtimeBroadcastService.recordRealtimeConnectionGauge();
      this.metricsRegistryService.incrementCounter('chat_realtime_connections_total', {
        help: 'Total number of accepted realtime socket connections.',
        labels: {
          result: 'accepted',
        },
      });

      client.emit(
        REALTIME_EVENTS.connectionReady,
        connection.readyEvent,
      );
      await this.realtimeBroadcastService.broadcastPresenceUpdate({
        server: this.server,
        userId: connection.auth.user.id,
        conversationIds: connection.conversationIds,
      });
    } catch (error) {
      const message =
        error instanceof Error ? error.message : '实时连接初始化失败';

      this.emitConnectionError(client, {
        code: error instanceof UnauthorizedException ? 'UNAUTHORIZED' : 'UNKNOWN',
        message,
      });
      this.metricsRegistryService.incrementCounter('chat_realtime_connections_total', {
        help: 'Total number of realtime socket connection attempts.',
        labels: {
          result: 'rejected',
        },
      });
      this.logger.warn(`Rejecting realtime socket ${client.id}: ${message}`);
      client.disconnect(true);
    }
  }

  async handleDisconnect(client: GatewaySocket): Promise<void> {
    this.realtimeHeartbeatService.stop(client.id);
    const connection = await this.realtimePresenceService.unregisterConnection(
      client.id,
    );

    if (!connection) {
      return;
    }

    await this.realtimeBroadcastService.recordRealtimeConnectionGauge();
    this.metricsRegistryService.incrementCounter('chat_realtime_disconnects_total', {
      help: 'Total number of realtime socket disconnect events.',
      labels: {
        reason: 'client_disconnect',
      },
    });
    await this.realtimeBroadcastService.broadcastPresenceUpdate({
      server: this.server,
      userId: connection.userId,
      conversationIds: connection.conversationIds,
    });
  }

  @SubscribeMessage('typing.set')
  async handleTypingSet(
    @ConnectedSocket() client: GatewaySocket,
    @MessageBody() dto: SetTypingDto,
  ): Promise<void> {
    const auth = this.getClientAuthOrThrow(client);

    await this.realtimeHeartbeatService.refresh(client.id, this.presenceTtlMs);

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

    // 当前账号的其他设备也需要同步自己的已读游标和未读角标，
    // 因此除了会话其他成员，还要发给当前用户的 user room。
    this.server
      .to(buildUserRoom(readCursor.userId))
      .emit(REALTIME_EVENTS.readCursorUpdated, payload);

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
      this.realtimeHeartbeatService.stop(socketId);
      this.server.sockets.sockets.get(socketId)?.disconnect(true);
    }
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

  private async emitTypingUpdated(event: TypingUpdatedEvent): Promise<void> {
    await this.emitToConversationMembers({
      conversationId: event.conversationId,
      eventName: REALTIME_EVENTS.typingUpdated,
      payload: event,
      excludedUserId: event.userId,
    });
  }

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

}
