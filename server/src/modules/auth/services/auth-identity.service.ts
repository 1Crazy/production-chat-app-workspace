import { Injectable, NotFoundException } from '@nestjs/common';

import type { AuthUserEntity } from '../entities/auth-user.entity';
import { AuthRepository } from '../repositories/auth.repository';

@Injectable()
export class AuthIdentityService {
  constructor(
    private readonly authRepository: AuthRepository,
  ) {}

  async getActiveUserById(userId: string): Promise<AuthUserEntity> {
    const user = await this.authRepository.findActiveUserById(userId);

    if (!user) {
      throw new NotFoundException('用户不存在或已失效');
    }

    return user;
  }

  findDiscoverableUserByHandle(
    handle: string,
  ): Promise<AuthUserEntity | null> {
    return this.authRepository.findUserByHandle(handle);
  }

  findActiveUserByHandle(handle: string): Promise<AuthUserEntity | null> {
    return this.authRepository.findActiveUserByHandle(handle);
  }

  async updateProfile(
    userId: string,
    params: {
      nickname?: string;
      avatarUrl?: string | null;
      discoveryMode?: 'public' | 'private';
    },
  ): Promise<AuthUserEntity> {
    const user = await this.getActiveUserById(userId);

    if (params.nickname != null) {
      user.nickname = params.nickname;
    }

    if (params.avatarUrl !== undefined) {
      user.avatarUrl = params.avatarUrl;
    }

    if (params.discoveryMode != null) {
      user.discoveryMode = params.discoveryMode;
    }

    user.updatedAt = new Date();
    await this.authRepository.saveUser(user);
    return user;
  }
}
