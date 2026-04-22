import { Module } from '@nestjs/common';

import { MessagesController } from './controllers/messages.controller';
import { MessagesService } from './services/messages.service';
import { MessageIdempotencyStore } from './stores/message-idempotency.store';
import { RedisMessageIdempotencyStore } from './stores/redis-message-idempotency.store';

import { AbuseModule } from '@app/infra/abuse/abuse.module';
import { CacheModule } from '@app/infra/cache/cache.module';
import { DatabaseModule } from '@app/infra/database/database.module';
import { AuthModule } from '@app/modules/auth/auth.module';
import { MediaModule } from '@app/modules/media/media.module';
import { NotificationsModule } from '@app/modules/notifications/notifications.module';
import { RealtimeModule } from '@app/modules/realtime/realtime.module';

@Module({
  imports: [
    AbuseModule,
    CacheModule,
    DatabaseModule,
    AuthModule,
    MediaModule,
    NotificationsModule,
    RealtimeModule,
  ],
  controllers: [MessagesController],
  providers: [
    MessagesService,
    RedisMessageIdempotencyStore,
    {
      provide: MessageIdempotencyStore,
      useExisting: RedisMessageIdempotencyStore,
    },
  ],
  exports: [MessagesService],
})
export class MessagesModule {}
