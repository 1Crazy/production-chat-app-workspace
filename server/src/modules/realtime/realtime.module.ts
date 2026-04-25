import { forwardRef, Module } from '@nestjs/common';

import { ChatGateway } from './gateways/chat.gateway';
import { RealtimeBroadcastService } from './services/realtime-broadcast.service';
import { RealtimeConnectionService } from './services/realtime-connection.service';
import { RealtimeHeartbeatService } from './services/realtime-heartbeat.service';
import { RealtimePresenceService } from './services/realtime-presence.service';
import { RealtimeSocketAdapterService } from './services/realtime-socket-adapter.service';
import { RealtimeTypingService } from './services/realtime-typing.service';
import { RealtimePresenceStore } from './stores/realtime-presence.store';
import { RealtimeTypingStore } from './stores/realtime-typing.store';
import { RedisRealtimePresenceStore } from './stores/redis-realtime-presence.store';
import { RedisRealtimeTypingStore } from './stores/redis-realtime-typing.store';

import { CacheModule } from '@app/infra/cache/cache.module';
import { DatabaseModule } from '@app/infra/database/database.module';
import { AuthModule } from '@app/modules/auth/auth.module';

@Module({
  imports: [forwardRef(() => AuthModule), CacheModule, DatabaseModule],
  providers: [
    RealtimePresenceService,
    RealtimeBroadcastService,
    RealtimeConnectionService,
    RealtimeHeartbeatService,
    RealtimeSocketAdapterService,
    RealtimeTypingService,
    RedisRealtimePresenceStore,
    RedisRealtimeTypingStore,
    {
      provide: RealtimePresenceStore,
      useExisting: RedisRealtimePresenceStore,
    },
    {
      provide: RealtimeTypingStore,
      useExisting: RedisRealtimeTypingStore,
    },
    ChatGateway,
  ],
  exports: [RealtimePresenceService, RealtimeTypingService, ChatGateway],
})
export class RealtimeModule {}
