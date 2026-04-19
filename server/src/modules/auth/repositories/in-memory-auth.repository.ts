import { randomUUID } from 'node:crypto';

import { Injectable } from '@nestjs/common';

import type { AuthUserEntity } from '../entities/auth-user.entity';
import type { DeviceSessionEntity } from '../entities/device-session.entity';
import type { VerificationCodeEntity } from '../entities/verification-code.entity';

@Injectable()
export class InMemoryAuthRepository {
  private readonly usersById = new Map<string, AuthUserEntity>();
  private readonly userIdsByIdentifier = new Map<string, string>();
  private readonly userIdsByHandle = new Map<string, string>();
  private readonly sessionsById = new Map<string, DeviceSessionEntity>();
  private readonly verificationCodes = new Map<string, VerificationCodeEntity>();

  createVerificationCode(
    identifier: string,
    code: string,
    expiresAt: Date,
  ): VerificationCodeEntity {
    const entity: VerificationCodeEntity = {
      identifier,
      code,
      createdAt: new Date(),
      expiresAt,
      consumedAt: null,
    };

    this.verificationCodes.set(identifier, entity);
    return entity;
  }

  findVerificationCode(identifier: string): VerificationCodeEntity | null {
    return this.verificationCodes.get(identifier) ?? null;
  }

  saveVerificationCode(entity: VerificationCodeEntity): void {
    this.verificationCodes.set(entity.identifier, entity);
  }

  createUser(params: {
    identifier: string;
    nickname: string;
    handle: string;
  }): AuthUserEntity {
    const now = new Date();
    const user: AuthUserEntity = {
      id: randomUUID(),
      identifier: params.identifier,
      nickname: params.nickname,
      handle: params.handle,
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

  findUserByIdentifier(identifier: string): AuthUserEntity | null {
    const userId = this.userIdsByIdentifier.get(identifier);

    if (!userId) {
      return null;
    }

    return this.usersById.get(userId) ?? null;
  }

  findActiveUserById(userId: string): AuthUserEntity | null {
    const user = this.usersById.get(userId) ?? null;

    if (!user || user.disabledAt) {
      return null;
    }

    return user;
  }

  findUserByHandle(handle: string): AuthUserEntity | null {
    const userId = this.userIdsByHandle.get(handle);

    if (!userId) {
      return null;
    }

    return this.usersById.get(userId) ?? null;
  }

  findActiveUserByHandle(handle: string): AuthUserEntity | null {
    const user = this.findUserByHandle(handle);

    if (!user || user.disabledAt) {
      return null;
    }

    return user;
  }

  saveUser(user: AuthUserEntity): void {
    this.usersById.set(user.id, user);
    this.userIdsByIdentifier.set(user.identifier, user.id);
    this.userIdsByHandle.set(user.handle, user.id);
  }

  createSession(params: {
    userId: string;
    deviceName: string;
    refreshNonce: string;
  }): DeviceSessionEntity {
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

  saveSession(session: DeviceSessionEntity): void {
    this.sessionsById.set(session.id, session);
  }

  findActiveSessionById(sessionId: string): DeviceSessionEntity | null {
    const session = this.sessionsById.get(sessionId) ?? null;

    if (!session || session.revokedAt) {
      return null;
    }

    return session;
  }

  listActiveSessionsByUserId(userId: string): DeviceSessionEntity[] {
    return Array.from(this.sessionsById.values())
      .filter((session) => session.userId === userId && !session.revokedAt)
      .sort((left, right) => {
        return right.lastSeenAt.getTime() - left.lastSeenAt.getTime();
      });
  }

  revokeSession(sessionId: string): DeviceSessionEntity | null {
    const session = this.sessionsById.get(sessionId) ?? null;

    if (!session || session.revokedAt) {
      return null;
    }

    session.revokedAt = new Date();
    this.sessionsById.set(session.id, session);
    return session;
  }
}
