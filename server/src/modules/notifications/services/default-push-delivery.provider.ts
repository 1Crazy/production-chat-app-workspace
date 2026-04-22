import { Injectable } from '@nestjs/common';

import { ApnsPushDeliveryProvider } from './apns-push-delivery.provider';
import { FcmHttpV1PushDeliveryProvider } from './fcm-http-v1-push-delivery.provider';
import {
  LoggingPushDeliveryProvider,
  type PushDeliveryRequest,
  PushDeliveryProvider,
} from './push-delivery.provider';

@Injectable()
export class DefaultPushDeliveryProvider extends PushDeliveryProvider {
  constructor(
    private readonly apnsPushDeliveryProvider: ApnsPushDeliveryProvider,
    private readonly fcmPushDeliveryProvider: FcmHttpV1PushDeliveryProvider,
    private readonly loggingPushDeliveryProvider: LoggingPushDeliveryProvider,
  ) {
    super();
  }

  override async send(request: PushDeliveryRequest): Promise<void> {
    if (
      request.registration.provider === 'apns' &&
      this.apnsPushDeliveryProvider.isConfigured()
    ) {
      await this.apnsPushDeliveryProvider.send(request);
      return;
    }

    if (
      request.registration.provider === 'fcm' &&
      this.fcmPushDeliveryProvider.isConfigured()
    ) {
      await this.fcmPushDeliveryProvider.send(request);
      return;
    }

    await this.loggingPushDeliveryProvider.send(request);
  }
}
