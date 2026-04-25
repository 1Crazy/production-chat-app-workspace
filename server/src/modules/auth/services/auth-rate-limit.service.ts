import { Injectable } from '@nestjs/common';

import { RateLimitService } from '@app/infra/abuse/services/rate-limit.service';
import { AppConfigService } from '@app/infra/config/app-config.service';

@Injectable()
export class AuthRateLimitService {
  constructor(
    private readonly appConfigService: AppConfigService,
    private readonly rateLimitService: RateLimitService,
  ) {}

  async assertAuthRateLimit(params: {
    scope: string;
    sourceKey: string;
    identifier: string;
    sourceLimit: number;
    identifierLimit: number;
    message: string;
  }): Promise<void> {
    if (!this.appConfigService.authRateLimitEnabled) {
      return;
    }

    const windowMs =
      this.appConfigService.authRateLimitWindowMinutes * 60 * 1000;

    await this.rateLimitService.consumeOrThrow({
      scope: `${params.scope}.source`,
      actorKey: params.sourceKey,
      limit: params.sourceLimit,
      windowMs,
      message: params.message,
      metadata: {
        identifier: params.identifier,
      },
    });
    await this.rateLimitService.consumeOrThrow({
      scope: `${params.scope}.identifier`,
      actorKey: params.identifier,
      limit: params.identifierLimit,
      windowMs,
      message: params.message,
      metadata: {
        sourceKey: params.sourceKey,
      },
    });
  }
}
