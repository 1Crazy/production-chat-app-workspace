import { Module } from '@nestjs/common';

import { MessagesController } from './controllers/messages.controller';
import { MessagesService } from './services/messages.service';

import { DatabaseModule } from '@app/infra/database/database.module';
import { AuthModule } from '@app/modules/auth/auth.module';

@Module({
  imports: [DatabaseModule, AuthModule],
  controllers: [MessagesController],
  providers: [MessagesService],
  exports: [MessagesService],
})
export class MessagesModule {}
