import { Injectable, NotFoundException } from '@nestjs/common';

import type { AuthUserEntity } from '../entities/auth-user.entity';
import { InMemoryAuthRepository } from '../repositories/in-memory-auth.repository';

@Injectable()
export class AuthIdentityService {
  constructor(
    private readonly authRepository: InMemoryAuthRepository,
  ) {}

  getActiveUserById(userId: string): AuthUserEntity {
    const user = this.authRepository.findActiveUserById(userId);

    if (!user) {
      throw new NotFoundException('用户不存在或已失效');
    }

    return user;
  }

  findDiscoverableUserByHandle(handle: string): AuthUserEntity | null {
    return this.authRepository.findUserByHandle(handle);
  }

  findActiveUserByHandle(handle: string): AuthUserEntity | null {
    return this.authRepository.findActiveUserByHandle(handle);
  }

  updateProfile(
    userId: string,
    params: {
      nickname?: string;
      avatarUrl?: string | null;
      discoveryMode?: 'public' | 'private';
    },
  ): AuthUserEntity {
    const user = this.getActiveUserById(userId);

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
    this.authRepository.saveUser(user);
    return user;
  }
}
