import { Injectable, Logger } from '@nestjs/common';

import type { PushRegistrationEntity } from '../entities/push-registration.entity';

export interface PushDeliveryRequest {
  registration: PushRegistrationEntity;
  title: string;
  body: string;
  badgeCount: number;
  data: Record<string, string>;
}

export abstract class PushDeliveryProvider {
  abstract send(request: PushDeliveryRequest): Promise<void>;
}

@Injectable()
export class LoggingPushDeliveryProvider extends PushDeliveryProvider {
  private readonly logger = new Logger(LoggingPushDeliveryProvider.name);

  override async send(request: PushDeliveryRequest): Promise<void> {
    // 当前仓库阶段先把 APNs/FCM 分发抽象稳定下来，默认实现走结构化日志，
    // 便于本地验证、测试替身注入，以及后续接入真实 provider 时不改业务链路。
    this.logger.log(
      JSON.stringify({
        provider: request.registration.provider,
        pushEnvironment: request.registration.pushEnvironment,
        tokenSuffix: request.registration.token.slice(-12),
        privacyModeEnabled: request.registration.privacyModeEnabled,
        badgeCount: request.badgeCount,
        title: request.title,
        body: request.body,
        data: request.data,
      }),
    );
  }
}
