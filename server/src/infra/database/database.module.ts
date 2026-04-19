import { Module } from '@nestjs/common';

import { InMemoryChatModelRepository } from './repositories/in-memory-chat-model.repository';

@Module({
  providers: [InMemoryChatModelRepository],
  exports: [InMemoryChatModelRepository],
})
export class DatabaseModule {}
