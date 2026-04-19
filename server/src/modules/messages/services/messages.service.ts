import {
  BadRequestException,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';

import { type SendMessageResponseDto, toMessageView } from '../dto/message.dto';
import type { SendMessageDto } from '../dto/send-message.dto';

import { InMemoryChatModelRepository } from '@app/infra/database/repositories/in-memory-chat-model.repository';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import { toUserDiscoveryProfileDto } from '@app/modules/users/dto/user-profile.dto';

@Injectable()
export class MessagesService {
  constructor(
    private readonly chatModelRepository: InMemoryChatModelRepository,
    private readonly authIdentityService: AuthIdentityService,
  ) {}

  getHealth(): { module: string; status: string } {
    return {
      module: 'messages',
      status: 'ready',
    };
  }

  getModelSummary(): {
    module: string;
    status: string;
    models: string[];
    summary: ReturnType<InMemoryChatModelRepository['getSummary']>;
  } {
    return {
      module: 'messages',
      status: 'ready',
      models: ['message', 'message-sequence', 'message-idempotency'],
      summary: this.chatModelRepository.getSummary(),
    };
  }

  sendMessage(
    senderUserId: string,
    dto: SendMessageDto,
  ): SendMessageResponseDto {
    this.authIdentityService.getActiveUserById(senderUserId);
    this.chatModelRepository.getConversationOrThrow(dto.conversationId);

    if (!this.chatModelRepository.isConversationMember(dto.conversationId, senderUserId)) {
      throw new ForbiddenException('你不是该会话成员');
    }

    const message = this.chatModelRepository.createMessage({
      conversationId: dto.conversationId,
      senderId: senderUserId,
      clientMessageId: dto.clientMessageId.trim(),
      type: dto.type,
      content: this.buildMessageContent(dto),
    });

    // 发送者自己的最新消息默认视为已读，这样后续未读计数不会把自己消息算进去。
    this.chatModelRepository.updateReadCursor({
      conversationId: dto.conversationId,
      userId: senderUserId,
      lastReadSequence: message.sequence,
    });

    return {
      ack: 'accepted',
      message: toMessageView(
        message,
        toUserDiscoveryProfileDto(
          this.authIdentityService.getActiveUserById(senderUserId),
        ),
      ),
    };
  }

  private buildMessageContent(dto: SendMessageDto): Record<string, unknown> {
    if (dto.type === 'text') {
      const normalizedText = dto.text?.trim();

      if (!normalizedText) {
        throw new BadRequestException('文本消息不能为空');
      }

      return {
        text: normalizedText,
      };
    }

    if (!dto.payload) {
      throw new BadRequestException('非文本消息必须携带 payload');
    }

    return dto.payload;
  }
}
