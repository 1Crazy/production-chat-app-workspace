import { Module } from '@nestjs/common';

import { RedisJobQueueService } from './redis-job-queue.service';

import { CacheModule } from '@app/infra/cache/cache.module';

@Module({
  imports: [CacheModule],
  providers: [RedisJobQueueService],
  exports: [RedisJobQueueService],
})
export class QueueModule {}
