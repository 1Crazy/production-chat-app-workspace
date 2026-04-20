import { Injectable } from '@nestjs/common';

import { RedisService } from '@app/infra/cache/redis.service';

export interface RedisQueueJob<TPayload> {
  id: string;
  queueName: string;
  kind: string;
  payload: TPayload;
  attempts: number;
  maxAttempts: number;
  availableAt: string;
}

@Injectable()
export class RedisJobQueueService {
  constructor(private readonly redisService: RedisService) {}

  async enqueue<TPayload>(job: RedisQueueJob<TPayload>): Promise<void> {
    await this.redisService.instance.zadd(
      this.queueKey(job.queueName),
      Date.parse(job.availableAt),
      JSON.stringify(job),
    );
  }

  async dequeueDueJobs<TPayload>(params: {
    queueName: string;
    now: Date;
    limit: number;
  }): Promise<Array<RedisQueueJob<TPayload>>> {
    const response = await this.redisService.instance.eval(
      `
        local key = KEYS[1]
        local nowScore = tonumber(ARGV[1])
        local limit = tonumber(ARGV[2])
        local jobs = redis.call('ZRANGEBYSCORE', key, '-inf', nowScore, 'LIMIT', 0, limit)
        if #jobs == 0 then
          return jobs
        end
        for _, job in ipairs(jobs) do
          redis.call('ZREM', key, job)
        end
        return jobs
      `,
      1,
      this.queueKey(params.queueName),
      params.now.getTime(),
      params.limit,
    );

    if (!Array.isArray(response)) {
      return [];
    }

    return response
      .map((item) => {
        if (typeof item !== 'string') {
          return null;
        }

        return JSON.parse(item) as RedisQueueJob<TPayload>;
      })
      .filter((job): job is RedisQueueJob<TPayload> => job != null);
  }

  private queueKey(queueName: string): string {
    return `queue:${queueName}`;
  }
}
