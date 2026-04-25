import { Injectable } from '@nestjs/common';

import type { NotificationSyncStateDto } from '../dto/notification-sync-state.dto';
import {
  type PushRegistrationView,
  toPushRegistrationView,
} from '../dto/push-registration.dto';
import { RegisterPushTokenDto } from '../dto/register-push-token.dto';
import type { SyncNotificationStateDto } from '../dto/sync-notification-state.dto';
import { PushRegistrationRepository } from '../repositories/push-registration.repository';

import {
  LoggingPushDeliveryProvider,
  PushDeliveryProvider,
} from './push-delivery.provider';

import { ChatModelRepository } from '@app/infra/database/repositories/chat-model.repository';
import { MetricsRegistryService } from '@app/infra/observability/metrics-registry.service';
import type { DeviceSessionEntity } from '@app/modules/auth/entities/device-session.entity';
import { AuthRepository } from '@app/modules/auth/repositories/auth.repository';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import {
  type ConversationSummaryView,
  toConversationSummaryView,
} from '@app/modules/conversations/dto/conversation-summary.dto';
import type { MessageSyncDto } from '@app/modules/messages/dto/message-history.dto';
import { toMessageView } from '@app/modules/messages/dto/message.dto';
import { RealtimePresenceService } from '@app/modules/realtime/services/realtime-presence.service';
import { toUserDiscoveryProfileDto } from '@app/modules/users/dto/user-profile.dto';

@Injectable()
export class NotificationsService {
  private readonly defaultGapLimit = 100;

  constructor(
    private readonly pushRegistrationRepository: PushRegistrationRepository,
    private readonly authRepository: AuthRepository,
    private readonly authIdentityService: AuthIdentityService,
    private readonly chatModelRepository: ChatModelRepository,
    private readonly realtimePresenceService: RealtimePresenceService,
    private readonly metricsRegistryService: MetricsRegistryService,
    private readonly pushDeliveryProvider: PushDeliveryProvider = new LoggingPushDeliveryProvider(),
  ) {}

  getHealth(): { module: string; status: string } {
    return {
      module: 'notifications',
      status: 'ready',
    };
  }

  async registerPushToken(params: {
    userId: string;
    session: DeviceSessionEntity;
    dto: RegisterPushTokenDto;
  }): Promise<PushRegistrationView> {
    const existingRegistration =
      await this.pushRegistrationRepository.findRegistrationByProviderAndToken({
        provider: params.dto.provider,
        token: params.dto.token.trim(),
      });

    let registration = existingRegistration;

    if (registration == null) {
      registration = await this.pushRegistrationRepository.createRegistration({
        userId: params.userId,
        sessionId: params.session.id,
        provider: params.dto.provider,
        token: params.dto.token.trim(),
        pushEnvironment: params.dto.pushEnvironment,
        privacyModeEnabled: params.dto.privacyModeEnabled ?? false,
      });
    } else {
      registration.userId = params.userId;
      registration.sessionId = params.session.id;
      registration.pushEnvironment = params.dto.pushEnvironment;
      registration.privacyModeEnabled = params.dto.privacyModeEnabled ?? false;
      registration.lastRegisteredAt = new Date();
      registration.revokedAt = null;
      await this.pushRegistrationRepository.saveRegistration(registration);
    }

    await this.pushRegistrationRepository.revokeOtherSessionProviderRegistrations({
      sessionId: params.session.id,
      provider: params.dto.provider,
      excludedRegistrationId: registration.id,
    });

    return toPushRegistrationView(registration, params.session.id);
  }

  async listActiveRegistrations(
    userId: string,
    currentSessionId: string,
  ): Promise<PushRegistrationView[]> {
    const registrations =
      await this.pushRegistrationRepository.listActiveRegistrationsByUserId(
        userId,
      );

    return registrations
      .map((registration) => {
        return toPushRegistrationView(registration, currentSessionId);
      })
      .sort((left, right) => {
        return right.updatedAt.localeCompare(left.updatedAt);
      });
  }

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

      // 有实时连接就依赖 websocket 送达，避免前台在线设备同时收到重复系统推送。
      if (presence.activeConnectionCount > 0) {
        this.metricsRegistryService.incrementCounter('chat_push_delivery_total', {
          help: 'Total push delivery attempts partitioned by provider and result.',
          labels: {
            provider: 'realtime',
            result: 'skipped_online',
          },
        });
        continue;
      }

      const registrations =
        await this.pushRegistrationRepository.listActiveRegistrationsByUserId(
          recipientUserId,
        );

      if (registrations.length === 0) {
        this.metricsRegistryService.incrementCounter('chat_push_delivery_total', {
          help: 'Total push delivery attempts partitioned by provider and result.',
          labels: {
            provider: 'unregistered',
            result: 'skipped_missing_registration',
          },
        });
        continue;
      }

      const unreadCount = await this.getConversationUnreadCount(
        params.conversationId,
        recipientUserId,
      );
      const badgeCount = await this.getTotalUnreadCount(recipientUserId);
      const preview = this.buildMessagePreview(message);
      const title = await this.buildPushTitle({
        conversationId: params.conversationId,
        sender,
      });

      for (const registration of registrations) {
        const session = await this.authRepository.findActiveSessionById(
          registration.sessionId,
        );

        if (session == null || session.userId !== recipientUserId) {
          this.metricsRegistryService.incrementCounter('chat_push_delivery_total', {
            help: 'Total push delivery attempts partitioned by provider and result.',
            labels: {
              provider: registration.provider,
              result: 'skipped_session_invalid',
            },
          });
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
          this.metricsRegistryService.incrementCounter('chat_push_delivery_total', {
            help: 'Total push delivery attempts partitioned by provider and result.',
            labels: {
              provider: registration.provider,
              result: 'sent',
            },
          });
        } catch (error) {
          this.metricsRegistryService.incrementCounter('chat_push_delivery_total', {
            help: 'Total push delivery attempts partitioned by provider and result.',
            labels: {
              provider: registration.provider,
              result: 'failed',
            },
          });
          throw error;
        }
      }
    }
  }

  async syncState(
    userId: string,
    dto: SyncNotificationStateDto,
  ): Promise<NotificationSyncStateDto> {
    this.metricsRegistryService.incrementCounter('chat_notification_sync_total', {
      help: 'Total number of notification sync requests handled by the server.',
      labels: {
        source: dto.pushMessageId?.trim() ? 'push_wakeup' : 'manual',
      },
    });
    await this.authIdentityService.getActiveUserById(userId);
    const conversationIds =
      await this.chatModelRepository.listConversationIdsForUser(userId);
    const conversationIdSet = new Set(conversationIds);
    const conversations = await this.listRecentConversationSummaries(userId);
    const gaps = await Promise.all(
      (dto.conversationStates ?? [])
        .filter((state) => {
          return conversationIdSet.has(state.conversationId);
        })
        .map((state) => {
          return this.buildGapState({
            conversationId: state.conversationId,
            afterSequence: state.afterSequence,
            limit: dto.gapLimit ?? this.defaultGapLimit,
          });
        }),
    );

    return {
      serverTime: new Date().toISOString(),
      unreadBadgeCount: conversations.reduce((sum, conversation) => {
        return sum + conversation.unreadCount;
      }, 0),
      conversations,
      gaps,
      recoveredPushMessageId: dto.pushMessageId?.trim() || null,
    };
  }

  private async listRecentConversationSummaries(
    userId: string,
  ): Promise<ConversationSummaryView[]> {
    const conversationIdSet = new Set(
      await this.chatModelRepository.listConversationIdsForUser(userId),
    );
    const conversations = (await this.chatModelRepository.listConversations())
      .filter((conversation) => conversationIdSet.has(conversation.id))
      .sort((left, right) => {
        return right.updatedAt.getTime() - left.updatedAt.getTime();
      });

    return Promise.all(
      conversations.map((conversation) => {
        return this.buildConversationSummaryView(conversation.id, userId);
      }),
    );
  }

  private async buildConversationSummaryView(
    conversationId: string,
    requesterUserId: string,
  ): Promise<ConversationSummaryView> {
    const conversation =
      await this.chatModelRepository.getConversationOrThrow(conversationId);
    const latestMessage =
      await this.chatModelRepository.findLatestMessage(conversationId);

    return toConversationSummaryView({
      id: conversation.id,
      type: conversation.type,
      title: await this.resolveConversationTitle(conversation.id, requesterUserId),
      memberCount: (
        await this.chatModelRepository.listConversationMemberUserIds(
          conversation.id,
        )
      ).length,
      latestSequence: conversation.latestSequence,
      lastMessagePreview: latestMessage
        ? this.buildMessagePreview(latestMessage)
        : '暂无消息',
      lastMessageAt: latestMessage?.createdAt ?? null,
      unreadCount: await this.getConversationUnreadCount(
        conversation.id,
        requesterUserId,
      ),
      updatedAt: conversation.updatedAt,
    });
  }

  private async resolveConversationTitle(
    conversationId: string,
    requesterUserId: string,
  ): Promise<string> {
    const conversation =
      await this.chatModelRepository.getConversationOrThrow(conversationId);

    if (conversation.type === 'group') {
      return conversation.title?.trim() || '未命名群聊';
    }

    const otherMemberIds = (
      await this.chatModelRepository.listConversationMemberUserIds(conversationId)
    ).filter((memberId) => memberId !== requesterUserId);

    if (otherMemberIds.length === 0) {
      return '仅自己';
    }

    const peer = await this.authIdentityService.getActiveUserById(otherMemberIds[0]!);
    return peer.nickname;
  }

  private async buildGapState(params: {
    conversationId: string;
    afterSequence: number;
    limit: number;
  }): Promise<MessageSyncDto> {
    const conversation = await this.chatModelRepository.getConversationOrThrow(
      params.conversationId,
    );
    const messages = (
      await this.chatModelRepository.listMessagesAfterSequence(
        params.conversationId,
        params.afterSequence,
      )
    ).slice(0, params.limit);
    const nextAfterSequence =
      messages.length > 0
        ? messages[messages.length - 1]!.sequence
        : params.afterSequence;

    return {
      conversationId: params.conversationId,
      latestSequence: conversation.latestSequence,
      nextAfterSequence,
      hasMore: nextAfterSequence < conversation.latestSequence,
      items: await Promise.all(
        messages.map((message) => this.buildMessageView(message.id)),
      ),
    };
  }

  private async buildMessageView(messageId: string) {
    const message = await this.chatModelRepository.getMessageOrThrow(messageId);

    return toMessageView(
      message,
      toUserDiscoveryProfileDto(
        await this.authIdentityService.getActiveUserById(message.senderId),
      ),
    );
  }

  private buildMessagePreview(message: {
    type: string;
    content: Record<string, unknown>;
  }): string {
    if (message.type === 'text') {
      const text = message.content['text'];
      return typeof text === 'string' && text.trim().length > 0
        ? text.trim()
        : '[文本消息]';
    }

    switch (message.type) {
      case 'image':
        return '[图片消息]';
      case 'audio':
        return '[语音消息]';
      case 'file':
        return '[文件消息]';
      default:
        return '[新消息]';
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

  private async getConversationUnreadCount(
    conversationId: string,
    userId: string,
  ): Promise<number> {
    const [conversation, cursor] = await Promise.all([
      this.chatModelRepository.getConversationOrThrow(conversationId),
      this.chatModelRepository.findReadCursor(conversationId, userId),
    ]);

    return Math.max(
      conversation.latestSequence - (cursor?.lastReadSequence ?? 0),
      0,
    );
  }

  private async getTotalUnreadCount(userId: string): Promise<number> {
    const conversationIds =
      await this.chatModelRepository.listConversationIdsForUser(userId);
    let unreadCount = 0;

    for (const conversationId of conversationIds) {
      unreadCount += await this.getConversationUnreadCount(conversationId, userId);
    }

    return unreadCount;
  }
}
