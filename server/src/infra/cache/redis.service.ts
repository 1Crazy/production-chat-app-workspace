import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import Redis from 'ioredis';

import { AppConfigService } from '@app/infra/config/app-config.service';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private readonly client: Redis;

  constructor(appConfigService: AppConfigService) {
    this.client = new Redis(appConfigService.redisUrl, {
      lazyConnect: true,
      // 单个命令最多重试 20 次，防止 Redis 不可用时请求永久挂起。
      maxRetriesPerRequest: 20,
      enableReadyCheck: true,
    });
    this.client.on('ready', () => {
      this.logger.log('Redis connection ready');
    });
    this.client.on('error', (error) => {
      this.logger.error(`Redis error: ${error.message}`);
    });
  }

  get instance(): Redis {
    return this.client;
  }

  async onModuleInit(): Promise<void> {
    try {
      if (this.client.status === 'wait') {
        await this.client.connect();
      }

      const pingResult = await this.client.ping();

      if (pingResult !== 'PONG') {
        throw new Error(`unexpected ping response: ${pingResult}`);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : 'unknown error';

      throw new Error(
        `Redis is a required dependency for chat realtime, presence, idempotency, and Socket.IO coordination. Startup aborted because Redis is unavailable: ${message}`,
      );
    }
  }

  async onModuleDestroy(): Promise<void> {
    if (this.client.status === 'wait') {
      this.client.disconnect();
      return;
    }

    if (this.client.status !== 'end') {
      await this.client.quit();
    }
  }
}
