import { InMemoryAuthRepository } from '../repositories/in-memory-auth.repository';

import { AuthTokenService } from './auth-token.service';
import { AuthService } from './auth.service';

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
    const service = new AuthService(
      authRepository,
      authTokenService,
      chatGateway,
    );

    return {
      authRepository,
      service,
    };
  }

  it('should allocate a unique handle when normalized identifiers collide', async () => {
    const fixture = createFixture();
    const firstIdentifier = 'alice@example.com';
    const secondIdentifier = 'alice@example-com';

    const firstCode = await fixture.service.requestCode({
      identifier: firstIdentifier,
    });
    await fixture.service.register({
      identifier: firstIdentifier,
      code: firstCode.debugCode,
      nickname: 'Alice',
      deviceName: 'alice-phone',
    });

    const secondCode = await fixture.service.requestCode({
      identifier: secondIdentifier,
    });
    const secondRegistration = await fixture.service.register({
      identifier: secondIdentifier,
      code: secondCode.debugCode,
      nickname: 'Alice Clone',
      deviceName: 'clone-phone',
    });

    expect(secondRegistration.user.handle).toBe('alice_example_com_1');
  });
});
