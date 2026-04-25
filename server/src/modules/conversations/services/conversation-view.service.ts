import { ForbiddenException, Injectable } from '@nestjs/common';

import {
  type ConversationSummaryView,
  toConversationSummaryView,
} from '../dto/conversation-summary.dto';
import { type ConversationView, toConversationView } from '../dto/conversation.dto';

import type { MessageEntity } from '@app/infra/database/entities/message.entity';
import { ChatModelRepository } from '@app/infra/database/repositories/chat-model.repository';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import { toUserDiscoveryProfileDto } from '@app/modules/users/dto/user-profile.dto';

@Injectable()
export class ConversationViewService {
  constructor(
    private readonly chatModelRepository: ChatModelRepository,
    private readonly authIdentityService: AuthIdentityService,
  ) {}

  async buildConversationView(conversationId: string): Promise<ConversationView> {
    const conversation =
      await this.chatModelRepository.getConversationOrThrow(conversationId);
    const members = await Promise.all(
      (await this.chatModelRepository.listConversationMembers(conversationId)).map(
        async (member) => {
          const user = await this.authIdentityService.getActiveUserById(
            member.userId,
          );

          return {
            member,
            profile: toUserDiscoveryProfileDto(user),
          };
        },
      ),
    );

    return toConversationView({
      conversation,
      members,
    });
  }

  async listRecentConversations(
    requesterUserId: string,
  ): Promise<ConversationSummaryView[]> {
    await this.authIdentityService.getActiveUserById(requesterUserId);

    const conversationIdSet = new Set(
      await this.chatModelRepository.listConversationIdsForUser(requesterUserId),
    );
    const conversations = (await this.chatModelRepository.listConversations())
      .filter((conversation) => conversationIdSet.has(conversation.id))
      .sort((left, right) => {
        return right.updatedAt.getTime() - left.updatedAt.getTime();
      });

    return Promise.all(
      conversations.map((conversation) => {
        return this.buildConversationSummaryView(conversation.id, requesterUserId);
      }),
    );
  }

  async getAccessibleConversationOrThrow(
    conversationId: string,
    requesterUserId: string,
  ) {
    const conversation = await this.chatModelRepository.getConversationOrThrow(
      conversationId,
    );

    if (
      !(await this.chatModelRepository.isConversationMember(
        conversationId,
        requesterUserId,
      ))
    ) {
      throw new ForbiddenException('你不是该会话成员');
    }

    return conversation;
  }

  async getUnreadCount(
    conversationId: string,
    requesterUserId: string,
  ): Promise<number> {
    const conversation =
      await this.chatModelRepository.getConversationOrThrow(conversationId);
    const cursor = await this.chatModelRepository.findReadCursor(
      conversationId,
      requesterUserId,
    );

    return Math.max(conversation.latestSequence - (cursor?.lastReadSequence ?? 0), 0);
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
      lastMessagePreview: this.buildLastMessagePreview(latestMessage),
      lastMessageAt: latestMessage?.createdAt ?? null,
      unreadCount: await this.getUnreadCount(conversation.id, requesterUserId),
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
      return conversation.title ?? '未命名群聊';
    }

    const peer = (
      await this.chatModelRepository.listConversationMembers(conversationId)
    ).find((member) => member.userId !== requesterUserId);

    if (!peer) {
      return '和自己';
    }

    return (await this.authIdentityService.getActiveUserById(peer.userId))
      .nickname;
  }

  private buildLastMessagePreview(message: MessageEntity | null): string {
    if (!message) {
      return '还没有消息';
    }

    if (message.type === 'text') {
      return String(message.content.text ?? '');
    }

    if (message.type === 'image') {
      return '[图片]';
    }

    if (message.type === 'audio') {
      return '[语音]';
    }

    if (message.type === 'file') {
      return '[文件]';
    }

    return '[系统消息]';
  }
}
