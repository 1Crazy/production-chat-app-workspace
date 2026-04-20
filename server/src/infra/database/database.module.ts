import { Module } from '@nestjs/common';

import { PrismaService } from './prisma.service';
import { ChatModelRepository } from './repositories/chat-model.repository';
import { PrismaChatModelRepository } from './repositories/prisma-chat-model.repository';

@Module({
  providers: [
    PrismaService,
    PrismaChatModelRepository,
    {
      provide: ChatModelRepository,
      useExisting: PrismaChatModelRepository,
    },
  ],
  exports: [PrismaService, ChatModelRepository],
})
export class DatabaseModule {}
