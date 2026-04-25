import { Injectable } from '@nestjs/common';
import type { DeviceSession, User, VerificationCode } from '@prisma/client';

import type { AuthUserEntity } from '../entities/auth-user.entity';
import type { DeviceSessionEntity } from '../entities/device-session.entity';
import type {
  VerificationCodeEntity,
  VerificationCodePurpose,
} from '../entities/verification-code.entity';

import { AuthRepository } from './auth.repository';

import { PrismaService } from '@app/infra/database/prisma.service';

@Injectable()
export class PrismaAuthRepository extends AuthRepository {
  constructor(private readonly prismaService: PrismaService) {
    super();
  }

  override async createVerificationCode(
    identifier: string,
    purpose: VerificationCodePurpose,
    code: string,
    expiresAt: Date,
  ): Promise<VerificationCodeEntity> {
    const verificationCode = await this.prismaService.verificationCode.upsert({
      where: {
        identifier_purpose: {
          identifier,
          purpose,
        },
      },
      update: {
        purpose,
        code,
        createdAt: new Date(),
        expiresAt,
        consumedAt: null,
      },
      create: {
        identifier,
        purpose,
        code,
        expiresAt,
      },
    });

    return this.toVerificationCodeEntity(verificationCode);
  }

  override async findVerificationCode(
    identifier: string,
    purpose: VerificationCodePurpose,
  ): Promise<VerificationCodeEntity | null> {
    const verificationCode =
      await this.prismaService.verificationCode.findUnique({
        where: {
          identifier_purpose: {
            identifier,
            purpose,
          },
        },
      });

    return verificationCode
      ? this.toVerificationCodeEntity(verificationCode)
      : null;
  }

  override async saveVerificationCode(
    entity: VerificationCodeEntity,
  ): Promise<void> {
    await this.prismaService.verificationCode.upsert({
      where: {
        identifier_purpose: {
          identifier: entity.identifier,
          purpose: entity.purpose,
        },
      },
      update: {
        purpose: entity.purpose,
        code: entity.code,
        createdAt: entity.createdAt,
        expiresAt: entity.expiresAt,
        consumedAt: entity.consumedAt,
      },
      create: {
        identifier: entity.identifier,
        purpose: entity.purpose,
        code: entity.code,
        createdAt: entity.createdAt,
        expiresAt: entity.expiresAt,
        consumedAt: entity.consumedAt,
      },
    });
  }

  override async createUser(params: {
    identifier: string;
    nickname: string;
    handle: string;
    passwordHash?: string | null;
    passwordUpdatedAt?: Date | null;
  }): Promise<AuthUserEntity> {
    const user = await this.prismaService.user.create({
      data: {
        identifier: params.identifier,
        nickname: params.nickname,
        handle: params.handle,
        passwordHash: params.passwordHash ?? null,
        passwordUpdatedAt: params.passwordUpdatedAt ?? null,
      },
    });

    return this.toAuthUserEntity(user);
  }

  override async findUserByIdentifier(
    identifier: string,
  ): Promise<AuthUserEntity | null> {
    const user = await this.prismaService.user.findUnique({
      where: {
        identifier,
      },
    });

    return user ? this.toAuthUserEntity(user) : null;
  }

  override async findActiveUserById(
    userId: string,
  ): Promise<AuthUserEntity | null> {
    const user = await this.prismaService.user.findFirst({
      where: {
        id: userId,
        disabledAt: null,
      },
    });

    return user ? this.toAuthUserEntity(user) : null;
  }

  override async findUserByHandle(
    handle: string,
  ): Promise<AuthUserEntity | null> {
    const user = await this.prismaService.user.findUnique({
      where: {
        handle,
      },
    });

    return user ? this.toAuthUserEntity(user) : null;
  }

  override async findActiveUserByHandle(
    handle: string,
  ): Promise<AuthUserEntity | null> {
    const user = await this.prismaService.user.findFirst({
      where: {
        handle,
        disabledAt: null,
      },
    });

    return user ? this.toAuthUserEntity(user) : null;
  }

  override async saveUser(user: AuthUserEntity): Promise<void> {
    await this.prismaService.user.update({
      where: {
        id: user.id,
      },
      data: {
        nickname: user.nickname,
        handle: user.handle,
        passwordHash: user.passwordHash,
        passwordUpdatedAt: user.passwordUpdatedAt,
        avatarUrl: user.avatarUrl,
        discoveryMode: user.discoveryMode,
        disabledAt: user.disabledAt,
      },
    });
  }

  override async createSession(params: {
    userId: string;
    deviceName: string;
    refreshNonce: string;
  }): Promise<DeviceSessionEntity> {
    const session = await this.prismaService.deviceSession.create({
      data: {
        userId: params.userId,
        deviceName: params.deviceName,
        refreshNonce: params.refreshNonce,
      },
    });

    return this.toDeviceSessionEntity(session);
  }

  override async saveSession(session: DeviceSessionEntity): Promise<void> {
    await this.prismaService.deviceSession.update({
      where: {
        id: session.id,
      },
      data: {
        deviceName: session.deviceName,
        refreshNonce: session.refreshNonce,
        lastSeenAt: session.lastSeenAt,
        revokedAt: session.revokedAt,
      },
    });
  }

  override async findActiveSessionById(
    sessionId: string,
  ): Promise<DeviceSessionEntity | null> {
    const session = await this.prismaService.deviceSession.findFirst({
      where: {
        id: sessionId,
        revokedAt: null,
      },
    });

    return session ? this.toDeviceSessionEntity(session) : null;
  }

  override async listActiveSessionsByUserId(
    userId: string,
  ): Promise<DeviceSessionEntity[]> {
    const sessions = await this.prismaService.deviceSession.findMany({
      where: {
        userId,
        revokedAt: null,
      },
      orderBy: {
        lastSeenAt: 'desc',
      },
    });

    return sessions.map((session: DeviceSession) => {
      return this.toDeviceSessionEntity(session);
    });
  }

  override async revokeSession(
    sessionId: string,
  ): Promise<DeviceSessionEntity | null> {
    const session = await this.findActiveSessionById(sessionId);

    if (!session) {
      return null;
    }

    session.revokedAt = new Date();
    await this.saveSession(session);
    return session;
  }

  private toAuthUserEntity(user: User): AuthUserEntity {
    return {
      id: user.id,
      identifier: user.identifier,
      nickname: user.nickname,
      handle: user.handle,
      passwordHash: user.passwordHash,
      passwordUpdatedAt: user.passwordUpdatedAt,
      avatarUrl: user.avatarUrl,
      discoveryMode: user.discoveryMode as AuthUserEntity['discoveryMode'],
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
      disabledAt: user.disabledAt,
    };
  }

  private toVerificationCodeEntity(
    verificationCode: VerificationCode,
  ): VerificationCodeEntity {
    return {
      identifier: verificationCode.identifier,
      purpose: verificationCode.purpose as VerificationCodePurpose,
      code: verificationCode.code,
      createdAt: verificationCode.createdAt,
      expiresAt: verificationCode.expiresAt,
      consumedAt: verificationCode.consumedAt,
    };
  }

  private toDeviceSessionEntity(session: DeviceSession): DeviceSessionEntity {
    return {
      id: session.id,
      userId: session.userId,
      deviceName: session.deviceName,
      refreshNonce: session.refreshNonce,
      createdAt: session.createdAt,
      lastSeenAt: session.lastSeenAt,
      revokedAt: session.revokedAt,
    };
  }
}
