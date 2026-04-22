import { Injectable } from '@nestjs/common';
import type { PushRegistration } from '@prisma/client';

import type { PushRegistrationEntity } from '../entities/push-registration.entity';

import { PushRegistrationRepository } from './push-registration.repository';

import { PrismaService } from '@app/infra/database/prisma.service';

@Injectable()
export class PrismaPushRegistrationRepository
  extends PushRegistrationRepository
{
  constructor(private readonly prismaService: PrismaService) {
    super();
  }

  override async findRegistrationByProviderAndToken(params: {
    provider: PushRegistrationEntity['provider'];
    token: string;
  }): Promise<PushRegistrationEntity | null> {
    const registration = await this.prismaService.pushRegistration.findUnique({
      where: {
        provider_token: {
          provider: params.provider,
          token: params.token,
        },
      },
    });

    return registration ? this.toEntity(registration) : null;
  }

  override async createRegistration(params: {
    userId: string;
    sessionId: string;
    provider: PushRegistrationEntity['provider'];
    token: string;
    pushEnvironment: PushRegistrationEntity['pushEnvironment'];
    privacyModeEnabled: boolean;
  }): Promise<PushRegistrationEntity> {
    const registration = await this.prismaService.pushRegistration.create({
      data: {
        userId: params.userId,
        sessionId: params.sessionId,
        provider: params.provider,
        token: params.token,
        pushEnvironment: params.pushEnvironment,
        privacyModeEnabled: params.privacyModeEnabled,
      },
    });

    return this.toEntity(registration);
  }

  override async saveRegistration(
    entity: PushRegistrationEntity,
  ): Promise<void> {
    await this.prismaService.pushRegistration.update({
      where: {
        id: entity.id,
      },
      data: {
        userId: entity.userId,
        sessionId: entity.sessionId,
        provider: entity.provider,
        token: entity.token,
        pushEnvironment: entity.pushEnvironment,
        privacyModeEnabled: entity.privacyModeEnabled,
        lastRegisteredAt: entity.lastRegisteredAt,
        revokedAt: entity.revokedAt,
      },
    });
  }

  override async revokeOtherSessionProviderRegistrations(params: {
    sessionId: string;
    provider: PushRegistrationEntity['provider'];
    excludedRegistrationId: string;
  }): Promise<void> {
    await this.prismaService.pushRegistration.updateMany({
      where: {
        sessionId: params.sessionId,
        provider: params.provider,
        revokedAt: null,
        id: {
          not: params.excludedRegistrationId,
        },
      },
      data: {
        revokedAt: new Date(),
      },
    });
  }

  override async listActiveRegistrationsByUserId(
    userId: string,
  ): Promise<PushRegistrationEntity[]> {
    const registrations = await this.prismaService.pushRegistration.findMany({
      where: {
        userId,
        revokedAt: null,
      },
      orderBy: {
        updatedAt: 'desc',
      },
    });

    return registrations.map((registration) => this.toEntity(registration));
  }

  private toEntity(registration: PushRegistration): PushRegistrationEntity {
    return {
      id: registration.id,
      userId: registration.userId,
      sessionId: registration.sessionId,
      provider: registration.provider as PushRegistrationEntity['provider'],
      token: registration.token,
      pushEnvironment:
        registration.pushEnvironment as PushRegistrationEntity['pushEnvironment'],
      privacyModeEnabled: registration.privacyModeEnabled,
      createdAt: registration.createdAt,
      updatedAt: registration.updatedAt,
      lastRegisteredAt: registration.lastRegisteredAt,
      revokedAt: registration.revokedAt,
    };
  }
}
