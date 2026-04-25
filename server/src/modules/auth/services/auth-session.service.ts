import {
  Inject,
  Injectable,
  NotFoundException,
  UnauthorizedException,
  forwardRef,
} from '@nestjs/common';

import type {
  AuthResponseDto,
  DeviceSessionView,
} from '../dto/auth-response.dto';
import { toAuthUserView, toDeviceSessionView } from '../dto/auth-response.dto';
import type { RefreshTokenDto } from '../dto/refresh-token.dto';
import type { AuthUserEntity } from '../entities/auth-user.entity';
import type { DeviceSessionEntity } from '../entities/device-session.entity';
import { AuthRepository } from '../repositories/auth.repository';
import type { AuthenticatedRequest } from '../types/authenticated-request.type';

import { AuthTokenService } from './auth-token.service';

import { ChatGateway } from '@app/modules/realtime/gateways/chat.gateway';

@Injectable()
export class AuthSessionService {
  constructor(
    private readonly authRepository: AuthRepository,
    private readonly authTokenService: AuthTokenService,
    @Inject(forwardRef(() => ChatGateway))
    private readonly chatGateway: ChatGateway,
  ) {}

  async createSessionForUser(params: {
    userId: string;
    deviceName?: string;
  }): Promise<DeviceSessionEntity> {
    return this.authRepository.createSession({
      userId: params.userId,
      deviceName: params.deviceName?.trim() || 'flutter-device',
      refreshNonce: this.authTokenService.issueRefreshNonce(),
    });
  }

  async refresh(dto: RefreshTokenDto): Promise<AuthResponseDto> {
    const payload = this.authTokenService.verifyRefreshToken(dto.refreshToken);
    const session = await this.authRepository.findActiveSessionById(
      payload.sid,
    );
    const user = await this.authRepository.findActiveUserById(payload.sub);

    if (!session || !user || session.userId !== user.id) {
      throw new UnauthorizedException('刷新会话不存在或已失效');
    }

    if (session.refreshNonce !== payload.nonce) {
      throw new UnauthorizedException('刷新令牌已轮换，请重新登录');
    }

    session.refreshNonce = this.authTokenService.issueRefreshNonce();
    session.lastSeenAt = new Date();
    await this.authRepository.saveSession(session);
    return this.buildAuthResponse(user, session);
  }

  getCurrentProfile(request: AuthenticatedRequest): {
    user: ReturnType<typeof toAuthUserView>;
    currentSession: DeviceSessionView;
  } {
    return {
      user: toAuthUserView(request.auth.user),
      currentSession: toDeviceSessionView(
        request.auth.session,
        request.auth.session.id,
      ),
    };
  }

  async listSessions(
    request: AuthenticatedRequest,
  ): Promise<DeviceSessionView[]> {
    const sessions = await this.authRepository.listActiveSessionsByUserId(
      request.auth.user.id,
    );

    return sessions.map((session) => {
      return toDeviceSessionView(session, request.auth.session.id);
    });
  }

  async revokeSession(
    request: AuthenticatedRequest,
    sessionId: string,
  ): Promise<{
    success: boolean;
    revokedSessionId: string;
  }> {
    const targetSession =
      await this.authRepository.findActiveSessionById(sessionId);

    if (!targetSession || targetSession.userId !== request.auth.user.id) {
      throw new NotFoundException('设备会话不存在');
    }

    await this.authRepository.revokeSession(sessionId);
    await this.chatGateway.disconnectSession(sessionId);
    return {
      success: true,
      revokedSessionId: sessionId,
    };
  }

  async logout(request: AuthenticatedRequest): Promise<{ success: boolean }> {
    await this.authRepository.revokeSession(request.auth.session.id);
    await this.chatGateway.disconnectSession(request.auth.session.id, 'logout');
    return {
      success: true,
    };
  }

  buildAuthResponse(
    user: AuthUserEntity,
    session: DeviceSessionEntity,
  ): AuthResponseDto {
    return {
      accessToken: this.authTokenService.createAccessToken({
        userId: user.id,
        sessionId: session.id,
      }),
      refreshToken: this.authTokenService.createRefreshToken({
        userId: user.id,
        sessionId: session.id,
        nonce: session.refreshNonce,
      }),
      user: toAuthUserView(user),
      currentSession: toDeviceSessionView(session, session.id),
    };
  }
}
