import { RateLimitService } from './rate-limit.service';
import type { RiskEventRecorderService } from './risk-event-recorder.service';

class InMemoryRedisService {
  private readonly counts = new Map<string, number>();
  readonly expiryByKey = new Map<string, number>();

  get instance() {
    return {
      incr: async (key: string) => {
        const nextValue = (this.counts.get(key) ?? 0) + 1;
        this.counts.set(key, nextValue);
        return nextValue;
      },
      pexpire: async (key: string, ttlMs: number) => {
        this.expiryByKey.set(key, ttlMs);
      },
    };
  }
}

describe('RateLimitService', () => {
  it('should reject over-limit requests and record a risk event', async () => {
    const redisService = new InMemoryRedisService();
    const riskEventRecorderService = {
      record: jest.fn().mockResolvedValue(undefined),
    } as unknown as RiskEventRecorderService;
    const service = new RateLimitService(
      redisService as never,
      riskEventRecorderService,
    );

    await service.consumeOrThrow({
      scope: 'messages.send',
      actorKey: 'user-1',
      limit: 1,
      windowMs: 60_000,
      message: '发送过于频繁，请稍后再试',
    });

    await expect(
      service.consumeOrThrow({
        scope: 'messages.send',
        actorKey: 'user-1',
        limit: 1,
        windowMs: 60_000,
        message: '发送过于频繁，请稍后再试',
        metadata: {
          userId: 'user-1',
        },
      }),
    ).rejects.toThrow('发送过于频繁，请稍后再试');

    expect(riskEventRecorderService.record).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'rate_limit_exceeded',
        scope: 'messages.send',
        actorKey: 'user-1',
        attempts: 2,
      }),
    );
  });
});
