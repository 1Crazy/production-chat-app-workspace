import { Module } from '@nestjs/common';

import { NotificationsController } from './controllers/notifications.controller';
import { PrismaPushRegistrationRepository } from './repositories/prisma-push-registration.repository';
import { PushRegistrationRepository } from './repositories/push-registration.repository';
import { NotificationsService } from './services/notifications.service';

import { DatabaseModule } from '@app/infra/database/database.module';
import { AuthModule } from '@app/modules/auth/auth.module';

@Module({
  imports: [AuthModule, DatabaseModule],
  controllers: [NotificationsController],
  providers: [
    NotificationsService,
    PrismaPushRegistrationRepository,
    {
      provide: PushRegistrationRepository,
      useExisting: PrismaPushRegistrationRepository,
    },
  ],
  exports: [NotificationsService],
})
export class NotificationsModule {}
