import { BadRequestException, Injectable } from '@nestjs/common';

import type { VerificationCodePurpose } from '../entities/verification-code.entity';
import { AuthRepository } from '../repositories/auth.repository';

@Injectable()
export class AuthVerificationCodeService {
  private readonly verificationCodeTtlSeconds = 60 * 10;

  constructor(private readonly authRepository: AuthRepository) {}

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
    return `${Math.floor(100000 + Math.random() * 900000)}`;
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
