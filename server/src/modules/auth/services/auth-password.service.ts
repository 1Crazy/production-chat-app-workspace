import { BadRequestException, Injectable } from '@nestjs/common';
import { argon2id, hash, verify } from 'argon2';

@Injectable()
export class AuthPasswordService {
  private readonly passwordMinLength = 8;
  private readonly passwordMaxLength = 72;

  async hashPassword(password: string): Promise<string> {
    this.assertPasswordRules(password);
    return hash(password, {
      type: argon2id,
    });
  }

  async verifyPassword(
    password: string,
    passwordHash: string,
  ): Promise<boolean> {
    if (!passwordHash.startsWith('$argon2')) {
      return false;
    }

    return verify(passwordHash, password);
  }

  assertPasswordRules(password: string): void {
    if (password.length < this.passwordMinLength) {
      throw new BadRequestException('密码至少需要 8 个字符');
    }

    if (password.length > this.passwordMaxLength) {
      throw new BadRequestException('密码最多支持 72 个字符');
    }

    if (!/[A-Za-z]/.test(password) || !/\d/.test(password)) {
      throw new BadRequestException('密码需要同时包含字母和数字');
    }
  }
}
