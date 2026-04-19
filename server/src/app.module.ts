import { Module } from '@nestjs/common';

import { CacheModule } from './infra/cache/cache.module';
import { AppConfigModule } from './infra/config/app-config.module';
import { DatabaseModule } from './infra/database/database.module';
import { ObservabilityModule } from './infra/observability/observability.module';
import { QueueModule } from './infra/queue/queue.module';
import { AdminModule } from './modules/admin/admin.module';
import { AuthModule } from './modules/auth/auth.module';
import { ConversationsModule } from './modules/conversations/conversations.module';
import { GroupsModule } from './modules/groups/groups.module';
import { MediaModule } from './modules/media/media.module';
import { MessagesModule } from './modules/messages/messages.module';
import { ModerationModule } from './modules/moderation/moderation.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { UsersModule } from './modules/users/users.module';

@Module({
  imports: [
    AppConfigModule,
    DatabaseModule,
    CacheModule,
    QueueModule,
    ObservabilityModule,
    AuthModule,
    UsersModule,
    ConversationsModule,
    MessagesModule,
    GroupsModule,
    MediaModule,
    NotificationsModule,
    ModerationModule,
    AdminModule,
  ],
})
export class AppModule {}
