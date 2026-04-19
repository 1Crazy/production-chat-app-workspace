import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';

import type { AuthResponseDto, DeviceSessionView } from '../dto/auth-response.dto';
import { toAuthUserView, toDeviceSessionView } from '../dto/auth-response.dto';
import type { LoginDto } from '../dto/login.dto';
import type { RefreshTokenDto } from '../dto/refresh-token.dto';
import type { RegisterDto } from '../dto/register.dto';
import type { RequestAuthCodeDto } from '../dto/request-auth-code.dto';
import type { AuthUserEntity } from '../entities/auth-user.entity';
import type { DeviceSessionEntity } from '../entities/device-session.entity';
import { InMemoryAuthRepository } from '../repositories/in-memory-auth.repository';
import type { AuthenticatedRequest } from '../types/authenticated-request.type';

import { AuthTokenService } from './auth-token.service';

@Injectable()
export class AuthService {
  private readonly verificationCodeTtlSeconds = 60 * 10;

  constructor(
    private readonly authRepository: InMemoryAuthRepository,
    private readonly authTokenService: AuthTokenService,
  ) {}

  getHealth(): { module: string; status: string } {
    return {
      module: 'auth',
      status: 'ready',
    };
  }

  requestCode(
    dto: RequestAuthCodeDto,
  ): { identifier: string; debugCode: string; expiresInSeconds: number } {
    const normalizedIdentifier = dto.identifier.trim().toLowerCase();
    const verificationCode = this.generateVerificationCode();
    const expiresAt = new Date(
      Date.now() + this.verificationCodeTtlSeconds * 1000,
    );

    this.authRepository.createVerificationCode(
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

  register(dto: RegisterDto): AuthResponseDto {
    const identifier = dto.identifier.trim().toLowerCase();

    if (this.authRepository.findUserByIdentifier(identifier)) {
      throw new ConflictException('该标识已完成注册');
    }

    this.assertVerificationCode(identifier, dto.code);
    const user = this.authRepository.createUser({
      identifier,
      nickname: dto.nickname.trim(),
      handle: this.buildHandle(identifier),
    });
    const session = this.authRepository.createSession({
      userId: user.id,
      deviceName: dto.deviceName?.trim() || 'flutter-device',
      refreshNonce: this.authTokenService.issueRefreshNonce(),
    });

    return this.buildAuthResponse(user, session);
  }

  login(dto: LoginDto): AuthResponseDto {
    const identifier = dto.identifier.trim().toLowerCase();
    const user = this.authRepository.findUserByIdentifier(identifier);

    if (!user || user.disabledAt) {
      throw new NotFoundException('账号不存在或已被禁用');
    }

    this.assertVerificationCode(identifier, dto.code);
    const session = this.authRepository.createSession({
      userId: user.id,
      deviceName: dto.deviceName?.trim() || 'flutter-device',
      refreshNonce: this.authTokenService.issueRefreshNonce(),
    });

    return this.buildAuthResponse(user, session);
  }

  refresh(dto: RefreshTokenDto): AuthResponseDto {
    const payload = this.authTokenService.verifyRefreshToken(dto.refreshToken);
    const session = this.authRepository.findActiveSessionById(payload.sid);
    const user = this.authRepository.findActiveUserById(payload.sub);

    if (!session || !user || session.userId !== user.id) {
      throw new UnauthorizedException('刷新会话不存在或已失效');
    }

    if (session.refreshNonce !== payload.nonce) {
      throw new UnauthorizedException('刷新令牌已轮换，请重新登录');
    }

    session.refreshNonce = this.authTokenService.issueRefreshNonce();
    session.lastSeenAt = new Date();
    this.authRepository.saveSession(session);
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

  listSessions(request: AuthenticatedRequest): DeviceSessionView[] {
    return this.authRepository
      .listActiveSessionsByUserId(request.auth.user.id)
      .map((session) => {
        return toDeviceSessionView(session, request.auth.session.id);
      });
  }

  revokeSession(request: AuthenticatedRequest, sessionId: string): {
    success: boolean;
    revokedSessionId: string;
  } {
    const targetSession = this.authRepository.findActiveSessionById(sessionId);

    if (!targetSession || targetSession.userId !== request.auth.user.id) {
      throw new NotFoundException('设备会话不存在');
    }

    this.authRepository.revokeSession(sessionId);
    return {
      success: true,
      revokedSessionId: sessionId,
    };
  }

  logout(request: AuthenticatedRequest): { success: boolean } {
    this.authRepository.revokeSession(request.auth.session.id);
    return {
      success: true,
    };
  }

  private assertVerificationCode(identifier: string, code: string): void {
    const verificationCode = this.authRepository.findVerificationCode(identifier);

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
    this.authRepository.saveVerificationCode(verificationCode);
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

  private buildHandle(identifier: string): string {
    return identifier
      .replace(/[^a-zA-Z0-9]+/g, '_')
      .replace(/^_+|_+$/g, '')
      .slice(0, 24);
  }

  private generateVerificationCode(): string {
    return `${Math.floor(100000 + Math.random() * 900000)}`;
  }
}
