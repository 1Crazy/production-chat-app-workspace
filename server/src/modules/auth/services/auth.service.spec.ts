import { InMemoryAuthRepository } from '../repositories/in-memory-auth.repository';

import { AuthCodeDeliveryService } from './auth-code-delivery.service';
import { AuthPasswordService } from './auth-password.service';
import { AuthRateLimitService } from './auth-rate-limit.service';
import { AuthSessionService } from './auth-session.service';
import { AuthTokenService } from './auth-token.service';
import { AuthVerificationCodeService } from './auth-verification-code.service';
import { AuthService } from './auth.service';

import type { RateLimitService } from '@app/infra/abuse/services/rate-limit.service';
import type { AppConfigService } from '@app/infra/config/app-config.service';
import type { ChatGateway } from '@app/modules/realtime/gateways/chat.gateway';

describe('AuthService', () => {
  type TestAppConfig = Pick<
    AppConfigService,
    | 'jwtAccessSecret'
    | 'jwtRefreshSecret'
    | 'nodeEnv'
    | 'authDebugCodeEnabled'
    | 'authCodeDeliveryMode'
    | 'authCodeWebhookUrl'
    | 'authCodeWebhookSecret'
    | 'authCodeEmailFrom'
    | 'authCodeEmailNickname'
    | 'authCodeEmailHandle'
    | 'authRateLimitEnabled'
    | 'authRateLimitWindowMinutes'
    | 'authRequestCodeSourceLimit'
    | 'authRequestCodeIdentifierLimit'
    | 'authRegisterSourceLimit'
    | 'authRegisterIdentifierLimit'
    | 'authLoginSourceLimit'
    | 'authLoginIdentifierLimit'
    | 'authResetPasswordSourceLimit'
    | 'authResetPasswordIdentifierLimit'
  >;

  function buildAppConfig(
    overrides: Partial<TestAppConfig> = {},
  ): AppConfigService {
    return {
      jwtAccessSecret: 'access-secret',
      jwtRefreshSecret: 'refresh-secret',
      nodeEnv: 'test',
      authDebugCodeEnabled: true,
      authCodeDeliveryMode: 'debug',
      authCodeWebhookUrl: undefined,
      authCodeWebhookSecret: undefined,
      authCodeEmailFrom: undefined,
      authCodeEmailNickname: undefined,
      authCodeEmailHandle: undefined,
      authRateLimitEnabled: true,
      authRateLimitWindowMinutes: 10,
      authRequestCodeSourceLimit: 6,
      authRequestCodeIdentifierLimit: 3,
      authRegisterSourceLimit: 5,
      authRegisterIdentifierLimit: 3,
      authLoginSourceLimit: 10,
      authLoginIdentifierLimit: 5,
      authResetPasswordSourceLimit: 5,
      authResetPasswordIdentifierLimit: 3,
      ...overrides,
    } as AppConfigService;
  }

  function requireDebugCode(response: { debugCode?: string }): string {
    if (!response.debugCode) {
      throw new Error('expected test fixture to expose debugCode');
    }

    return response.debugCode;
  }

  function createFixture(configOverrides: Partial<TestAppConfig> = {}) {
    const authRepository = new InMemoryAuthRepository();
    const appConfig = buildAppConfig(configOverrides);
    const authTokenService = new AuthTokenService(appConfig);
    const chatGateway = {
      disconnectSession: jest.fn(),
    } as unknown as ChatGateway;
    const rateLimitService = {
      consumeOrThrow: jest.fn().mockResolvedValue(undefined),
      reset: jest.fn().mockResolvedValue(undefined),
    } as unknown as RateLimitService;
    const authPasswordService = new AuthPasswordService();
    const authSessionService = new AuthSessionService(
      authRepository,
      authTokenService,
      chatGateway,
    );
    const authVerificationCodeService = new AuthVerificationCodeService(
      authRepository,
      rateLimitService,
    );
    const authRateLimitService = new AuthRateLimitService(
      appConfig,
      rateLimitService,
    );
    const authCodeDeliveryService = new AuthCodeDeliveryService(appConfig);
    const service = new AuthService(
      authRepository,
      authPasswordService,
      authSessionService,
      authVerificationCodeService,
      authRateLimitService,
      authCodeDeliveryService,
      appConfig,
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
      code: requireDebugCode(firstCode),
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
      code: requireDebugCode(secondCode),
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

  it('should skip auth rate limiting when disabled by env config', async () => {
    const fixture = createFixture({
      authRateLimitEnabled: false,
    });

    await fixture.service.requestCode({
      identifier: 'alice@example.com',
      purpose: 'register',
    });

    expect(
      (fixture.rateLimitService as unknown as { consumeOrThrow: jest.Mock })
        .consumeOrThrow,
    ).not.toHaveBeenCalled();
  });

  it('should not expose debug codes in production responses', async () => {
    const fixture = createFixture({
      nodeEnv: 'production',
      authDebugCodeEnabled: true,
      authCodeDeliveryMode: 'debug',
      authRateLimitEnabled: false,
    });

    await expect(
      fixture.service.requestCode({
        identifier: 'alice@example.com',
        purpose: 'register',
      }),
    ).resolves.not.toHaveProperty('debugCode');
  });

  it('should store newly issued verification codes as hashes', async () => {
    const fixture = createFixture({
      authRateLimitEnabled: false,
    });

    const response = await fixture.service.requestCode({
      identifier: 'alice@example.com',
      purpose: 'register',
    });
    const storedCode = await fixture.authRepository.findVerificationCode(
      'alice@example.com',
      'register',
    );

    expect(storedCode).not.toBeNull();
    expect(storedCode?.code).toBeDefined();
    expect(storedCode?.code).not.toBe(requireDebugCode(response));
    expect(storedCode?.code.startsWith('$argon2')).toBe(true);
  });

  it('should reject plaintext verification codes stored in legacy format', async () => {
    const fixture = createFixture({
      authRateLimitEnabled: false,
    });

    await fixture.authRepository.createVerificationCode(
      'alice@example.com',
      'register',
      '123456',
      new Date(Date.now() + 10 * 60 * 1000),
    );

    await expect(
      fixture.service.register({
        identifier: 'alice@example.com',
        code: '123456',
        password: 'Alice1234',
        nickname: 'Alice',
        deviceName: 'alice-phone',
      }),
    ).rejects.toThrow('注册验证码不正确');
  });

  it('should deliver production codes through the configured webhook', async () => {
    const fetchMock = jest
      .spyOn(globalThis, 'fetch')
      .mockResolvedValue({ ok: true } as Response);
    const fixture = createFixture({
      nodeEnv: 'production',
      authDebugCodeEnabled: false,
      authCodeDeliveryMode: 'webhook',
      authCodeWebhookUrl: 'https://code-provider.example/send',
      authCodeWebhookSecret: 'delivery-secret',
      authCodeEmailFrom: 'no-reply@example.com',
      authCodeEmailNickname: 'Production Chat',
      authCodeEmailHandle: 'production_chat',
      authRateLimitEnabled: false,
    });

    await fixture.service.requestCode({
      identifier: 'Alice@Example.com',
      purpose: 'reset-password',
    });

    expect(fetchMock).toHaveBeenCalledWith(
      'https://code-provider.example/send',
      expect.objectContaining({
        method: 'POST',
        headers: {
          'content-type': 'application/json',
          authorization: 'Bearer delivery-secret',
        },
      }),
    );
    const [, request] = fetchMock.mock.calls[0]!;
    const body = JSON.parse(String((request as RequestInit).body));
    expect(body).toMatchObject({
      identifier: 'alice@example.com',
      purpose: 'reset-password',
      expiresInSeconds: 600,
      sender: {
        email: 'no-reply@example.com',
        nickname: 'Production Chat',
        handle: 'production_chat',
      },
    });
    expect(body.code).toMatch(/^\d{6}$/);

    fetchMock.mockRestore();
  });

  it('should require a password reset before legacy code-only accounts can login', async () => {
    const fixture = createFixture();
    const code = await fixture.service.requestCode({
      identifier: 'alice@example.com',
      purpose: 'register',
    });
    const registration = await fixture.service.register({
      identifier: 'alice@example.com',
      code: requireDebugCode(code),
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
    ).rejects.toThrow('账号或密码不匹配');
  });

  it('should scope verification retries to the source and identifier pair', async () => {
    const fixture = createFixture({
      authRateLimitEnabled: false,
    });

    const requestCode = await fixture.service.requestCode(
      {
        identifier: 'alice@example.com',
        purpose: 'register',
      },
      'source-a',
    );

    await expect(
      fixture.service.register(
        {
          identifier: 'alice@example.com',
          code: '000000',
          password: 'Alice1234',
          nickname: 'Alice',
          deviceName: 'alice-phone',
        },
        'source-b',
      ),
    ).rejects.toThrow('注册验证码不正确');

    const rateLimit = fixture.rateLimitService as unknown as {
      consumeOrThrow: jest.Mock;
      reset: jest.Mock;
    };

    expect(rateLimit.reset).toHaveBeenCalledWith({
      scope: 'auth.assert-code.register',
      actorKey: 'source-a::alice@example.com',
    });
    expect(rateLimit.consumeOrThrow).toHaveBeenCalledWith(
      expect.objectContaining({
        scope: 'auth.assert-code.register',
        actorKey: 'source-b::alice@example.com',
      }),
    );
    expect(requestCode.debugCode).toMatch(/^\d{6}$/);
  });

  it('should mask reset-password verification failures behind one message', async () => {
    const fixture = createFixture({
      authRateLimitEnabled: false,
    });
    const code = await fixture.service.requestCode(
      {
        identifier: 'alice@example.com',
        purpose: 'register',
      },
      'source-1',
    );
    await fixture.service.register(
      {
        identifier: 'alice@example.com',
        code: requireDebugCode(code),
        password: 'Alice1234',
        nickname: 'Alice',
        deviceName: 'alice-phone',
      },
      'source-1',
    );

    await expect(
      fixture.service.resetPassword(
        {
          identifier: 'alice@example.com',
          code: '000000',
          password: 'Alice5678',
        },
        'source-1',
      ),
    ).rejects.toThrow('账号验证失败');

    await expect(
      fixture.service.resetPassword(
        {
          identifier: 'ghost@example.com',
          code: '123456',
          password: 'Ghost1234',
        },
        'source-1',
      ),
    ).rejects.toThrow('账号验证失败');
  });
});
