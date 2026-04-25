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

    try {
      const response = await fetch(webhookUrl, {
        method: 'POST',
        headers: this.buildWebhookHeaders(),
      body: JSON.stringify({
        identifier: params.identifier,
        purpose: params.purpose,
        code: params.code,
        expiresInSeconds: params.expiresInSeconds,
        sender: {
          email: this.appConfigService.authCodeEmailFrom,
          nickname: this.appConfigService.authCodeEmailNickname,
          handle: this.appConfigService.authCodeEmailHandle,
        },
      }),
    });

      if (response.ok) {
        return;
      }
    } catch {
      throw new ServiceUnavailableException('验证码投递失败，请稍后再试');
    }

    throw new ServiceUnavailableException('验证码投递失败，请稍后再试');
  }

  private buildWebhookHeaders(): Record<string, string> {
    const headers: Record<string, string> = {
      'content-type': 'application/json',
    };
    const secret = this.appConfigService.authCodeWebhookSecret;

    if (secret) {
      headers.authorization = `Bearer ${secret}`;
    }

    return headers;
  }
}
