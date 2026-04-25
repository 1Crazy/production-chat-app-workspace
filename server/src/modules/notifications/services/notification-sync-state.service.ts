import { Injectable } from '@nestjs/common';

import type { NotificationSyncStateDto } from '../dto/notification-sync-state.dto';
import type { SyncNotificationStateDto } from '../dto/sync-notification-state.dto';

import { ChatModelRepository } from '@app/infra/database/repositories/chat-model.repository';
import { MetricsRegistryService } from '@app/infra/observability/metrics-registry.service';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import {
  type ConversationSummaryView,
  toConversationSummaryView,
} from '@app/modules/conversations/dto/conversation-summary.dto';
import type { MessageSyncDto } from '@app/modules/messages/dto/message-history.dto';
import { toMessageView } from '@app/modules/messages/dto/message.dto';
import { toUserDiscoveryProfileDto } from '@app/modules/users/dto/user-profile.dto';

@Injectable()
export class NotificationSyncStateService {
  private readonly defaultGapLimit = 100;

  constructor(
    private readonly authIdentityService: AuthIdentityService,
    private readonly chatModelRepository: ChatModelRepository,
    private readonly metricsRegistryService: MetricsRegistryService,
  ) {}

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

  async listRecentConversationSummaries(
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

  async getConversationUnreadCount(
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

  async getTotalUnreadCount(userId: string): Promise<number> {
    const conversationIds =
      await this.chatModelRepository.listConversationIdsForUser(userId);
    let unreadCount = 0;

    for (const conversationId of conversationIds) {
      unreadCount += await this.getConversationUnreadCount(conversationId, userId);
    }

    return unreadCount;
  }

  buildMessagePreview(message: {
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

    const peer = await this.authIdentityService.getActiveUserById(
      otherMemberIds[0]!,
    );
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
}
