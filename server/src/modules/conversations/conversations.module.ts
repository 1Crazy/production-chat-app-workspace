import { Module } from '@nestjs/common';

import { ConversationsController } from './controllers/conversations.controller';
import { ConversationsService } from './services/conversations.service';

import { DatabaseModule } from '@app/infra/database/database.module';
import { AuthModule } from '@app/modules/auth/auth.module';

@Module({
  imports: [DatabaseModule, AuthModule],
  controllers: [ConversationsController],
  providers: [ConversationsService],
  exports: [ConversationsService],
})
export class ConversationsModule {}
