import type { RegisterPushTokenDto } from '../dto/register-push-token.dto';
import type { PushRegistrationEntity } from '../entities/push-registration.entity';
import { PushRegistrationRepository } from '../repositories/push-registration.repository';

import { NotificationsService } from './notifications.service';

import type { DeviceSessionEntity } from '@app/modules/auth/entities/device-session.entity';

class InMemoryPushRegistrationRepository extends PushRegistrationRepository {
  private readonly registrationsById = new Map<string, PushRegistrationEntity>();

  override async findRegistrationByProviderAndToken(params: {
    provider: PushRegistrationEntity['provider'];
    token: string;
  }): Promise<PushRegistrationEntity | null> {
    for (const registration of this.registrationsById.values()) {
      if (
        registration.provider === params.provider &&
        registration.token === params.token
      ) {
        return registration;
      }
    }

    return null;
  }

  override async createRegistration(params: {
    userId: string;
    sessionId: string;
    provider: PushRegistrationEntity['provider'];
    token: string;
    pushEnvironment: PushRegistrationEntity['pushEnvironment'];
  }): Promise<PushRegistrationEntity> {
    const now = new Date();
    const registration: PushRegistrationEntity = {
      id: `push-${this.registrationsById.size + 1}`,
      userId: params.userId,
      sessionId: params.sessionId,
      provider: params.provider,
      token: params.token,
      pushEnvironment: params.pushEnvironment,
      createdAt: now,
      updatedAt: now,
      lastRegisteredAt: now,
      revokedAt: null,
    };

    this.registrationsById.set(registration.id, registration);
    return registration;
  }

  override async saveRegistration(
    entity: PushRegistrationEntity,
  ): Promise<void> {
    entity.updatedAt = new Date();
    this.registrationsById.set(entity.id, entity);
  }

  override async revokeOtherSessionProviderRegistrations(params: {
    sessionId: string;
    provider: PushRegistrationEntity['provider'];
    excludedRegistrationId: string;
  }): Promise<void> {
    for (const registration of this.registrationsById.values()) {
      if (
        registration.sessionId === params.sessionId &&
        registration.provider === params.provider &&
        registration.id !== params.excludedRegistrationId &&
        registration.revokedAt == null
      ) {
        registration.revokedAt = new Date();
      }
    }
  }

  override async listActiveRegistrationsByUserId(
    userId: string,
  ): Promise<PushRegistrationEntity[]> {
    return Array.from(this.registrationsById.values()).filter((registration) => {
      return registration.userId === userId && registration.revokedAt == null;
    });
  }
}

describe('NotificationsService', () => {
  function createFixture() {
    const repository = new InMemoryPushRegistrationRepository();
    const service = new NotificationsService(repository);
    const session: DeviceSessionEntity = {
      id: 'session-1',
      userId: 'user-1',
      deviceName: 'iphone',
      refreshNonce: 'nonce',
      createdAt: new Date('2026-01-01T00:00:00.000Z'),
      lastSeenAt: new Date('2026-01-01T00:00:00.000Z'),
      revokedAt: null,
    };

    return {
      repository,
      service,
      session,
    };
  }

  it('should register a new push token for the current session', async () => {
    const fixture = createFixture();
    const dto: RegisterPushTokenDto = {
      provider: 'apns',
      token: 'apns_token_1234567890',
      pushEnvironment: 'sandbox',
    };

    const result = await fixture.service.registerPushToken({
      userId: 'user-1',
      session: fixture.session,
      dto,
    });

    expect(result).toMatchObject({
      provider: 'apns',
      pushEnvironment: 'sandbox',
      isCurrentSession: true,
    });
  });

  it('should reuse an existing provider token and move it to the current session', async () => {
    const fixture = createFixture();
    const existing = await fixture.repository.createRegistration({
      userId: 'user-old',
      sessionId: 'session-old',
      provider: 'apns',
      token: 'apns_token_reused',
      pushEnvironment: 'production',
    });

    const result = await fixture.service.registerPushToken({
      userId: 'user-1',
      session: fixture.session,
      dto: {
        provider: 'apns',
        token: existing.token,
        pushEnvironment: 'sandbox',
      },
    });

    expect(result.pushEnvironment).toBe('sandbox');
    const registrations = await fixture.repository.listActiveRegistrationsByUserId(
      'user-1',
    );
    expect(registrations[0]?.sessionId).toBe('session-1');
  });

  it('should revoke older registrations for the same session/provider', async () => {
    const fixture = createFixture();

    await fixture.service.registerPushToken({
      userId: 'user-1',
      session: fixture.session,
      dto: {
        provider: 'apns',
        token: 'apns_token_1',
        pushEnvironment: 'sandbox',
      },
    });
    await fixture.service.registerPushToken({
      userId: 'user-1',
      session: fixture.session,
      dto: {
        provider: 'apns',
        token: 'apns_token_2',
        pushEnvironment: 'sandbox',
      },
    });

    const registrations = await fixture.repository.listActiveRegistrationsByUserId(
      'user-1',
    );

    expect(registrations).toHaveLength(1);
    expect(registrations[0]?.token).toBe('apns_token_2');
  });
});
