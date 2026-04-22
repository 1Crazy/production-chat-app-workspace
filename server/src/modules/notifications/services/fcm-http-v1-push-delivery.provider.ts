import { createSign } from 'crypto';

import { Injectable, Logger } from '@nestjs/common';

import {
  type PushDeliveryRequest,
  PushDeliveryProvider,
} from './push-delivery.provider';

import { AppConfigService } from '@app/infra/config/app-config.service';

interface FcmOAuthTokenResponse {
  access_token: string;
  expires_in: number;
  token_type: string;
}

@Injectable()
export class FcmHttpV1PushDeliveryProvider extends PushDeliveryProvider {
  private readonly logger = new Logger(FcmHttpV1PushDeliveryProvider.name);
  private accessTokenCache:
    | {
        token: string;
        expiresAt: number;
      }
    | null = null;

  constructor(private readonly appConfigService: AppConfigService) {
    super();
  }

  isConfigured(): boolean {
    return (
      this.appConfigService.fcmProjectId != null &&
      this.appConfigService.fcmClientEmail != null &&
      this.appConfigService.fcmPrivateKey != null
    );
  }

  override async send(request: PushDeliveryRequest): Promise<void> {
    if (request.registration.provider !== 'fcm') {
      return;
    }

    if (!this.isConfigured()) {
      this.logger.warn('Skipping FCM delivery because credentials are missing');
      return;
    }

    const accessToken = await this.getAccessToken();
    const projectId = this.appConfigService.fcmProjectId!;
    const response = await this.postJson<{
      name: string;
    }>(
      `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
      {
        message: {
          token: request.registration.token,
          notification: {
            title: request.title,
            body: request.body,
          },
          data: request.data,
          android: {
            priority: 'high',
          },
          apns: {
            headers: {
              'apns-priority': '10',
              'apns-push-type': 'alert',
            },
            payload: {
              aps: {
                badge: request.badgeCount,
                sound: 'default',
              },
            },
          },
        },
      },
      {
        Authorization: `Bearer ${accessToken}`,
      },
    );

    this.logger.log(
      `Delivered FCM push ${response.name} to registration ${request.registration.id}`,
    );
  }

  protected async postForm<TResponse>(
    url: string,
    body: URLSearchParams,
  ): Promise<TResponse> {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body,
    });

    if (!response.ok) {
      const responseText = await response.text();
      throw new Error(
        `FCM auth request failed (${response.status}): ${responseText}`,
      );
    }

    return (await response.json()) as TResponse;
  }

  protected async postJson<TResponse>(
    url: string,
    body: Record<string, unknown>,
    headers: Record<string, string>,
  ): Promise<TResponse> {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...headers,
      },
      body: JSON.stringify(body),
    });

    if (!response.ok) {
      const responseText = await response.text();
      throw new Error(
        `FCM send request failed (${response.status}): ${responseText}`,
      );
    }

    return (await response.json()) as TResponse;
  }

  private async getAccessToken(): Promise<string> {
    const cachedToken = this.accessTokenCache;

    if (cachedToken != null && cachedToken.expiresAt > Date.now()) {
      return cachedToken.token;
    }

    const issuedAtSeconds = Math.floor(Date.now() / 1000);
    const expiresAtSeconds = issuedAtSeconds + 3600;
    const assertion = this.createServiceAccountAssertion({
      clientEmail: this.appConfigService.fcmClientEmail!,
      privateKey: this.normalizePrivateKey(this.appConfigService.fcmPrivateKey!),
      issuedAtSeconds,
      expiresAtSeconds,
    });
    const tokenResponse = await this.postForm<FcmOAuthTokenResponse>(
      'https://oauth2.googleapis.com/token',
      new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion,
      }),
    );

    this.accessTokenCache = {
      token: tokenResponse.access_token,
      expiresAt:
        Date.now() + Math.max(tokenResponse.expires_in - 60, 0) * 1000,
    };

    return tokenResponse.access_token;
  }

  protected createServiceAccountAssertion(params: {
    clientEmail: string;
    privateKey: string;
    issuedAtSeconds: number;
    expiresAtSeconds: number;
  }): string {
    const encodedHeader = this.encodeBase64Url(
      JSON.stringify({
        alg: 'RS256',
        typ: 'JWT',
      }),
    );
    const encodedPayload = this.encodeBase64Url(
      JSON.stringify({
        iss: params.clientEmail,
        scope: 'https://www.googleapis.com/auth/firebase.messaging',
        aud: 'https://oauth2.googleapis.com/token',
        iat: params.issuedAtSeconds,
        exp: params.expiresAtSeconds,
      }),
    );
    const signingInput = `${encodedHeader}.${encodedPayload}`;
    const signer = createSign('RSA-SHA256');

    signer.update(signingInput);
    signer.end();

    const signature = signer.sign(params.privateKey);
    return `${signingInput}.${this.encodeBase64Url(signature)}`;
  }

  private encodeBase64Url(input: string | Buffer): string {
    return Buffer.from(input)
      .toString('base64')
      .replace(/\+/g, '-')
      .replace(/\//g, '_')
      .replace(/=+$/g, '');
  }

  private normalizePrivateKey(privateKey: string): string {
    return privateKey.replace(/\\n/g, '\n');
  }
}
