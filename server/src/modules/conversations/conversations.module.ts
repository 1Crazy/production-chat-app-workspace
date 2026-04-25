import { Module } from '@nestjs/common';

import { ConversationsController } from './controllers/conversations.controller';
import { ConversationsService } from './services/conversations.service';

import { AbuseModule } from '@app/infra/abuse/abuse.module';
import { DatabaseModule } from '@app/infra/database/database.module';
import { AuthModule } from '@app/modules/auth/auth.module';
import { FriendshipsModule } from '@app/modules/friendships/friendships.module';
import { RealtimeModule } from '@app/modules/realtime/realtime.module';

@Module({
  imports: [
    AbuseModule,
    DatabaseModule,
    AuthModule,
    FriendshipsModule,
    RealtimeModule,
  ],
  controllers: [ConversationsController],
  providers: [ConversationsService],
  exports: [ConversationsService],
})
export class ConversationsModule {}
