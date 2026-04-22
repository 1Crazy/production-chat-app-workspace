import { FcmHttpV1PushDeliveryProvider } from './fcm-http-v1-push-delivery.provider';

import type { AppConfigService } from '@app/infra/config/app-config.service';

class TestableFcmHttpV1PushDeliveryProvider extends FcmHttpV1PushDeliveryProvider {
  readonly formRequests: Array<{
    url: string;
    body: URLSearchParams;
  }> = [];
  readonly jsonRequests: Array<{
    url: string;
    body: Record<string, unknown>;
    headers: Record<string, string>;
  }> = [];

  override async postForm<TResponse>(
    url: string,
    body: URLSearchParams,
  ): Promise<TResponse> {
    this.formRequests.push({ url, body });

    return {
      access_token: 'oauth-token-1',
      expires_in: 3600,
      token_type: 'Bearer',
    } as TResponse;
  }

  override async postJson<TResponse>(
    url: string,
    body: Record<string, unknown>,
    headers: Record<string, string>,
  ): Promise<TResponse> {
    this.jsonRequests.push({ url, body, headers });
    return {
      name: 'projects/test/messages/msg-1',
    } as TResponse;
  }

  override createServiceAccountAssertion(): string {
    return 'test.header.signature';
  }
}

describe('FcmHttpV1PushDeliveryProvider', () => {
  function createFixture() {
    const configService = {
      get fcmProjectId() {
        return 'demo-fcm-project';
      },
      get fcmClientEmail() {
        return 'firebase-adminsdk@example.iam.gserviceaccount.com';
      },
      get fcmPrivateKey() {
        return [
          '-----BEGIN PRIVATE KEY-----',
          'MIIBVgIBADANBgkqhkiG9w0BAQEFAASCAT8wggE7AgEAAkEA1cM6u2c=',
          '-----END PRIVATE KEY-----',
        ].join('\\n');
      },
    } as unknown as AppConfigService;
    const provider = new TestableFcmHttpV1PushDeliveryProvider(configService);

    return {
      provider,
    };
  }

  it('should exchange a service account assertion and send the FCM v1 request', async () => {
    const fixture = createFixture();

    await fixture.provider.send({
      registration: {
        id: 'push-1',
        userId: 'user-1',
        sessionId: 'session-1',
        provider: 'fcm',
        token: 'fcm_device_token',
        pushEnvironment: 'production',
        privacyModeEnabled: false,
        createdAt: new Date(),
        updatedAt: new Date(),
        lastRegisteredAt: new Date(),
        revokedAt: null,
      },
      title: 'Alice',
      body: '你好',
      badgeCount: 3,
      data: {
        conversationId: 'conversation-1',
        badgeCount: '3',
      },
    });

    expect(fixture.provider.formRequests).toHaveLength(1);
    expect(fixture.provider.formRequests[0]?.url).toBe(
      'https://oauth2.googleapis.com/token',
    );
    expect(
      fixture.provider.formRequests[0]?.body.get('grant_type'),
    ).toBe('urn:ietf:params:oauth:grant-type:jwt-bearer');
    expect(
      fixture.provider.formRequests[0]?.body.get('assertion'),
    ).toContain('.');
    expect(fixture.provider.jsonRequests).toHaveLength(1);
    expect(fixture.provider.jsonRequests[0]?.url).toBe(
      'https://fcm.googleapis.com/v1/projects/demo-fcm-project/messages:send',
    );
    expect(fixture.provider.jsonRequests[0]?.headers.Authorization).toBe(
      'Bearer oauth-token-1',
    );
    expect(fixture.provider.jsonRequests[0]?.body).toMatchObject({
      message: {
        token: 'fcm_device_token',
        notification: {
          title: 'Alice',
          body: '你好',
        },
        data: {
          conversationId: 'conversation-1',
          badgeCount: '3',
        },
        apns: {
          payload: {
            aps: {
              badge: 3,
            },
          },
        },
      },
    });
  });

  it('should reuse a cached OAuth token across repeated sends', async () => {
    const fixture = createFixture();
    const request = {
      registration: {
        id: 'push-2',
        userId: 'user-2',
        sessionId: 'session-2',
        provider: 'fcm' as const,
        token: 'fcm_device_token_2',
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

    expect(fixture.provider.formRequests).toHaveLength(1);
    expect(fixture.provider.jsonRequests).toHaveLength(2);
  });
});
