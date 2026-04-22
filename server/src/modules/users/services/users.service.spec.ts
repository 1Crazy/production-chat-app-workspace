import { UsersService } from './users.service';

import type { RateLimitService } from '@app/infra/abuse/services/rate-limit.service';
import { InMemoryAuthRepository } from '@app/modules/auth/repositories/in-memory-auth.repository';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';

describe('UsersService', () => {
  function createFixture() {
    const authRepository = new InMemoryAuthRepository();
    const authIdentityService = new AuthIdentityService(authRepository);
    const rateLimitService = {
      consumeOrThrow: jest.fn().mockResolvedValue(undefined),
    } as unknown as RateLimitService;
    const service = new UsersService(authIdentityService, rateLimitService);

    return {
      authRepository,
      rateLimitService,
      service,
    };
  }

  it('should reject discovery requests when the limiter trips', async () => {
    const fixture = createFixture();
    (
      fixture.rateLimitService as unknown as {
        consumeOrThrow: jest.Mock;
      }
    ).consumeOrThrow.mockRejectedValueOnce(
      new Error('搜索过于频繁，请稍后再试'),
    );

    await expect(
      fixture.service.discoverByHandle('user-1', 'alice_user'),
    ).rejects.toThrow('搜索过于频繁，请稍后再试');
  });
});
