import type { ChatModelSummaryDto } from '../dto/chat-model-summary.dto';
import type {
  ConversationMemberEntity,
} from '../entities/conversation-member.entity';
import type {
  ConversationEntity,
  ConversationType,
} from '../entities/conversation.entity';
import type {
  MessageEntity,
  MessageStatus,
  MessageType,
} from '../entities/message.entity';
import type { ReadCursorEntity } from '../entities/read-cursor.entity';

export abstract class ChatModelRepository {
  abstract getSummary(): Promise<ChatModelSummaryDto>;

  abstract createConversation(params: {
    type: ConversationType;
    title?: string | null;
    createdBy: string;
    memberIds: string[];
  }): Promise<ConversationEntity>;

  abstract findDirectConversationByMemberIds(
    memberIds: string[],
  ): Promise<ConversationEntity | null>;

  abstract getConversationOrThrow(
    conversationId: string,
  ): Promise<ConversationEntity>;

  abstract listConversations(): Promise<ConversationEntity[]>;

  abstract listConversationMembers(
    conversationId: string,
  ): Promise<ConversationMemberEntity[]>;

  abstract listConversationIdsForUser(userId: string): Promise<string[]>;

  abstract listConversationMemberUserIds(
    conversationId: string,
  ): Promise<string[]>;

  abstract isConversationMember(
    conversationId: string,
    userId: string,
  ): Promise<boolean>;

  abstract createMessage(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
    type: MessageType;
    status?: MessageStatus;
    content: Record<string, unknown>;
    failureReason?: string | null;
  }): Promise<MessageEntity>;

  abstract findMessageByClientKey(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
  }): Promise<MessageEntity | null>;

  abstract listMessages(conversationId: string): Promise<MessageEntity[]>;

  abstract findLatestMessage(
    conversationId: string,
  ): Promise<MessageEntity | null>;

  abstract listMessagesAfterSequence(
    conversationId: string,
    sequence: number,
  ): Promise<MessageEntity[]>;

  abstract getMessageOrThrow(messageId: string): Promise<MessageEntity>;

  abstract updateReadCursor(params: {
    conversationId: string;
    userId: string;
    lastReadSequence: number;
  }): Promise<ReadCursorEntity>;

  abstract findReadCursor(
    conversationId: string,
    userId: string,
  ): Promise<ReadCursorEntity | null>;

  abstract listReadCursorsForConversation(
    conversationId: string,
  ): Promise<ReadCursorEntity[]>;
}
