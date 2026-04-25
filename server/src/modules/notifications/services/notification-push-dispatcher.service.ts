import { Injectable } from '@nestjs/common';

import { PushRegistrationRepository } from '../repositories/push-registration.repository';

import { NotificationSyncStateService } from './notification-sync-state.service';
import { PushDeliveryProvider } from './push-delivery.provider';

import { ChatModelRepository } from '@app/infra/database/repositories/chat-model.repository';
import { MetricsRegistryService } from '@app/infra/observability/metrics-registry.service';
import { AuthRepository } from '@app/modules/auth/repositories/auth.repository';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import { RealtimePresenceService } from '@app/modules/realtime/services/realtime-presence.service';
import { toUserDiscoveryProfileDto } from '@app/modules/users/dto/user-profile.dto';

@Injectable()
export class NotificationPushDispatcherService {
  constructor(
    private readonly pushRegistrationRepository: PushRegistrationRepository,
    private readonly authRepository: AuthRepository,
    private readonly authIdentityService: AuthIdentityService,
    private readonly chatModelRepository: ChatModelRepository,
    private readonly realtimePresenceService: RealtimePresenceService,
    private readonly metricsRegistryService: MetricsRegistryService,
    private readonly pushDeliveryProvider: PushDeliveryProvider,
    private readonly syncStateService: NotificationSyncStateService,
  ) {}

  async dispatchOfflineMessagePush(params: {
    conversationId: string;
    senderUserId: string;
    messageId: string;
  }): Promise<void> {
    const [conversation, message, sender] = await Promise.all([
      this.chatModelRepository.getConversationOrThrow(params.conversationId),
      this.chatModelRepository.getMessageOrThrow(params.messageId),
      this.authIdentityService.getActiveUserById(params.senderUserId),
    ]);
    const memberIds = await this.chatModelRepository.listConversationMemberUserIds(
      params.conversationId,
    );

    for (const recipientUserId of memberIds) {
      if (recipientUserId === params.senderUserId) {
        continue;
      }

      const presence = await this.realtimePresenceService.getUserPresence(
        recipientUserId,
      );

      if (presence.activeConnectionCount > 0) {
        this.recordDeliveryMetric('realtime', 'skipped_online');
        continue;
      }

      const registrations =
        await this.pushRegistrationRepository.listActiveRegistrationsByUserId(
          recipientUserId,
        );

      if (registrations.length === 0) {
        this.recordDeliveryMetric('unregistered', 'skipped_missing_registration');
        continue;
      }

      const unreadCount = await this.syncStateService.getConversationUnreadCount(
        params.conversationId,
        recipientUserId,
      );
      const badgeCount = await this.syncStateService.getTotalUnreadCount(
        recipientUserId,
      );
      const preview = this.syncStateService.buildMessagePreview(message);
      const title = await this.buildPushTitle({
        conversationId: params.conversationId,
        sender,
      });

      for (const registration of registrations) {
        const session = await this.authRepository.findActiveSessionById(
          registration.sessionId,
        );

        if (session == null || session.userId !== recipientUserId) {
          this.recordDeliveryMetric(
            registration.provider,
            'skipped_session_invalid',
          );
          continue;
        }

        const body = registration.privacyModeEnabled
          ? '你收到一条新消息'
          : preview;

        try {
          await this.pushDeliveryProvider.send({
            registration,
            title,
            body,
            badgeCount,
            data: {
              badgeCount: String(badgeCount),
              conversationId: params.conversationId,
              messageId: message.id,
              senderId: sender.id,
              senderName: sender.nickname,
              sequence: String(conversation.latestSequence),
              unreadCount: String(unreadCount),
              privacyModeEnabled: String(registration.privacyModeEnabled),
              messagePreview: registration.privacyModeEnabled ? '' : preview,
              title,
              body,
            },
          });
          this.recordDeliveryMetric(registration.provider, 'sent');
        } catch (error) {
          this.recordDeliveryMetric(registration.provider, 'failed');
          throw error;
        }
      }
    }
  }

  private async buildPushTitle(params: {
    conversationId: string;
    sender: Awaited<ReturnType<AuthIdentityService['getActiveUserById']>>;
  }): Promise<string> {
    const conversation = await this.chatModelRepository.getConversationOrThrow(
      params.conversationId,
    );

    if (conversation.type === 'group') {
      const groupTitle = conversation.title?.trim() || '群聊';
      return `${params.sender.nickname} · ${groupTitle}`;
    }

    const peerProfile = toUserDiscoveryProfileDto(params.sender);
    return peerProfile.nickname;
  }

  private recordDeliveryMetric(provider: string, result: string): void {
    this.metricsRegistryService.incrementCounter('chat_push_delivery_total', {
      help: 'Total push delivery attempts partitioned by provider and result.',
      labels: {
        provider,
        result,
      },
    });
  }
}
