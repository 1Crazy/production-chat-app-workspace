import { randomInt } from 'node:crypto';

import { BadRequestException, Injectable } from '@nestjs/common';

import type { VerificationCodePurpose } from '../entities/verification-code.entity';
import { AuthRepository } from '../repositories/auth.repository';

import { RateLimitService } from '@app/infra/abuse/services/rate-limit.service';

@Injectable()
export class AuthVerificationCodeService {
  private readonly verificationCodeTtlSeconds = 60 * 10;
  // 验证码输入最大重试次数，超过后需重新获取。
  private readonly maxVerifyAttempts = 5;

  constructor(
    private readonly authRepository: AuthRepository,
    private readonly rateLimitService: RateLimitService,
  ) {}

  async issueCode(params: {
    identifier: string;
    purpose: VerificationCodePurpose;
  }): Promise<{
    debugCode: string;
    expiresInSeconds: number;
  }> {
    const verificationCode = this.generateVerificationCode();
    const expiresAt = new Date(
      Date.now() + this.verificationCodeTtlSeconds * 1000,
    );

    await this.authRepository.createVerificationCode(
      params.identifier,
      params.purpose,
      verificationCode,
      expiresAt,
    );

    // 新验证码签发时重置之前的重试计数器，让用户获得完整的尝试次数。
    await this.rateLimitService.reset({
      scope: `auth.assert-code.${params.purpose}`,
      actorKey: params.identifier,
    });

    return {
      debugCode: verificationCode,
      expiresInSeconds: this.verificationCodeTtlSeconds,
    };
  }

  async assertVerificationCode(
    identifier: string,
    purpose: VerificationCodePurpose,
    code: string,
  ): Promise<void> {
    // 先检查重试限流，防止暴力枚举验证码。
    // 如果触发限流，在窗口期内不管输入是否正确都会被拒绝。
    await this.rateLimitService.consumeOrThrow({
      scope: `auth.assert-code.${purpose}`,
      actorKey: identifier,
      limit: this.maxVerifyAttempts,
      windowMs: this.verificationCodeTtlSeconds * 1000,
      message: '验证码尝试次数过多，请重新获取',
    });

    const verificationCode = await this.authRepository.findVerificationCode(
      identifier,
      purpose,
    );
    const purposeLabel = this.getVerificationCodePurposeLabel(purpose);

    if (!verificationCode) {
      throw new BadRequestException(`请先获取${purposeLabel}验证码`);
    }

    if (verificationCode.consumedAt) {
      throw new BadRequestException(`${purposeLabel}验证码已使用，请重新获取`);
    }

    if (verificationCode.expiresAt.getTime() <= Date.now()) {
      throw new BadRequestException(`${purposeLabel}验证码已过期，请重新获取`);
    }

    if (verificationCode.code !== code.trim()) {
      throw new BadRequestException(`${purposeLabel}验证码不正确`);
    }

    verificationCode.consumedAt = new Date();
    await this.authRepository.saveVerificationCode(verificationCode);
  }

  private generateVerificationCode(): string {
    // 使用密码学安全的随机数替代 Math.random，防止预测。
    return `${randomInt(100000, 1000000)}`;
  }

  private getVerificationCodePurposeLabel(
    purpose: VerificationCodePurpose,
  ): string {
    switch (purpose) {
      case 'register':
        return '注册';
      case 'reset-password':
        return '重置密码';
    }
  }
}
