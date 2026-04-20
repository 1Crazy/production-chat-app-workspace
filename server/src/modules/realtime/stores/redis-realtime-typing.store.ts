import { Injectable } from '@nestjs/common';

import { RealtimeTypingStore } from './realtime-typing.store';

import { RedisService } from '@app/infra/cache/redis.service';

@Injectable()
export class RedisRealtimeTypingStore extends RealtimeTypingStore {
  constructor(private readonly redisService: RedisService) {
    super();
  }

  override async setTyping(params: {
    conversationId: string;
    userId: string;
    ttlMs: number;
  }): Promise<Date> {
    const expiresAt = new Date(Date.now() + params.ttlMs);

    await this.redisService.instance.set(
      this.buildKey(params.conversationId, params.userId),
      expiresAt.toISOString(),
      'PX',
      params.ttlMs,
    );

    return expiresAt;
  }

  override async clearTyping(params: {
    conversationId: string;
    userId: string;
  }): Promise<void> {
    await this.redisService.instance.del(
      this.buildKey(params.conversationId, params.userId),
    );
  }

  private buildKey(conversationId: string, userId: string): string {
    return `chat:typing:${conversationId}:${userId}`;
  }
}
