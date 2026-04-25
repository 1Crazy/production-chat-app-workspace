import type { RegisterPushTokenDto } from '../dto/register-push-token.dto';
import type { PushRegistrationEntity } from '../entities/push-registration.entity';
import { PushRegistrationRepository } from '../repositories/push-registration.repository';

import { NotificationPushDispatcherService } from './notification-push-dispatcher.service';
import { NotificationSyncStateService } from './notification-sync-state.service';
import { NotificationsService } from './notifications.service';
import {
  type PushDeliveryRequest,
  PushDeliveryProvider,
} from './push-delivery.provider';

import { InMemoryChatModelRepository } from '@app/infra/database/repositories/in-memory-chat-model.repository';
import type { MetricsRegistryService } from '@app/infra/observability/metrics-registry.service';
import type { DeviceSessionEntity } from '@app/modules/auth/entities/device-session.entity';
import { InMemoryAuthRepository } from '@app/modules/auth/repositories/in-memory-auth.repository';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import type { RealtimePresenceService } from '@app/modules/realtime/services/realtime-presence.service';

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
    privacyModeEnabled: boolean;
  }): Promise<PushRegistrationEntity> {
    const now = new Date();
    const registration: PushRegistrationEntity = {
      id: `push-${this.registrationsById.size + 1}`,
      userId: params.userId,
      sessionId: params.sessionId,
      provider: params.provider,
      token: params.token,
      pushEnvironment: params.pushEnvironment,
      privacyModeEnabled: params.privacyModeEnabled,
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

class RecordingPushDeliveryProvider extends PushDeliveryProvider {
  readonly requests: PushDeliveryRequest[] = [];

  override async send(request: PushDeliveryRequest): Promise<void> {
    this.requests.push(request);
  }
}

describe('NotificationsService', () => {
  function createFixture() {
    const authRepository = new InMemoryAuthRepository();
    const chatModelRepository = new InMemoryChatModelRepository();
    const pushRegistrationRepository = new InMemoryPushRegistrationRepository();
    const authIdentityService = new AuthIdentityService(authRepository);
    const realtimePresenceService = {
      getUserPresence: jest.fn().mockResolvedValue({
        userId: 'unknown',
        isOnline: false,
        activeConnectionCount: 0,
        activeSessionCount: 0,
        lastSeenAt: null,
      }),
    } as unknown as RealtimePresenceService;
    const metricsRegistryService = {
      incrementCounter: jest.fn(),
    } as unknown as MetricsRegistryService;
    const pushDeliveryProvider = new RecordingPushDeliveryProvider();
    const syncStateService = new NotificationSyncStateService(
      authIdentityService,
      chatModelRepository,
      metricsRegistryService,
    );
    const pushDispatcherService = new NotificationPushDispatcherService(
      pushRegistrationRepository,
      authRepository,
      authIdentityService,
      chatModelRepository,
      realtimePresenceService,
      metricsRegistryService,
      pushDeliveryProvider,
      syncStateService,
    );
    const service = new NotificationsService(
      pushRegistrationRepository,
      pushDispatcherService,
      syncStateService,
    );
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
      authRepository,
      chatModelRepository,
      pushDeliveryProvider,
      pushRegistrationRepository,
      realtimePresenceService,
      metricsRegistryService,
      service,
      session,
    };
  }

  it('should register a new push token with privacy mode for the current session', async () => {
    const fixture = createFixture();
    const dto: RegisterPushTokenDto = {
      provider: 'apns',
      token: 'apns_token_1234567890',
      pushEnvironment: 'sandbox',
      privacyModeEnabled: true,
    };

    const result = await fixture.service.registerPushToken({
      userId: 'user-1',
      session: fixture.session,
      dto,
    });

    expect(result).toMatchObject({
      provider: 'apns',
      pushEnvironment: 'sandbox',
      privacyModeEnabled: true,
      isCurrentSession: true,
    });
  });

  it('should dispatch offline pushes with redacted content when privacy mode is enabled', async () => {
    const fixture = createFixture();
    const alice = await fixture.authRepository.createUser({
      identifier: 'alice@example.com',
      nickname: 'Alice',
      handle: 'alice_user',
    });
    const bob = await fixture.authRepository.createUser({
      identifier: 'bob@example.com',
      nickname: 'Bob',
      handle: 'bob_user',
    });
    const bobSession = await fixture.authRepository.createSession({
      userId: bob.id,
      deviceName: 'bob-phone',
      refreshNonce: 'nonce-bob',
    });
    const conversation = await fixture.chatModelRepository.createConversation({
      type: 'direct',
      createdBy: alice.id,
      memberIds: [alice.id, bob.id],
    });
    const message = await fixture.chatModelRepository.createMessage({
      conversationId: conversation.id,
      senderId: alice.id,
      clientMessageId: 'client-msg-1',
      type: 'text',
      content: { text: '今晚 8 点开会' },
    });
    await fixture.pushRegistrationRepository.createRegistration({
      userId: bob.id,
      sessionId: bobSession.id,
      provider: 'fcm',
      token: 'fcm_token_1234567890',
      pushEnvironment: 'production',
      privacyModeEnabled: true,
    });

    await fixture.service.dispatchOfflineMessagePush({
      conversationId: conversation.id,
      senderUserId: alice.id,
      messageId: message.id,
    });

    expect(fixture.pushDeliveryProvider.requests).toHaveLength(1);
    expect(fixture.pushDeliveryProvider.requests[0]).toMatchObject({
      title: 'Alice',
      body: '你收到一条新消息',
      badgeCount: 1,
      data: expect.objectContaining({
        conversationId: conversation.id,
        unreadCount: '1',
        badgeCount: '1',
        messagePreview: '',
        privacyModeEnabled: 'true',
      }),
    });
  });

  it('should skip offline push when the recipient still has realtime connections', async () => {
    const fixture = createFixture();
    const alice = await fixture.authRepository.createUser({
      identifier: 'alice@example.com',
      nickname: 'Alice',
      handle: 'alice_user',
    });
    const bob = await fixture.authRepository.createUser({
      identifier: 'bob@example.com',
      nickname: 'Bob',
      handle: 'bob_user',
    });
    const bobSession = await fixture.authRepository.createSession({
      userId: bob.id,
      deviceName: 'bob-phone',
      refreshNonce: 'nonce-bob',
    });
    const conversation = await fixture.chatModelRepository.createConversation({
      type: 'direct',
      createdBy: alice.id,
      memberIds: [alice.id, bob.id],
    });
    const message = await fixture.chatModelRepository.createMessage({
      conversationId: conversation.id,
      senderId: alice.id,
      clientMessageId: 'client-msg-2',
      type: 'text',
      content: { text: '在线用户不该收到推送' },
    });
    await fixture.pushRegistrationRepository.createRegistration({
      userId: bob.id,
      sessionId: bobSession.id,
      provider: 'fcm',
      token: 'fcm_token_online',
      pushEnvironment: 'production',
      privacyModeEnabled: false,
    });
    (
      fixture.realtimePresenceService as unknown as {
        getUserPresence: jest.Mock;
      }
    ).getUserPresence.mockResolvedValue({
      userId: bob.id,
      isOnline: true,
      activeConnectionCount: 1,
      activeSessionCount: 1,
      lastSeenAt: new Date().toISOString(),
    });

    await fixture.service.dispatchOfflineMessagePush({
      conversationId: conversation.id,
      senderUserId: alice.id,
      messageId: message.id,
    });

    expect(fixture.pushDeliveryProvider.requests).toHaveLength(0);
  });

  it('should keep repeated sync-state calls idempotent for unread and gap recovery', async () => {
    const fixture = createFixture();
    const alice = await fixture.authRepository.createUser({
      identifier: 'alice@example.com',
      nickname: 'Alice',
      handle: 'alice_user',
    });
    const bob = await fixture.authRepository.createUser({
      identifier: 'bob@example.com',
      nickname: 'Bob',
      handle: 'bob_user',
    });
    const conversation = await fixture.chatModelRepository.createConversation({
      type: 'direct',
      createdBy: alice.id,
      memberIds: [alice.id, bob.id],
    });

    for (let index = 1; index <= 3; index += 1) {
      await fixture.chatModelRepository.createMessage({
        conversationId: conversation.id,
        senderId: index % 2 === 0 ? bob.id : alice.id,
        clientMessageId: `client-msg-${index}`,
        type: 'text',
        content: { text: `消息 ${index}` },
      });
    }

    await fixture.chatModelRepository.updateReadCursor({
      conversationId: conversation.id,
      userId: bob.id,
      lastReadSequence: 1,
    });

    const first = await fixture.service.syncState(bob.id, {
      conversationStates: [
        {
          conversationId: conversation.id,
          afterSequence: 1,
        },
      ],
      gapLimit: 10,
      pushMessageId: 'push-msg-1',
    });
    const second = await fixture.service.syncState(bob.id, {
      conversationStates: [
        {
          conversationId: conversation.id,
          afterSequence: 1,
        },
      ],
      gapLimit: 10,
      pushMessageId: 'push-msg-1',
    });

    expect(first.unreadBadgeCount).toBe(2);
    expect(first.conversations[0]).toMatchObject({
      id: conversation.id,
      unreadCount: 2,
    });
    expect(first.gaps[0]?.items.map((item) => item.sequence)).toEqual([2, 3]);
    expect(second.unreadBadgeCount).toBe(first.unreadBadgeCount);
    expect(second.gaps[0]?.items.map((item) => item.sequence)).toEqual([2, 3]);
    expect(second.recoveredPushMessageId).toBe('push-msg-1');
  });
});
