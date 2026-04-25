import { Injectable } from '@nestjs/common';

import type { NotificationSyncStateDto } from '../dto/notification-sync-state.dto';
import {
  type PushRegistrationView,
  toPushRegistrationView,
} from '../dto/push-registration.dto';
import { RegisterPushTokenDto } from '../dto/register-push-token.dto';
import type { SyncNotificationStateDto } from '../dto/sync-notification-state.dto';
import { PushRegistrationRepository } from '../repositories/push-registration.repository';

import { NotificationPushDispatcherService } from './notification-push-dispatcher.service';
import { NotificationSyncStateService } from './notification-sync-state.service';

import type { DeviceSessionEntity } from '@app/modules/auth/entities/device-session.entity';

@Injectable()
export class NotificationsService {
  constructor(
    private readonly pushRegistrationRepository: PushRegistrationRepository,
    private readonly pushDispatcherService: NotificationPushDispatcherService,
    private readonly syncStateService: NotificationSyncStateService,
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
        privacyModeEnabled: params.dto.privacyModeEnabled ?? false,
      });
    } else {
      registration.userId = params.userId;
      registration.sessionId = params.session.id;
      registration.pushEnvironment = params.dto.pushEnvironment;
      registration.privacyModeEnabled = params.dto.privacyModeEnabled ?? false;
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

    return registrations
      .map((registration) => {
        return toPushRegistrationView(registration, currentSessionId);
      })
      .sort((left, right) => {
        return right.updatedAt.localeCompare(left.updatedAt);
      });
  }

  dispatchOfflineMessagePush(params: {
    conversationId: string;
    senderUserId: string;
    messageId: string;
  }): Promise<void> {
    return this.pushDispatcherService.dispatchOfflineMessagePush(params);
  }

  syncState(
    userId: string,
    dto: SyncNotificationStateDto,
  ): Promise<NotificationSyncStateDto> {
    return this.syncStateService.syncState(userId, dto);
  }
}
