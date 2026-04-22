import { createSign } from 'crypto';
import {
  connect,
  constants,
  type ClientHttp2Session,
  type IncomingHttpHeaders,
} from 'http2';

import { Injectable, Logger } from '@nestjs/common';

import {
  type PushDeliveryRequest,
  PushDeliveryProvider,
} from './push-delivery.provider';

import { AppConfigService } from '@app/infra/config/app-config.service';

interface ApnsResponse {
  statusCode: number;
  body: string;
}

@Injectable()
export class ApnsPushDeliveryProvider extends PushDeliveryProvider {
  private readonly logger = new Logger(ApnsPushDeliveryProvider.name);
  private providerTokenCache:
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
      this.appConfigService.apnsTeamId != null &&
      this.appConfigService.apnsKeyId != null &&
      this.appConfigService.apnsBundleId != null &&
      this.appConfigService.apnsPrivateKey != null
    );
  }

  override async send(request: PushDeliveryRequest): Promise<void> {
    if (request.registration.provider !== 'apns') {
      return;
    }

    if (!this.isConfigured()) {
      this.logger.warn('Skipping APNs delivery because credentials are missing');
      return;
    }

    const providerToken = this.getProviderToken();
    const response = await this.sendApnsRequest({
      origin: this.resolveOrigin(request.registration.pushEnvironment),
      deviceToken: request.registration.token,
      headers: {
        ':method': 'POST',
        ':path': `/3/device/${request.registration.token}`,
        authorization: `bearer ${providerToken}`,
        'apns-priority': '10',
        'apns-push-type': 'alert',
        'apns-topic': this.appConfigService.apnsBundleId!,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        aps: {
          alert: {
            title: request.title,
            body: request.body,
          },
          badge: request.badgeCount,
          sound: 'default',
        },
        ...request.data,
      }),
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(
        `APNs send request failed (${response.statusCode}): ${response.body}`,
      );
    }

    this.logger.log(
      `Delivered APNs push to registration ${request.registration.id}`,
    );
  }

  protected async sendApnsRequest(params: {
    origin: string;
    deviceToken: string;
    headers: IncomingHttpHeaders;
    body: string;
  }): Promise<ApnsResponse> {
    const session = connect(params.origin);

    try {
      return await new Promise<ApnsResponse>((resolve, reject) => {
        const request = session.request(params.headers);
        const bodyChunks: Buffer[] = [];
        let statusCode = constants.HTTP_STATUS_INTERNAL_SERVER_ERROR;

        request.setEncoding('utf8');
        request.on('response', (headers) => {
          const statusHeader = headers[':status'];

          if (typeof statusHeader === 'number') {
            statusCode = statusHeader;
          }
        });
        request.on('data', (chunk: string) => {
          bodyChunks.push(Buffer.from(chunk));
        });
        request.on('end', () => {
          resolve({
            statusCode,
            body: Buffer.concat(bodyChunks).toString('utf8'),
          });
        });
        request.on('error', reject);
        session.on('error', reject);
        request.end(params.body);
      });
    } finally {
      this.closeSession(session);
    }
  }

  protected createProviderToken(issuedAtSeconds: number): string {
    const encodedHeader = this.encodeBase64Url(
      JSON.stringify({
        alg: 'ES256',
        kid: this.appConfigService.apnsKeyId!,
      }),
    );
    const encodedPayload = this.encodeBase64Url(
      JSON.stringify({
        iss: this.appConfigService.apnsTeamId!,
        iat: issuedAtSeconds,
      }),
    );
    const signingInput = `${encodedHeader}.${encodedPayload}`;
    const signer = createSign('SHA256');

    signer.update(signingInput);
    signer.end();

    const signature = signer.sign({
      key: this.normalizePrivateKey(this.appConfigService.apnsPrivateKey!),
      dsaEncoding: 'ieee-p1363',
    });

    return `${signingInput}.${this.encodeBase64Url(signature)}`;
  }

  private getProviderToken(): string {
    const cachedToken = this.providerTokenCache;

    if (cachedToken != null && cachedToken.expiresAt > Date.now()) {
      return cachedToken.token;
    }

    const issuedAtSeconds = Math.floor(Date.now() / 1000);
    const token = this.createProviderToken(issuedAtSeconds);

    this.providerTokenCache = {
      token,
      expiresAt: Date.now() + 50 * 60 * 1000,
    };

    return token;
  }

  private resolveOrigin(pushEnvironment: 'sandbox' | 'production'): string {
    return pushEnvironment === 'sandbox'
      ? 'https://api.sandbox.push.apple.com'
      : 'https://api.push.apple.com';
  }

  private closeSession(session: ClientHttp2Session): void {
    if (!session.closed && !session.destroyed) {
      session.close();
    }
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
