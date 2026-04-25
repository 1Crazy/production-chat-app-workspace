import { Module } from '@nestjs/common';

import { NotificationsController } from './controllers/notifications.controller';
import { PrismaPushRegistrationRepository } from './repositories/prisma-push-registration.repository';
import { PushRegistrationRepository } from './repositories/push-registration.repository';
import { ApnsPushDeliveryProvider } from './services/apns-push-delivery.provider';
import { DefaultPushDeliveryProvider } from './services/default-push-delivery.provider';
import { FcmHttpV1PushDeliveryProvider } from './services/fcm-http-v1-push-delivery.provider';
import { NotificationPushDispatcherService } from './services/notification-push-dispatcher.service';
import { NotificationSyncStateService } from './services/notification-sync-state.service';
import { NotificationsService } from './services/notifications.service';
import {
  LoggingPushDeliveryProvider,
  PushDeliveryProvider,
} from './services/push-delivery.provider';

import { DatabaseModule } from '@app/infra/database/database.module';
import { AuthModule } from '@app/modules/auth/auth.module';
import { RealtimeModule } from '@app/modules/realtime/realtime.module';

@Module({
  imports: [AuthModule, DatabaseModule, RealtimeModule],
  controllers: [NotificationsController],
  providers: [
    NotificationsService,
    NotificationPushDispatcherService,
    NotificationSyncStateService,
    ApnsPushDeliveryProvider,
    DefaultPushDeliveryProvider,
    FcmHttpV1PushDeliveryProvider,
    LoggingPushDeliveryProvider,
    PrismaPushRegistrationRepository,
    {
      provide: PushDeliveryProvider,
      useExisting: DefaultPushDeliveryProvider,
    },
    {
      provide: PushRegistrationRepository,
      useExisting: PrismaPushRegistrationRepository,
    },
  ],
  exports: [NotificationsService],
})
export class NotificationsModule {}
