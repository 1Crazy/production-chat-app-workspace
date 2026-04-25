import {
  ConflictException,
  Injectable,
  NotFoundException,
  UnauthorizedException,
} from '@nestjs/common';

import type { AuthResponseDto } from '../dto/auth-response.dto';
import type { LoginDto } from '../dto/login.dto';
import type { RefreshTokenDto } from '../dto/refresh-token.dto';
import type { RegisterDto } from '../dto/register.dto';
import type { RequestAuthCodeDto } from '../dto/request-auth-code.dto';
import type { ResetPasswordDto } from '../dto/reset-password.dto';
import type { VerificationCodePurpose } from '../entities/verification-code.entity';
import { AuthRepository } from '../repositories/auth.repository';
import type { AuthenticatedRequest } from '../types/authenticated-request.type';

import { AuthCodeDeliveryService } from './auth-code-delivery.service';
import { AuthPasswordService } from './auth-password.service';
import { AuthRateLimitService } from './auth-rate-limit.service';
import { AuthSessionService } from './auth-session.service';
import { AuthVerificationCodeService } from './auth-verification-code.service';

import { AppConfigService } from '@app/infra/config/app-config.service';

@Injectable()
export class AuthService {
  constructor(
    private readonly authRepository: AuthRepository,
    private readonly authPasswordService: AuthPasswordService,
    private readonly authSessionService: AuthSessionService,
    private readonly authVerificationCodeService: AuthVerificationCodeService,
    private readonly authRateLimitService: AuthRateLimitService,
    private readonly authCodeDeliveryService: AuthCodeDeliveryService,
    private readonly appConfigService: AppConfigService,
  ) {}

  getHealth(): { module: string; status: string } {
    return {
      module: 'auth',
      status: 'ready',
    };
  }

  async requestCode(
    dto: RequestAuthCodeDto,
    sourceKey = 'unknown-source',
  ): Promise<{
    identifier: string;
    purpose: VerificationCodePurpose;
    debugCode?: string;
    expiresInSeconds: number;
  }> {
    const normalizedIdentifier = dto.identifier.trim().toLowerCase();
    const purpose = dto.purpose;

    await this.authRateLimitService.assertAuthRateLimit({
      scope: `auth.request-code.${purpose}`,
      sourceKey,
      identifier: normalizedIdentifier,
      sourceLimit: this.appConfigService.authRequestCodeSourceLimit,
      identifierLimit: this.appConfigService.authRequestCodeIdentifierLimit,
      message: '验证码请求过于频繁，请稍后再试',
    });
    const issuedCode = await this.authVerificationCodeService.issueCode({
      identifier: normalizedIdentifier,
      purpose,
    });
    await this.authCodeDeliveryService.deliverVerificationCode({
      identifier: normalizedIdentifier,
      purpose,
      code: issuedCode.debugCode,
      expiresInSeconds: issuedCode.expiresInSeconds,
    });

    return {
      identifier: normalizedIdentifier,
      purpose,
      ...(this.authCodeDeliveryService.shouldExposeDebugCode()
        ? {
            debugCode: issuedCode.debugCode,
          }
        : {}),
      expiresInSeconds: issuedCode.expiresInSeconds,
    };
  }

  async register(
    dto: RegisterDto,
    sourceKey = 'unknown-source',
  ): Promise<AuthResponseDto> {
    const identifier = dto.identifier.trim().toLowerCase();

    await this.authRateLimitService.assertAuthRateLimit({
      scope: 'auth.register',
      sourceKey,
      identifier,
      sourceLimit: this.appConfigService.authRegisterSourceLimit,
      identifierLimit: this.appConfigService.authRegisterIdentifierLimit,
      message: '注册尝试过于频繁，请稍后再试',
    });

    if (await this.authRepository.findUserByIdentifier(identifier)) {
      throw new ConflictException('该标识已完成注册');
    }

    await this.authVerificationCodeService.assertVerificationCode(
      identifier,
      'register',
      dto.code,
    );
    const passwordHash = await this.authPasswordService.hashPassword(
      dto.password,
    );
    const user = await this.authRepository.createUser({
      identifier,
      nickname: dto.nickname.trim(),
      handle: await this.buildUniqueHandle(identifier),
      passwordHash,
      passwordUpdatedAt: new Date(),
    });
    const session = await this.authSessionService.createSessionForUser({
      userId: user.id,
      deviceName: dto.deviceName,
    });

    return this.authSessionService.buildAuthResponse(user, session);
  }

  async login(
    dto: LoginDto,
    sourceKey = 'unknown-source',
  ): Promise<AuthResponseDto> {
    const identifier = dto.identifier.trim().toLowerCase();

    await this.authRateLimitService.assertAuthRateLimit({
      scope: 'auth.login',
      sourceKey,
      identifier,
      sourceLimit: this.appConfigService.authLoginSourceLimit,
      identifierLimit: this.appConfigService.authLoginIdentifierLimit,
      message: '登录尝试过于频繁，请稍后再试',
    });
    const user = await this.authRepository.findUserByIdentifier(identifier);

    if (!user || user.disabledAt) {
      // 不区分"用户不存在"和"密码错误"，防止用户枚举攻击
      throw new UnauthorizedException('账号或密码不匹配');
    }

    if (!user.passwordHash) {
      throw new UnauthorizedException('账号或密码不匹配');
    }

    const passwordMatched = await this.authPasswordService.verifyPassword(
      dto.password,
      user.passwordHash,
    );

    if (!passwordMatched) {
      throw new UnauthorizedException('账号或密码不匹配');
    }

    const session = await this.authSessionService.createSessionForUser({
      userId: user.id,
      deviceName: dto.deviceName,
    });

    return this.authSessionService.buildAuthResponse(user, session);
  }

  async resetPassword(
    dto: ResetPasswordDto,
    sourceKey = 'unknown-source',
  ): Promise<{ success: boolean }> {
    const identifier = dto.identifier.trim().toLowerCase();

    await this.authRateLimitService.assertAuthRateLimit({
      scope: 'auth.reset-password',
      sourceKey,
      identifier,
      sourceLimit: this.appConfigService.authResetPasswordSourceLimit,
      identifierLimit: this.appConfigService.authResetPasswordIdentifierLimit,
      message: '重置密码尝试过于频繁，请稍后再试',
    });
    const user = await this.authRepository.findUserByIdentifier(identifier);

    if (!user || user.disabledAt) {
      // 不区分"不存在"和"禁用"，防止用户枚举攻击
      throw new NotFoundException('账号验证失败');
    }

    await this.authVerificationCodeService.assertVerificationCode(
      identifier,
      'reset-password',
      dto.code,
    );
    user.passwordHash = await this.authPasswordService.hashPassword(
      dto.password,
    );
    user.passwordUpdatedAt = new Date();
    await this.authRepository.saveUser(user);
    return {
      success: true,
    };
  }

  refresh(dto: RefreshTokenDto): Promise<AuthResponseDto> {
    return this.authSessionService.refresh(dto);
  }

  getCurrentProfile(
    request: AuthenticatedRequest,
  ): ReturnType<AuthSessionService['getCurrentProfile']> {
    return this.authSessionService.getCurrentProfile(request);
  }

  listSessions(request: AuthenticatedRequest) {
    return this.authSessionService.listSessions(request);
  }

  revokeSession(
    request: AuthenticatedRequest,
    sessionId: string,
  ): Promise<{
    success: boolean;
    revokedSessionId: string;
  }> {
    return this.authSessionService.revokeSession(request, sessionId);
  }

  logout(request: AuthenticatedRequest): Promise<{ success: boolean }> {
    return this.authSessionService.logout(request);
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
}
