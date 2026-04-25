import { HttpException, HttpStatus, Injectable } from '@nestjs/common';

import { RiskEventRecorderService } from './risk-event-recorder.service';

import { RedisService } from '@app/infra/cache/redis.service';

@Injectable()
export class RateLimitService {
  constructor(
    private readonly redisService: RedisService,
    private readonly riskEventRecorderService: RiskEventRecorderService,
  ) {}

  async reset(params: {
    scope: string;
    actorKey: string;
  }): Promise<void> {
    const key = this.buildKey(params.scope, params.actorKey);
    await this.redisService.instance.del(key);
  }

  async consumeOrThrow(params: {
    scope: string;
    actorKey: string;
    limit: number;
    windowMs: number;
    message: string;
    metadata?: Record<string, string | number | boolean | null>;
  }): Promise<void> {
    const key = this.buildKey(params.scope, params.actorKey);
    const attempts = await this.redisService.instance.incr(key);

    if (attempts === 1) {
      await this.redisService.instance.pexpire(key, params.windowMs);
    }

    if (attempts <= params.limit) {
      return;
    }

    await this.riskEventRecorderService.record({
      type: 'rate_limit_exceeded',
      scope: params.scope,
      actorKey: params.actorKey,
      limit: params.limit,
      windowMs: params.windowMs,
      attempts,
      metadata: params.metadata,
    });

    throw new HttpException(params.message, HttpStatus.TOO_MANY_REQUESTS);
  }

  private buildKey(scope: string, actorKey: string): string {
    return `rate-limit:${scope}:${actorKey.trim().toLowerCase()}`;
  }
}
