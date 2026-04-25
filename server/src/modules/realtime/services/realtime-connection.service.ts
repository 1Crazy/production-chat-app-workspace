import { Injectable, UnauthorizedException } from '@nestjs/common';

import {
  buildConversationRoom,
  buildSessionRoom,
  buildUserRoom,
} from '../constants/realtime.constants';
import type { ConnectionReadyEvent } from '../dto/realtime-event.dto';
import { RealtimePresenceService } from '../services/realtime-presence.service';
import type {
  AuthenticatedSocket,
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

@Injectable()
export class RealtimeConnectionService {
  constructor(
    private readonly authTokenService: AuthTokenService,
    private readonly authRepository: AuthRepository,
    private readonly chatModelRepository: ChatModelRepository,
    private readonly realtimePresenceService: RealtimePresenceService,
  ) {}

  async acceptConnection(params: {
    client: GatewaySocket;
    presenceTtlMs: number;
  }): Promise<{
    auth: SocketAuthContext;
    conversationIds: string[];
    readyEvent: ConnectionReadyEvent;
  }> {
    const authenticatedClient = params.client as AuthenticatedSocket;
    const auth = await this.authenticateClient(authenticatedClient);
    const conversationIds =
      await this.chatModelRepository.listConversationIdsForUser(auth.user.id);

    authenticatedClient.data.auth = auth;
    await this.realtimePresenceService.registerConnection({
      socketId: params.client.id,
      userId: auth.user.id,
      sessionId: auth.session.id,
      conversationIds,
      ttlMs: params.presenceTtlMs,
    });

    await params.client.join(buildUserRoom(auth.user.id));
    await params.client.join(buildSessionRoom(auth.session.id));
    await Promise.all(
      conversationIds.map((conversationId) => {
        return params.client.join(buildConversationRoom(conversationId));
      }),
    );

    return {
      auth,
      conversationIds,
      readyEvent: await this.buildConnectionReadyEvent(
        authenticatedClient,
        conversationIds,
      ),
    };
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
    const auth = client.data.auth;

    if (!auth) {
      throw new UnauthorizedException('实时连接上下文缺失');
    }

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
}
