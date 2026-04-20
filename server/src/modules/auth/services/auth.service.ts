import {
  BadRequestException,
  ConflictException,
  Inject,
  Injectable,
  NotFoundException,
  UnauthorizedException,
  forwardRef,
} from '@nestjs/common';

import type { AuthResponseDto, DeviceSessionView } from '../dto/auth-response.dto';
import { toAuthUserView, toDeviceSessionView } from '../dto/auth-response.dto';
import type { LoginDto } from '../dto/login.dto';
import type { RefreshTokenDto } from '../dto/refresh-token.dto';
import type { RegisterDto } from '../dto/register.dto';
import type { RequestAuthCodeDto } from '../dto/request-auth-code.dto';
import type { AuthUserEntity } from '../entities/auth-user.entity';
import type { DeviceSessionEntity } from '../entities/device-session.entity';
import { AuthRepository } from '../repositories/auth.repository';
import type { AuthenticatedRequest } from '../types/authenticated-request.type';

import { AuthTokenService } from './auth-token.service';

import { ChatGateway } from '@app/modules/realtime/gateways/chat.gateway';

@Injectable()
export class AuthService {
  private readonly verificationCodeTtlSeconds = 60 * 10;

  constructor(
    private readonly authRepository: AuthRepository,
    private readonly authTokenService: AuthTokenService,
    @Inject(forwardRef(() => ChatGateway))
    private readonly chatGateway: ChatGateway,
  ) {}

  getHealth(): { module: string; status: string } {
    return {
      module: 'auth',
      status: 'ready',
    };
  }

  async requestCode(
    dto: RequestAuthCodeDto,
  ): Promise<{
    identifier: string;
    debugCode: string;
    expiresInSeconds: number;
  }> {
    const normalizedIdentifier = dto.identifier.trim().toLowerCase();
    const verificationCode = this.generateVerificationCode();
    const expiresAt = new Date(
      Date.now() + this.verificationCodeTtlSeconds * 1000,
    );

    await this.authRepository.createVerificationCode(
      normalizedIdentifier,
      verificationCode,
      expiresAt,
    );

    return {
      identifier: normalizedIdentifier,
      debugCode: verificationCode,
      expiresInSeconds: this.verificationCodeTtlSeconds,
    };
  }

  async register(dto: RegisterDto): Promise<AuthResponseDto> {
    const identifier = dto.identifier.trim().toLowerCase();

    if (await this.authRepository.findUserByIdentifier(identifier)) {
      throw new ConflictException('该标识已完成注册');
    }

    await this.assertVerificationCode(identifier, dto.code);
    const user = await this.authRepository.createUser({
      identifier,
      nickname: dto.nickname.trim(),
      handle: await this.buildUniqueHandle(identifier),
    });
    const session = await this.authRepository.createSession({
      userId: user.id,
      deviceName: dto.deviceName?.trim() || 'flutter-device',
      refreshNonce: this.authTokenService.issueRefreshNonce(),
    });

    return this.buildAuthResponse(user, session);
  }

  async login(dto: LoginDto): Promise<AuthResponseDto> {
    const identifier = dto.identifier.trim().toLowerCase();
    const user = await this.authRepository.findUserByIdentifier(identifier);

    if (!user || user.disabledAt) {
      throw new NotFoundException('账号不存在或已被禁用');
    }

    await this.assertVerificationCode(identifier, dto.code);
    const session = await this.authRepository.createSession({
      userId: user.id,
      deviceName: dto.deviceName?.trim() || 'flutter-device',
      refreshNonce: this.authTokenService.issueRefreshNonce(),
    });

    return this.buildAuthResponse(user, session);
  }

  async refresh(dto: RefreshTokenDto): Promise<AuthResponseDto> {
    const payload = this.authTokenService.verifyRefreshToken(dto.refreshToken);
    const session = await this.authRepository.findActiveSessionById(payload.sid);
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

  async getCurrentProfile(request: AuthenticatedRequest): Promise<{
    user: ReturnType<typeof toAuthUserView>;
    currentSession: DeviceSessionView;
  }> {
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
    const targetSession = await this.authRepository.findActiveSessionById(
      sessionId,
    );

    if (!targetSession || targetSession.userId !== request.auth.user.id) {
      throw new NotFoundException('设备会话不存在');
    }

    await this.authRepository.revokeSession(sessionId);
    // 设备会话一旦被撤销，对应长连接也必须立即下线，避免继续接收实时事件。
    await this.chatGateway.disconnectSession(sessionId);
    return {
      success: true,
      revokedSessionId: sessionId,
    };
  }

  async logout(
    request: AuthenticatedRequest,
  ): Promise<{ success: boolean }> {
    await this.authRepository.revokeSession(request.auth.session.id);
    await this.chatGateway.disconnectSession(request.auth.session.id, 'logout');
    return {
      success: true,
    };
  }

  private async assertVerificationCode(
    identifier: string,
    code: string,
  ): Promise<void> {
    const verificationCode = await this.authRepository.findVerificationCode(
      identifier,
    );

    if (!verificationCode) {
      throw new BadRequestException('请先获取验证码');
    }

    if (verificationCode.consumedAt) {
      throw new BadRequestException('验证码已使用，请重新获取');
    }

    if (verificationCode.expiresAt.getTime() <= Date.now()) {
      throw new BadRequestException('验证码已过期，请重新获取');
    }

    if (verificationCode.code !== code.trim()) {
      throw new BadRequestException('验证码不正确');
    }

    verificationCode.consumedAt = new Date();
    await this.authRepository.saveVerificationCode(verificationCode);
  }

  private buildAuthResponse(
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

  private async buildUniqueHandle(identifier: string): Promise<string> {
    const baseHandle = identifier
      .replace(/[^a-zA-Z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '')
      .slice(0, 24);

    const normalizedBaseHandle = baseHandle || 'user';

    for (let suffix = 0; suffix < 1000; suffix += 1) {
      const handle =
        suffix === 0
          ? normalizedBaseHandle
          : `${normalizedBaseHandle.slice(0, 24 - `_${suffix}`.length)}_${suffix}`;

      if (!(await this.authRepository.findUserByHandle(handle))) {
        return handle;
      }
    }

    throw new ConflictException('系统暂时无法分配唯一标识，请稍后重试');
  }

  private generateVerificationCode(): string {
    return `${Math.floor(100000 + Math.random() * 900000)}`;
  }
}
