import { ApnsPushDeliveryProvider } from './apns-push-delivery.provider';

import type { AppConfigService } from '@app/infra/config/app-config.service';

class TestableApnsPushDeliveryProvider extends ApnsPushDeliveryProvider {
  readonly requests: Array<{
    origin: string;
    deviceToken: string;
    headers: Record<string, unknown>;
    body: string;
  }> = [];
  providerTokenCallCount = 0;

  override createProviderToken(): string {
    this.providerTokenCallCount += 1;
    return 'test.apns.provider-token';
  }

  override async sendApnsRequest(params: {
    origin: string;
    deviceToken: string;
    headers: Record<string, unknown>;
    body: string;
  }): Promise<{ statusCode: number; body: string }> {
    this.requests.push(params);
    return {
      statusCode: 200,
      body: '',
    };
  }
}

describe('ApnsPushDeliveryProvider', () => {
  function createFixture() {
    const configService = {
      get apnsTeamId() {
        return 'TEAM123456';
      },
      get apnsKeyId() {
        return 'KEY1234567';
      },
      get apnsBundleId() {
        return 'com.example.productionchatapp';
      },
      get apnsPrivateKey() {
        return '-----BEGIN PRIVATE KEY-----\\nTEST\\n-----END PRIVATE KEY-----';
      },
    } as unknown as AppConfigService;
    const provider = new TestableApnsPushDeliveryProvider(configService);

    return {
      provider,
    };
  }

  it('should send APNs requests to the sandbox host with provider token auth', async () => {
    const fixture = createFixture();

    await fixture.provider.send({
      registration: {
        id: 'push-1',
        userId: 'user-1',
        sessionId: 'session-1',
        provider: 'apns',
        token: 'apns-device-token',
        pushEnvironment: 'sandbox',
        privacyModeEnabled: false,
        createdAt: new Date(),
        updatedAt: new Date(),
        lastRegisteredAt: new Date(),
        revokedAt: null,
      },
      title: 'Alice',
      body: '你好',
      badgeCount: 5,
      data: {
        conversationId: 'conversation-1',
        badgeCount: '5',
      },
    });

    expect(fixture.provider.requests).toHaveLength(1);
    expect(fixture.provider.requests[0]).toMatchObject({
      origin: 'https://api.sandbox.push.apple.com',
      deviceToken: 'apns-device-token',
      headers: {
        ':method': 'POST',
        ':path': '/3/device/apns-device-token',
        authorization: 'bearer test.apns.provider-token',
        'apns-topic': 'com.example.productionchatapp',
      },
    });
    expect(JSON.parse(fixture.provider.requests[0]!.body)).toMatchObject({
      aps: {
        alert: {
          title: 'Alice',
          body: '你好',
        },
        badge: 5,
      },
      conversationId: 'conversation-1',
      badgeCount: '5',
    });
  });

  it('should reuse cached provider tokens across repeated sends', async () => {
    const fixture = createFixture();
    const request = {
      registration: {
        id: 'push-2',
        userId: 'user-2',
        sessionId: 'session-2',
        provider: 'apns' as const,
        token: 'apns-device-token-2',
        pushEnvironment: 'production' as const,
        privacyModeEnabled: false,
        createdAt: new Date(),
        updatedAt: new Date(),
        lastRegisteredAt: new Date(),
        revokedAt: null,
      },
      title: 'Bob',
      body: '消息',
      badgeCount: 1,
      data: {
        conversationId: 'conversation-2',
      },
    };

    await fixture.provider.send(request);
    await fixture.provider.send(request);

    expect(fixture.provider.providerTokenCallCount).toBe(1);
    expect(fixture.provider.requests).toHaveLength(2);
    expect(fixture.provider.requests[1]?.origin).toBe(
      'https://api.push.apple.com',
    );
  });
});
