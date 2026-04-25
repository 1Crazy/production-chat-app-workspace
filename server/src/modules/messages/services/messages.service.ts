import { Injectable } from '@nestjs/common';

import type { GetConversationHistoryQueryDto } from '../dto/get-conversation-history-query.dto';
import type {
  MessageHistoryPageDto,
  MessageSyncDto,
} from '../dto/message-history.dto';
import type { SendMessageResponseDto } from '../dto/message.dto';
import type { SendMessageDto } from '../dto/send-message.dto';
import type { SyncMessagesQueryDto } from '../dto/sync-messages-query.dto';
import { MessageIdempotencyStore } from '../stores/message-idempotency.store';

import { MessageContentService } from './message-content.service';
import { MessageReaderService } from './message-reader.service';

import { RateLimitService } from '@app/infra/abuse/services/rate-limit.service';
import { ChatModelRepository } from '@app/infra/database/repositories/chat-model.repository';
import { MetricsRegistryService } from '@app/infra/observability/metrics-registry.service';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import { NotificationsService } from '@app/modules/notifications/services/notifications.service';
import { ChatGateway } from '@app/modules/realtime/gateways/chat.gateway';

@Injectable()
export class MessagesService {
  private readonly sendMessageWindowMs = 60 * 1000;

  constructor(
    private readonly chatModelRepository: ChatModelRepository,
    private readonly messageIdempotencyStore: MessageIdempotencyStore,
    private readonly authIdentityService: AuthIdentityService,
    private readonly rateLimitService: RateLimitService,
    private readonly metricsRegistryService: MetricsRegistryService,
    private readonly notificationsService: NotificationsService,
    private readonly chatGateway: ChatGateway,
    private readonly messageContentService: MessageContentService,
    private readonly messageReaderService: MessageReaderService,
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
    await this.messageReaderService.getAccessibleConversationOrThrow(
      dto.conversationId,
      senderUserId,
    );

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
        message: await this.messageReaderService.buildMessageView(
          existingMessage.id,
        ),
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
        content: await this.messageContentService.buildMessageContent(
          senderUserId,
          dto,
        ),
      });

      await this.messageIdempotencyStore.bind({
        ...idempotencyKey,
        messageId: message.id,
      });
      shouldReleaseReservation = false;

      await this.chatModelRepository.updateReadCursor({
        conversationId: dto.conversationId,
        userId: senderUserId,
        lastReadSequence: message.sequence,
      });

      const messageView = await this.messageReaderService.buildMessageView(
        message.id,
      );

      this.chatGateway.emitMessageCreated(messageView);
      await this.notificationsService.dispatchOfflineMessagePush({
        conversationId: dto.conversationId,
        senderUserId,
        messageId: message.id,
      });
      this.recordDeliveryMetric('accepted', dto.type);

      return {
        ack: 'accepted',
        message: messageView,
      };
    } catch (error) {
      if (shouldReleaseReservation) {
        await this.messageIdempotencyStore.release(idempotencyKey);
      }
      this.recordDeliveryMetric('failed', dto.type);

      throw error;
    }
  }

  getConversationHistory(
    requesterUserId: string,
    conversationId: string,
    query: GetConversationHistoryQueryDto,
  ): Promise<MessageHistoryPageDto> {
    return this.messageReaderService.getConversationHistory(
      requesterUserId,
      conversationId,
      query,
    );
  }

  syncConversationMessages(
    requesterUserId: string,
    conversationId: string,
    query: SyncMessagesQueryDto,
  ): Promise<MessageSyncDto> {
    return this.messageReaderService.syncConversationMessages(
      requesterUserId,
      conversationId,
      query,
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

  private recordDeliveryMetric(result: string, messageType: string): void {
    this.metricsRegistryService.incrementCounter('chat_message_delivery_total', {
      help: 'Total number of message send attempts that reached a terminal delivery result.',
      labels: {
        result,
        message_type: messageType,
      },
    });
  }
}
