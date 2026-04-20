import { Injectable } from '@nestjs/common';

import { MessageIdempotencyStore } from './message-idempotency.store';

import { RedisService } from '@app/infra/cache/redis.service';

@Injectable()
export class RedisMessageIdempotencyStore extends MessageIdempotencyStore {
  private readonly pendingValue = 'PENDING';
  private readonly pendingTtlSeconds = 5 * 60;
  private readonly boundTtlSeconds = 7 * 24 * 60 * 60;

  constructor(private readonly redisService: RedisService) {
    super();
  }

  override async getBoundMessageId(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
  }): Promise<string | null> {
    const value = await this.redisService.instance.get(this.buildKey(params));

    if (!value || value === this.pendingValue) {
      return null;
    }

    return value;
  }

  override async reserve(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
  }): Promise<boolean> {
    const result = await this.redisService.instance.set(
      this.buildKey(params),
      this.pendingValue,
      'EX',
      this.pendingTtlSeconds,
      'NX',
    );

    return result === 'OK';
  }

  override async bind(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
    messageId: string;
  }): Promise<void> {
    await this.redisService.instance.set(
      this.buildKey(params),
      params.messageId,
      'EX',
      this.boundTtlSeconds,
    );
  }

  override async release(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
  }): Promise<void> {
    await this.redisService.instance.del(this.buildKey(params));
  }

  private buildKey(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
  }): string {
    return `chat:message-idempotency:${params.conversationId}:${params.senderId}:${params.clientMessageId}`;
  }
}
