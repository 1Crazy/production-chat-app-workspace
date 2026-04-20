import { Injectable } from '@nestjs/common';

import {
  type PushRegistrationView,
  toPushRegistrationView,
} from '../dto/push-registration.dto';
import { RegisterPushTokenDto } from '../dto/register-push-token.dto';
import { PushRegistrationRepository } from '../repositories/push-registration.repository';

import type { DeviceSessionEntity } from '@app/modules/auth/entities/device-session.entity';

@Injectable()
export class NotificationsService {
  constructor(
    private readonly pushRegistrationRepository: PushRegistrationRepository,
  ) {}

  getHealth(): { module: string; status: string } {
    return {
      module: 'notifications',
      status: 'ready',
    };
  }

  async registerPushToken(params: {
    userId: string;
    session: DeviceSessionEntity;
    dto: RegisterPushTokenDto;
  }): Promise<PushRegistrationView> {
    const existingRegistration =
      await this.pushRegistrationRepository.findRegistrationByProviderAndToken({
        provider: params.dto.provider,
        token: params.dto.token.trim(),
      });

    let registration = existingRegistration;

    if (registration == null) {
      registration = await this.pushRegistrationRepository.createRegistration({
        userId: params.userId,
        sessionId: params.session.id,
        provider: params.dto.provider,
        token: params.dto.token.trim(),
        pushEnvironment: params.dto.pushEnvironment,
      });
    } else {
      registration.userId = params.userId;
      registration.sessionId = params.session.id;
      registration.pushEnvironment = params.dto.pushEnvironment;
      registration.lastRegisteredAt = new Date();
      registration.revokedAt = null;
      await this.pushRegistrationRepository.saveRegistration(registration);
    }

    await this.pushRegistrationRepository.revokeOtherSessionProviderRegistrations({
      sessionId: params.session.id,
      provider: params.dto.provider,
      excludedRegistrationId: registration.id,
    });

    return toPushRegistrationView(registration, params.session.id);
  }

  async listActiveRegistrations(
    userId: string,
    currentSessionId: string,
  ): Promise<PushRegistrationView[]> {
    const registrations =
      await this.pushRegistrationRepository.listActiveRegistrationsByUserId(
        userId,
      );

    return registrations.map((registration) => {
      return toPushRegistrationView(registration, currentSessionId);
    });
  }
}
