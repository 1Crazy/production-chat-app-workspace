import { ForbiddenException, Injectable } from '@nestjs/common';

import type { GetConversationHistoryQueryDto } from '../dto/get-conversation-history-query.dto';
import type {
  MessageHistoryPageDto,
  MessageSyncDto,
} from '../dto/message-history.dto';
import { toMessageView } from '../dto/message.dto';
import type { SyncMessagesQueryDto } from '../dto/sync-messages-query.dto';

import type { ConversationEntity } from '@app/infra/database/entities/conversation.entity';
import { ChatModelRepository } from '@app/infra/database/repositories/chat-model.repository';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import {
  toReadCursorView,
  type ReadCursorView,
} from '@app/modules/conversations/dto/read-cursor.dto';
import {
  toUserDiscoveryProfileDto,
  type UserDiscoveryProfileDto,
} from '@app/modules/users/dto/user-profile.dto';

@Injectable()
export class MessageReaderService {
  private readonly defaultHistoryPageSize = 20;
  private readonly defaultSyncPageSize = 100;

  constructor(
    private readonly chatModelRepository: ChatModelRepository,
    private readonly authIdentityService: AuthIdentityService,
  ) {}

  async getConversationHistory(
    requesterUserId: string,
    conversationId: string,
    query: GetConversationHistoryQueryDto,
  ): Promise<MessageHistoryPageDto> {
    const conversation = await this.getAccessibleConversationOrThrow(
      conversationId,
      requesterUserId,
    );
    const limit = query.limit ?? this.defaultHistoryPageSize;
    const upperBoundSequence =
      query.beforeSequence == null
        ? conversation.latestSequence
        : Math.max(query.beforeSequence - 1, 0);
    const eligibleMessages = (
      await this.chatModelRepository.listMessages(conversationId)
    ).filter((message) => {
      return message.sequence <= upperBoundSequence;
    });
    const pageItems = eligibleMessages.slice(
      Math.max(eligibleMessages.length - limit, 0),
    );
    const nextCursor =
      pageItems.length > 0 && eligibleMessages.length > pageItems.length
        ? {
            beforeSequence: pageItems[0]!.sequence,
          }
        : null;

    return {
      conversationId,
      latestSequence: conversation.latestSequence,
      items: await Promise.all(
        pageItems.map((message) => this.buildMessageView(message.id)),
      ),
      readCursors: await this.buildReadCursorViews(conversationId),
      memberProfiles: await this.buildMemberProfiles(conversationId),
      nextCursor,
    };
  }

  async syncConversationMessages(
    requesterUserId: string,
    conversationId: string,
    query: SyncMessagesQueryDto,
  ): Promise<MessageSyncDto> {
    const conversation = await this.getAccessibleConversationOrThrow(
      conversationId,
      requesterUserId,
    );
    const limit = query.limit ?? this.defaultSyncPageSize;
    const missingMessages = (
      await this.chatModelRepository.listMessagesAfterSequence(
        conversationId,
        query.afterSequence,
      )
    ).slice(0, limit);
    const nextAfterSequence =
      missingMessages.length > 0
        ? missingMessages[missingMessages.length - 1]!.sequence
        : query.afterSequence;

    return {
      conversationId,
      latestSequence: conversation.latestSequence,
      nextAfterSequence,
      hasMore: nextAfterSequence < conversation.latestSequence,
      items: await Promise.all(
        missingMessages.map((message) => this.buildMessageView(message.id)),
      ),
    };
  }

  async getAccessibleConversationOrThrow(
    conversationId: string,
    requesterUserId: string,
  ): Promise<ConversationEntity> {
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

  async buildMessageView(messageId: string) {
    const message = await this.chatModelRepository.getMessageOrThrow(messageId);

    return toMessageView(
      message,
      toUserDiscoveryProfileDto(
        await this.authIdentityService.getActiveUserById(message.senderId),
      ),
    );
  }

  private async buildReadCursorViews(
    conversationId: string,
  ): Promise<ReadCursorView[]> {
    const [conversation, cursors] = await Promise.all([
      this.chatModelRepository.getConversationOrThrow(conversationId),
      this.chatModelRepository.listReadCursorsForConversation(conversationId),
    ]);

    return cursors.map((cursor) => {
      return toReadCursorView(
        cursor,
        Math.max(conversation.latestSequence - cursor.lastReadSequence, 0),
      );
    });
  }

  private async buildMemberProfiles(
    conversationId: string,
  ): Promise<UserDiscoveryProfileDto[]> {
    return Promise.all(
      (
        await this.chatModelRepository.listConversationMemberUserIds(
          conversationId,
        )
      ).map(async (userId) => {
        return toUserDiscoveryProfileDto(
          await this.authIdentityService.getActiveUserById(userId),
        );
      }),
    );
  }
}
