import { InMemoryAuthRepository } from '../repositories/in-memory-auth.repository';

import { AuthPasswordService } from './auth-password.service';
import { AuthTokenService } from './auth-token.service';
import { AuthService } from './auth.service';

import type { RateLimitService } from '@app/infra/abuse/services/rate-limit.service';
import type { AppConfigService } from '@app/infra/config/app-config.service';
import type { ChatGateway } from '@app/modules/realtime/gateways/chat.gateway';

describe('AuthService', () => {
  function createFixture() {
    const authRepository = new InMemoryAuthRepository();
    const authTokenService = new AuthTokenService({
      get jwtAccessSecret() {
        return 'access-secret';
      },
      get jwtRefreshSecret() {
        return 'refresh-secret';
      },
    } as unknown as AppConfigService);
    const chatGateway = {
      disconnectSession: jest.fn(),
    } as unknown as ChatGateway;
    const rateLimitService = {
      consumeOrThrow: jest.fn().mockResolvedValue(undefined),
    } as unknown as RateLimitService;
    const authPasswordService = new AuthPasswordService();
    const service = new AuthService(
      authRepository,
      authPasswordService,
      authTokenService,
      rateLimitService,
      chatGateway,
    );

    return {
      authRepository,
      rateLimitService,
      service,
    };
  }

  it('should allocate a unique handle when normalized identifiers collide', async () => {
    const fixture = createFixture();
    const firstIdentifier = 'alice@example.com';
    const secondIdentifier = 'alice@example-com';

    const firstCode = await fixture.service.requestCode({
      identifier: firstIdentifier,
      purpose: 'register',
    });
    await fixture.service.register({
      identifier: firstIdentifier,
      code: firstCode.debugCode,
      password: 'Alice1234',
      nickname: 'Alice',
      deviceName: 'alice-phone',
    });

    const secondCode = await fixture.service.requestCode({
      identifier: secondIdentifier,
      purpose: 'register',
    });
    const secondRegistration = await fixture.service.register({
      identifier: secondIdentifier,
      code: secondCode.debugCode,
      password: 'Alice5678',
      nickname: 'Alice Clone',
      deviceName: 'clone-phone',
    });

    expect(secondRegistration.user.handle).toBe('alice_example_com_1');
  });

  it('should reject request-code attempts that exceed the limiter', async () => {
    const fixture = createFixture();
    (
      fixture.rateLimitService as unknown as {
        consumeOrThrow: jest.Mock;
      }
    ).consumeOrThrow.mockRejectedValueOnce(
      new Error('验证码请求过于频繁，请稍后再试'),
    );

    await expect(
      fixture.service.requestCode(
        {
          identifier: 'alice@example.com',
          purpose: 'register',
        },
        'source-1',
      ),
    ).rejects.toThrow('验证码请求过于频繁，请稍后再试');
  });

  it('should require a password reset before legacy code-only accounts can login', async () => {
    const fixture = createFixture();
    const code = await fixture.service.requestCode({
      identifier: 'alice@example.com',
      purpose: 'register',
    });
    const registration = await fixture.service.register({
      identifier: 'alice@example.com',
      code: code.debugCode,
      password: 'Alice1234',
      nickname: 'Alice',
      deviceName: 'alice-phone',
    });

    const user = await fixture.authRepository.findUserByIdentifier(
      registration.user.identifier,
    );

    if (!user) {
      throw new Error('expected registered user');
    }

    user.passwordHash = null;
    user.passwordUpdatedAt = null;
    await fixture.authRepository.saveUser(user);

    await expect(
      fixture.service.login({
        identifier: 'alice@example.com',
        password: 'Alice1234',
        deviceName: 'alice-ipad',
      }),
    ).rejects.toThrow('当前账号尚未设置密码，请先重置密码');
  });
});
