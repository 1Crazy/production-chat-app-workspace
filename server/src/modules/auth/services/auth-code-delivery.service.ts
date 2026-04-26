import { createHmac } from 'node:crypto';

import { Injectable, ServiceUnavailableException } from '@nestjs/common';

import type { VerificationCodePurpose } from '../entities/verification-code.entity';

import { AppConfigService } from '@app/infra/config/app-config.service';

@Injectable()
export class AuthCodeDeliveryService {
  constructor(private readonly appConfigService: AppConfigService) {}

  async deliverVerificationCode(params: {
    identifier: string;
    purpose: VerificationCodePurpose;
    code: string;
    expiresInSeconds: number;
  }): Promise<void> {
    if (this.appConfigService.authCodeDeliveryMode === 'debug') {
      return;
    }

    await this.deliverViaWebhook(params);
  }

  shouldExposeDebugCode(): boolean {
    return (
      this.appConfigService.authDebugCodeEnabled &&
      this.appConfigService.nodeEnv !== 'production'
    );
  }

  private async deliverViaWebhook(params: {
    identifier: string;
    purpose: VerificationCodePurpose;
    code: string;
    expiresInSeconds: number;
  }): Promise<void> {
    const webhookUrl = this.appConfigService.authCodeWebhookUrl;

    if (!webhookUrl) {
      throw new ServiceUnavailableException('验证码投递通道未配置');
    }

    const body = JSON.stringify({
      identifier: params.identifier,
      purpose: params.purpose,
      code: params.code,
      expiresInSeconds: params.expiresInSeconds,
      sender: {
        email: this.appConfigService.authCodeEmailFrom,
        nickname: this.appConfigService.authCodeEmailNickname,
        handle: this.appConfigService.authCodeEmailHandle,
      },
    });

    try {
      const response = await fetch(webhookUrl, {
        method: 'POST',
        headers: this.buildWebhookHeaders(body),
        // 外部 webhook 必须在 10 秒内响应，防止阻塞验证码投递链路。
        signal: AbortSignal.timeout(10_000),
        body,
      });

      if (response.ok) {
        return;
      }
    } catch {
      throw new ServiceUnavailableException('验证码投递失败，请稍后再试');
    }

    throw new ServiceUnavailableException('验证码投递失败，请稍后再试');
  }

  private buildWebhookHeaders(body: string): Record<string, string> {
    const headers: Record<string, string> = {
      'content-type': 'application/json',
    };
    const secret = this.appConfigService.authCodeWebhookSecret;

    if (secret) {
      const timestamp = String(Date.now());
      headers.authorization = `Bearer ${secret}`;
      headers['x-chatapp-timestamp'] = timestamp;
      headers['x-chatapp-signature'] = `sha256=${createHmac(
        'sha256',
        secret,
      )
        .update(`${timestamp}.${body}`)
        .digest('hex')}`;
    }

    return headers;
  }
}
