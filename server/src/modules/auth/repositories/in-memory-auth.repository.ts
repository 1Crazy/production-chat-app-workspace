import { randomUUID } from 'node:crypto';

import { Injectable } from '@nestjs/common';

import type { AuthUserEntity } from '../entities/auth-user.entity';
import type { DeviceSessionEntity } from '../entities/device-session.entity';
import type {
  VerificationCodeEntity,
  VerificationCodePurpose,
} from '../entities/verification-code.entity';

import { AuthRepository } from './auth.repository';

@Injectable()
export class InMemoryAuthRepository extends AuthRepository {
  private readonly usersById = new Map<string, AuthUserEntity>();
  private readonly userIdsByIdentifier = new Map<string, string>();
  private readonly userIdsByHandle = new Map<string, string>();
  private readonly sessionsById = new Map<string, DeviceSessionEntity>();
  private readonly verificationCodes = new Map<
    string,
    VerificationCodeEntity
  >();

  override async createVerificationCode(
    identifier: string,
    purpose: VerificationCodePurpose,
    code: string,
    expiresAt: Date,
  ): Promise<VerificationCodeEntity> {
    const entity: VerificationCodeEntity = {
      identifier,
      purpose,
      code,
      createdAt: new Date(),
      expiresAt,
      consumedAt: null,
    };

    this.verificationCodes.set(
      this.buildVerificationCodeKey(identifier, purpose),
      entity,
    );
    return entity;
  }

  override async findVerificationCode(
    identifier: string,
    purpose: VerificationCodePurpose,
  ): Promise<VerificationCodeEntity | null> {
    return (
      this.verificationCodes.get(
        this.buildVerificationCodeKey(identifier, purpose),
      ) ?? null
    );
  }

  override async saveVerificationCode(
    entity: VerificationCodeEntity,
  ): Promise<void> {
    this.verificationCodes.set(
      this.buildVerificationCodeKey(entity.identifier, entity.purpose),
      entity,
    );
  }

  override async createUser(params: {
    identifier: string;
    nickname: string;
    handle: string;
    passwordHash?: string | null;
    passwordUpdatedAt?: Date | null;
  }): Promise<AuthUserEntity> {
    const now = new Date();
    const user: AuthUserEntity = {
      id: randomUUID(),
      identifier: params.identifier,
      nickname: params.nickname,
      handle: params.handle,
      passwordHash: params.passwordHash ?? null,
      passwordUpdatedAt: params.passwordUpdatedAt ?? null,
      friendRequestLastViewedAt: null,
      avatarUrl: null,
      discoveryMode: 'public',
      createdAt: now,
      updatedAt: now,
      disabledAt: null,
    };

    this.usersById.set(user.id, user);
    this.userIdsByIdentifier.set(user.identifier, user.id);
    this.userIdsByHandle.set(user.handle, user.id);
    return user;
  }

  override async findUserByIdentifier(
    identifier: string,
  ): Promise<AuthUserEntity | null> {
    const userId = this.userIdsByIdentifier.get(identifier);

    if (!userId) {
      return null;
    }

    return this.usersById.get(userId) ?? null;
  }

  override async findActiveUserById(
    userId: string,
  ): Promise<AuthUserEntity | null> {
    const user = this.usersById.get(userId) ?? null;

    if (!user || user.disabledAt) {
      return null;
    }

    return user;
  }

  override async findUserByHandle(
    handle: string,
  ): Promise<AuthUserEntity | null> {
    const userId = this.userIdsByHandle.get(handle);

    if (!userId) {
      return null;
    }

    return this.usersById.get(userId) ?? null;
  }

  override async findActiveUserByHandle(
    handle: string,
  ): Promise<AuthUserEntity | null> {
    const user = await this.findUserByHandle(handle);

    if (!user || user.disabledAt) {
      return null;
    }

    return user;
  }

  override async saveUser(user: AuthUserEntity): Promise<void> {
    this.usersById.set(user.id, user);
    this.userIdsByIdentifier.set(user.identifier, user.id);
    this.userIdsByHandle.set(user.handle, user.id);
  }

  override async createSession(params: {
    userId: string;
    deviceName: string;
    refreshNonce: string;
  }): Promise<DeviceSessionEntity> {
    const now = new Date();
    const session: DeviceSessionEntity = {
      id: randomUUID(),
      userId: params.userId,
      deviceName: params.deviceName,
      refreshNonce: params.refreshNonce,
      createdAt: now,
      lastSeenAt: now,
      revokedAt: null,
    };

    this.sessionsById.set(session.id, session);
    return session;
  }

  override async saveSession(session: DeviceSessionEntity): Promise<void> {
    this.sessionsById.set(session.id, session);
  }

  override async findActiveSessionById(
    sessionId: string,
  ): Promise<DeviceSessionEntity | null> {
    const session = this.sessionsById.get(sessionId) ?? null;

    if (!session || session.revokedAt) {
      return null;
    }

    return session;
  }

  override async listActiveSessionsByUserId(
    userId: string,
  ): Promise<DeviceSessionEntity[]> {
    return Array.from(this.sessionsById.values())
      .filter((session) => session.userId === userId && !session.revokedAt)
      .sort((left, right) => {
        return right.lastSeenAt.getTime() - left.lastSeenAt.getTime();
      });
  }

  override async revokeSession(
    sessionId: string,
  ): Promise<DeviceSessionEntity | null> {
    const session = this.sessionsById.get(sessionId) ?? null;

    if (!session || session.revokedAt) {
      return null;
    }

    session.revokedAt = new Date();
    this.sessionsById.set(session.id, session);
    return session;
  }

  private buildVerificationCodeKey(
    identifier: string,
    purpose: VerificationCodePurpose,
  ): string {
    return `${identifier}:${purpose}`;
  }
}
