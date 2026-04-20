import { Injectable, OnModuleDestroy } from '@nestjs/common';

import type { TypingUpdatedEvent } from '../dto/realtime-event.dto';
import { RealtimeTypingStore } from '../stores/realtime-typing.store';

@Injectable()
export class RealtimeTypingService implements OnModuleDestroy {
  private readonly typingTtlMs = 5 * 1000;
  private readonly timeoutByKey = new Map<string, NodeJS.Timeout>();

  constructor(private readonly realtimeTypingStore: RealtimeTypingStore) {}

  // 输入中状态只需要短时存在，超时后自动失效，避免客户端异常断线时状态一直悬挂。
  async setTyping(params: {
    conversationId: string;
    userId: string;
    isTyping: boolean;
    onExpired: (event: TypingUpdatedEvent) => void;
  }): Promise<TypingUpdatedEvent> {
    const key = this.buildKey(params.conversationId, params.userId);

    if (!params.isTyping) {
      return this.clearTyping({
        key,
        conversationId: params.conversationId,
        userId: params.userId,
      });
    }

    this.clearTimer(key);
    const expiresAt = await this.realtimeTypingStore.setTyping({
      conversationId: params.conversationId,
      userId: params.userId,
      ttlMs: this.typingTtlMs,
    });
    const timeout = setTimeout(() => {
      this.timeoutByKey.delete(key);
      void this.realtimeTypingStore
        .clearTyping({
          conversationId: params.conversationId,
          userId: params.userId,
        })
        .finally(() => {
          params.onExpired({
            conversationId: params.conversationId,
            userId: params.userId,
            isTyping: false,
            expiresAt: null,
          });
        });
    }, this.typingTtlMs);

    this.timeoutByKey.set(key, timeout);
    return {
      conversationId: params.conversationId,
      userId: params.userId,
      isTyping: true,
      expiresAt: expiresAt.toISOString(),
    };
  }

  onModuleDestroy(): void {
    for (const timeout of this.timeoutByKey.values()) {
      clearTimeout(timeout);
    }

    this.timeoutByKey.clear();
  }

  private async clearTyping(params: {
    key: string;
    conversationId: string;
    userId: string;
  }): Promise<TypingUpdatedEvent> {
    this.clearTimer(params.key);
    await this.realtimeTypingStore.clearTyping({
      conversationId: params.conversationId,
      userId: params.userId,
    });
    return {
      conversationId: params.conversationId,
      userId: params.userId,
      isTyping: false,
      expiresAt: null,
    };
  }

  private clearTimer(key: string): void {
    const timeout = this.timeoutByKey.get(key);

    if (!timeout) {
      return;
    }

    clearTimeout(timeout);
    this.timeoutByKey.delete(key);
  }

  private buildKey(conversationId: string, userId: string): string {
    return `${conversationId}:${userId}`;
  }
}
