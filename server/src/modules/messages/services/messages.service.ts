import {
  BadRequestException,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';

import type { GetConversationHistoryQueryDto } from '../dto/get-conversation-history-query.dto';
import type {
  MessageHistoryPageDto,
  MessageSyncDto,
} from '../dto/message-history.dto';
import { type SendMessageResponseDto, toMessageView } from '../dto/message.dto';
import type { SendMessageDto } from '../dto/send-message.dto';
import type { SyncMessagesQueryDto } from '../dto/sync-messages-query.dto';
import { MessageIdempotencyStore } from '../stores/message-idempotency.store';

import { RateLimitService } from '@app/infra/abuse/services/rate-limit.service';
import type { ConversationEntity } from '@app/infra/database/entities/conversation.entity';
import { ChatModelRepository } from '@app/infra/database/repositories/chat-model.repository';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import {
  toReadCursorView,
  type ReadCursorView,
} from '@app/modules/conversations/dto/read-cursor.dto';
import { MediaAttachmentRepository } from '@app/modules/media/repositories/media-attachment.repository';
import { NotificationsService } from '@app/modules/notifications/services/notifications.service';
import { ChatGateway } from '@app/modules/realtime/gateways/chat.gateway';
import {
  toUserDiscoveryProfileDto,
  type UserDiscoveryProfileDto,
} from '@app/modules/users/dto/user-profile.dto';

@Injectable()
export class MessagesService {
  private readonly defaultHistoryPageSize = 20;
  private readonly defaultSyncPageSize = 100;
  private readonly sendMessageWindowMs = 60 * 1000;

  constructor(
    private readonly chatModelRepository: ChatModelRepository,
    private readonly messageIdempotencyStore: MessageIdempotencyStore,
    private readonly authIdentityService: AuthIdentityService,
    private readonly mediaAttachmentRepository: MediaAttachmentRepository,
    private readonly rateLimitService: RateLimitService,
    private readonly notificationsService: NotificationsService,
    private readonly chatGateway: ChatGateway,
  ) {}

  getHealth(): { module: string; status: string } {
    return {
      module: 'messages',
      status: 'ready',
    };
  }

  async getModelSummary(): Promise<{
    module: string;
    status: string;
    models: string[];
    summary: Awaited<ReturnType<ChatModelRepository['getSummary']>>;
  }> {
    return {
      module: 'messages',
      status: 'ready',
      models: ['message', 'message-sequence', 'message-idempotency'],
      summary: await this.chatModelRepository.getSummary(),
    };
  }

  async sendMessage(
    senderUserId: string,
    dto: SendMessageDto,
  ): Promise<SendMessageResponseDto> {
    await this.rateLimitService.consumeOrThrow({
      scope: 'messages.send',
      actorKey: senderUserId,
      limit: 60,
      windowMs: this.sendMessageWindowMs,
      message: '消息发送过于频繁，请稍后再试',
      metadata: {
        conversationId: dto.conversationId,
      },
    });
    await this.authIdentityService.getActiveUserById(senderUserId);
    await this.getAccessibleConversationOrThrow(dto.conversationId, senderUserId);

    const clientMessageId = dto.clientMessageId.trim();
    const idempotencyKey = {
      conversationId: dto.conversationId,
      senderId: senderUserId,
      clientMessageId,
    };
    const existingMessage = await this.resolveExistingMessage(idempotencyKey);

    if (existingMessage) {
      await this.chatModelRepository.updateReadCursor({
        conversationId: dto.conversationId,
        userId: senderUserId,
        lastReadSequence: existingMessage.sequence,
      });

      return {
        ack: 'accepted',
        message: await this.buildMessageView(existingMessage.id),
      };
    }

    const reservationGranted = await this.messageIdempotencyStore.reserve(
      idempotencyKey,
    );
    let shouldReleaseReservation = reservationGranted;

    try {
      const message = await this.chatModelRepository.createMessage({
        conversationId: dto.conversationId,
        senderId: senderUserId,
        clientMessageId,
        type: dto.type,
        content: await this.buildMessageContent(senderUserId, dto),
      });

      await this.messageIdempotencyStore.bind({
        ...idempotencyKey,
        messageId: message.id,
      });
      shouldReleaseReservation = false;

      // 发送者自己的最新消息默认视为已读，这样后续未读计数不会把自己消息算进去。
      await this.chatModelRepository.updateReadCursor({
        conversationId: dto.conversationId,
        userId: senderUserId,
        lastReadSequence: message.sequence,
      });

      const messageView = await this.buildMessageView(message.id);

      // REST ack 负责当前发送端确认，实时事件负责把同一条消息扩散到在线成员和发送端其他设备。
      this.chatGateway.emitMessageCreated(messageView);
      await this.notificationsService.dispatchOfflineMessagePush({
        conversationId: dto.conversationId,
        senderUserId,
        messageId: message.id,
      });

      return {
        ack: 'accepted',
        message: messageView,
      };
    } catch (error) {
      if (shouldReleaseReservation) {
        await this.messageIdempotencyStore.release(idempotencyKey);
      }

      throw error;
    }
  }

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
      // 首屏历史接口顺便带回当前读游标快照，避免客户端必须等后续实时事件才能知道谁已读到哪里。
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

  private async buildMessageContent(
    senderUserId: string,
    dto: SendMessageDto,
  ): Promise<Record<string, unknown>> {
    if (dto.type === 'text') {
      const normalizedText = dto.text?.trim();

      if (!normalizedText) {
        throw new BadRequestException('文本消息不能为空');
      }

      return {
        text: normalizedText,
      };
    }

    const attachmentId = dto.payload?.['attachmentId'];

    if (typeof attachmentId !== 'string' || attachmentId.trim().length === 0) {
      throw new BadRequestException('附件消息必须携带 attachmentId');
    }

    const attachment = await this.mediaAttachmentRepository.getAttachmentOrThrow(
      attachmentId.trim(),
    );

    if (attachment.ownerId !== senderUserId) {
      throw new ForbiddenException('不能发送不属于自己的附件');
    }

    if (attachment.conversationId !== dto.conversationId) {
      throw new BadRequestException('附件不属于当前会话');
    }

    if (attachment.attachmentKind !== dto.type) {
      throw new BadRequestException('消息类型与附件类型不匹配');
    }

    if (attachment.status === 'pending_upload') {
      throw new BadRequestException('附件尚未完成上传确认');
    }

    if (attachment.status === 'failed') {
      throw new BadRequestException('附件处理失败，不能发送');
    }

    return {
      attachmentId: attachment.id,
      attachmentKind: attachment.attachmentKind,
      attachmentStatus: attachment.status,
      fileName: attachment.fileName,
      mimeType: attachment.mimeType,
      sizeBytes: attachment.sizeBytes,
      previewObjectKey: attachment.previewObjectKey,
    };
  }

  private async getAccessibleConversationOrThrow(
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

  private async buildMessageView(messageId: string) {
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

  private async resolveExistingMessage(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
  }) {
    const boundMessageId = await this.messageIdempotencyStore.getBoundMessageId(
      params,
    );

    if (boundMessageId) {
      try {
        return await this.chatModelRepository.getMessageOrThrow(boundMessageId);
      } catch {
        await this.messageIdempotencyStore.release(params);
      }
    }

    return this.chatModelRepository.findMessageByClientKey(params);
  }
}
