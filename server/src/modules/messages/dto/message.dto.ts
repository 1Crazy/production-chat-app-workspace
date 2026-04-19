import type {
  MessageEntity,
  MessageStatus,
  MessageType,
} from '@app/infra/database/entities/message.entity';
import type { UserDiscoveryProfileDto } from '@app/modules/users/dto/user-profile.dto';

export interface MessageView {
  serverMessageId: string;
  conversationId: string;
  senderId: string;
  sender: UserDiscoveryProfileDto;
  clientMessageId: string;
  type: MessageType;
  status: MessageStatus;
  sequence: number;
  content: Record<string, unknown>;
  createdAt: string;
  updatedAt: string;
}

export interface SendMessageResponseDto {
  ack: 'accepted';
  message: MessageView;
}

export function toMessageView(
  message: MessageEntity,
  sender: UserDiscoveryProfileDto,
): MessageView {
  return {
    serverMessageId: message.id,
    conversationId: message.conversationId,
    senderId: message.senderId,
    sender,
    clientMessageId: message.clientMessageId,
    type: message.type,
    status: message.status,
    sequence: message.sequence,
    content: message.content,
    createdAt: message.createdAt.toISOString(),
    updatedAt: message.updatedAt.toISOString(),
  };
}
