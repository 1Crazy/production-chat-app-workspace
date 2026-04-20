import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { createAdapter } from '@socket.io/redis-adapter';
import type Redis from 'ioredis';

import type { GatewayServer } from '../types/authenticated-socket.type';

import { RedisService } from '@app/infra/cache/redis.service';

@Injectable()
export class RealtimeSocketAdapterService
  implements OnModuleInit, OnModuleDestroy
{
  private readonly logger = new Logger(RealtimeSocketAdapterService.name);
  private pubClient: Redis | null = null;
  private subClient: Redis | null = null;
  private adapterFactory: ReturnType<typeof createAdapter> | null = null;

  constructor(private readonly redisService: RedisService) {}

  async onModuleInit(): Promise<void> {
    this.pubClient = this.redisService.instance.duplicate();
    this.subClient = this.redisService.instance.duplicate();

    await Promise.all([
      this.connectClient(this.pubClient),
      this.connectClient(this.subClient),
    ]);
    this.adapterFactory = createAdapter(this.pubClient, this.subClient);
  }

  async onModuleDestroy(): Promise<void> {
    await Promise.all([
      this.quitClient(this.pubClient),
      this.quitClient(this.subClient),
    ]);
  }

  apply(server: GatewayServer): void {
    if (!this.adapterFactory || typeof server.adapter !== 'function') {
      return;
    }

    server.adapter(this.adapterFactory);
    this.logger.log('Socket.IO Redis adapter enabled');
  }

  private async connectClient(client: Redis | null): Promise<void> {
    if (!client || client.status !== 'wait') {
      return;
    }

    await client.connect();
  }

  private async quitClient(client: Redis | null): Promise<void> {
    if (!client) {
      return;
    }

    if (client.status === 'wait') {
      client.disconnect();
      return;
    }

    if (client.status !== 'end') {
      await client.quit();
    }
  }
}
