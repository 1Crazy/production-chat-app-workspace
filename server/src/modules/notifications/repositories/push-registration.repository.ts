import type { PushRegistrationEntity } from '../entities/push-registration.entity';

export abstract class PushRegistrationRepository {
  abstract findRegistrationByProviderAndToken(params: {
    provider: PushRegistrationEntity['provider'];
    token: string;
  }): Promise<PushRegistrationEntity | null>;

  abstract createRegistration(params: {
    userId: string;
    sessionId: string;
    provider: PushRegistrationEntity['provider'];
    token: string;
    pushEnvironment: PushRegistrationEntity['pushEnvironment'];
  }): Promise<PushRegistrationEntity>;

  abstract saveRegistration(entity: PushRegistrationEntity): Promise<void>;

  abstract revokeOtherSessionProviderRegistrations(params: {
    sessionId: string;
    provider: PushRegistrationEntity['provider'];
    excludedRegistrationId: string;
  }): Promise<void>;

  abstract listActiveRegistrationsByUserId(
    userId: string,
  ): Promise<PushRegistrationEntity[]>;
}
