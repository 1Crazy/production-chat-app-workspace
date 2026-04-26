import { randomUUID } from 'node:crypto';

import { Injectable, NotFoundException } from '@nestjs/common';

import type { ChatModelSummaryDto } from '../dto/chat-model-summary.dto';
import type {
  ConversationMemberEntity,
  ConversationMemberRole,
} from '../entities/conversation-member.entity';
import type {
  ConversationEntity,
  ConversationType,
} from '../entities/conversation.entity';
import type { MessageEntity, MessageStatus, MessageType } from '../entities/message.entity';
import type { ReadCursorEntity } from '../entities/read-cursor.entity';

import { ChatModelRepository } from './chat-model.repository';

@Injectable()
export class InMemoryChatModelRepository extends ChatModelRepository {
  private readonly conversationsById = new Map<string, ConversationEntity>();
  private readonly conversationIdsByDirectKey = new Map<string, string>();
  private readonly membersById = new Map<string, ConversationMemberEntity>();
  private readonly memberIdsByConversation = new Map<string, Set<string>>();
  private readonly messagesById = new Map<string, MessageEntity>();
  private readonly messageIdsByConversation = new Map<string, string[]>();
  private readonly messageIdsByClientKey = new Map<string, string>();
  private readonly readCursorsByKey = new Map<string, ReadCursorEntity>();

  override async getSummary(): Promise<ChatModelSummaryDto> {
    return {
      conversations: this.conversationsById.size,
      members: this.membersById.size,
      messages: this.messagesById.size,
      readCursors: this.readCursorsByKey.size,
    };
  }

  override async createConversation(params: {
    type: ConversationType;
    title?: string | null;
    createdBy: string;
    memberIds: string[];
  }): Promise<ConversationEntity> {
    const now = new Date();
    const normalizedMemberIds = Array.from(
      new Set([params.createdBy, ...params.memberIds]),
    );
    const directKey =
      params.type === 'direct' && normalizedMemberIds.length === 2
        ? [...normalizedMemberIds].sort().join(':')
        : null;

    const conversation: ConversationEntity = {
      id: randomUUID(),
      type: params.type,
      title: params.title ?? null,
      createdBy: params.createdBy,
      directKey,
      latestSequence: 0,
      createdAt: now,
      updatedAt: now,
    };

    this.conversationsById.set(conversation.id, conversation);
    this.memberIdsByConversation.set(conversation.id, new Set());

    if (directKey) {
      this.conversationIdsByDirectKey.set(directKey, conversation.id);
    }

    normalizedMemberIds.forEach((userId) => {
      this.addMember({
        conversationId: conversation.id,
        userId,
        role:
          params.type === 'group' && userId === params.createdBy
            ? 'owner'
            : 'member',
      });
    });

    return conversation;
  }

  override async findDirectConversationByMemberIds(
    memberIds: string[],
  ): Promise<ConversationEntity | null> {
    const directKey = Array.from(new Set(memberIds)).sort().join(':');
    const conversationId = this.conversationIdsByDirectKey.get(directKey);

    if (!conversationId) {
      return null;
    }

    return this.conversationsById.get(conversationId) ?? null;
  }

  override async getConversationOrThrow(
    conversationId: string,
  ): Promise<ConversationEntity> {
    const conversation = this.conversationsById.get(conversationId);

    if (!conversation) {
      throw new NotFoundException('会话不存在');
    }

    return conversation;
  }

  override async listConversations(): Promise<ConversationEntity[]> {
    return Array.from(this.conversationsById.values());
  }

  override async listConversationMembers(
    conversationId: string,
  ): Promise<ConversationMemberEntity[]> {
    const memberIds = this.memberIdsByConversation.get(conversationId);

    if (!memberIds) {
      return [];
    }

    return Array.from(memberIds)
      .map((memberId) => this.membersById.get(memberId))
      .filter((member): member is ConversationMemberEntity => member != null);
  }

  override async listConversationIdsForUser(userId: string): Promise<string[]> {
    const conversationIds = Array.from(this.conversationsById.keys());

    return conversationIds.filter((conversationId) => {
      return this.listConversationMembersSync(conversationId).some((member) => {
        return member.userId === userId;
      });
    });
  }

  override async listConversationMemberUserIds(
    conversationId: string,
  ): Promise<string[]> {
    return this.listConversationMembersSync(conversationId).map((member) => {
      return member.userId;
    });
  }

  private addMember(params: {
    conversationId: string;
    userId: string;
    role: ConversationMemberRole;
  }): ConversationMemberEntity {
    const member: ConversationMemberEntity = {
      id: randomUUID(),
      conversationId: params.conversationId,
      userId: params.userId,
      role: params.role,
      joinedAt: new Date(),
    };

    this.membersById.set(member.id, member);
    const memberIds = this.memberIdsByConversation.get(params.conversationId) ?? new Set();
    memberIds.add(member.id);
    this.memberIdsByConversation.set(params.conversationId, memberIds);
    return member;
  }

  override async isConversationMember(
    conversationId: string,
    userId: string,
  ): Promise<boolean> {
    return this.listConversationMembersSync(conversationId).some((member) => {
      return member.userId === userId;
    });
  }

  override async createMessage(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
    type: MessageType;
    status?: MessageStatus;
    content: Record<string, unknown>;
    failureReason?: string | null;
  }): Promise<MessageEntity> {
    const conversation = this.getConversationOrThrowSync(params.conversationId);
    const nextSequence = conversation.latestSequence + 1;
    const now = new Date();
    const message: MessageEntity = {
      id: randomUUID(),
      conversationId: params.conversationId,
      senderId: params.senderId,
      clientMessageId: params.clientMessageId,
      type: params.type,
      status: params.status ?? 'sent',
      sequence: nextSequence,
      content: params.content,
      failureReason: params.failureReason ?? null,
      createdAt: now,
      updatedAt: now,
    };

    conversation.latestSequence = nextSequence;
    conversation.updatedAt = now;
    this.conversationsById.set(conversation.id, conversation);
    this.messagesById.set(message.id, message);
    this.messageIdsByClientKey.set(
      this.buildClientMessageKey(
        params.conversationId,
        params.senderId,
        params.clientMessageId,
      ),
      message.id,
    );

    const messageIds = this.messageIdsByConversation.get(params.conversationId) ?? [];
    messageIds.push(message.id);
    this.messageIdsByConversation.set(params.conversationId, messageIds);
    return message;
  }

  override async listMessages(conversationId: string): Promise<MessageEntity[]> {
    const messageIds = this.messageIdsByConversation.get(conversationId) ?? [];
    return messageIds
      .map((messageId) => this.messagesById.get(messageId))
      .filter((message): message is MessageEntity => message != null);
  }

  override async findLatestMessage(
    conversationId: string,
  ): Promise<MessageEntity | null> {
    const messages = await this.listMessages(conversationId);
    return messages.length > 0 ? messages[messages.length - 1] ?? null : null;
  }

  override async listMessagesAfterSequence(
    conversationId: string,
    sequence: number,
  ): Promise<MessageEntity[]> {
    return (await this.listMessages(conversationId)).filter((message) => {
      return message.sequence > sequence;
    });
  }

  override async getMessageOrThrow(messageId: string): Promise<MessageEntity> {
    return this.getMessageOrThrowSync(messageId);
  }

  override async findMessageByClientKey(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
  }): Promise<MessageEntity | null> {
    const messageId = this.messageIdsByClientKey.get(
      this.buildClientMessageKey(
        params.conversationId,
        params.senderId,
        params.clientMessageId,
      ),
    );

    return messageId ? this.getMessageOrThrowSync(messageId) : null;
  }

  override async updateReadCursor(params: {
    conversationId: string;
    userId: string;
    lastReadSequence: number;
  }): Promise<ReadCursorEntity> {
    const key = this.buildReadCursorKey(params.conversationId, params.userId);
    const existingCursor = this.readCursorsByKey.get(key);
    const cursor: ReadCursorEntity = {
      id: existingCursor?.id ?? randomUUID(),
      conversationId: params.conversationId,
      userId: params.userId,
      lastReadSequence: Math.max(
        existingCursor?.lastReadSequence ?? 0,
        params.lastReadSequence,
      ),
      updatedAt: new Date(),
    };

    this.readCursorsByKey.set(key, cursor);
    return cursor;
  }

  override async findReadCursor(
    conversationId: string,
    userId: string,
  ): Promise<ReadCursorEntity | null> {
    return this.readCursorsByKey.get(
      this.buildReadCursorKey(conversationId, userId),
    ) ?? null;
  }

  override async listReadCursorsForConversation(
    conversationId: string,
  ): Promise<ReadCursorEntity[]> {
    return Array.from(this.readCursorsByKey.values()).filter((cursor) => {
      return cursor.conversationId === conversationId;
    });
  }

  private getMessageOrThrowSync(messageId: string): MessageEntity {
    const message = this.messagesById.get(messageId);

    if (!message) {
      throw new NotFoundException('消息不存在');
    }

    return message;
  }

  private getConversationOrThrowSync(conversationId: string): ConversationEntity {
    const conversation = this.conversationsById.get(conversationId);

    if (!conversation) {
      throw new NotFoundException('会话不存在');
    }

    return conversation;
  }

  private listConversationMembersSync(
    conversationId: string,
  ): ConversationMemberEntity[] {
    const memberIds = this.memberIdsByConversation.get(conversationId);

    if (!memberIds) {
      return [];
    }

    return Array.from(memberIds)
      .map((memberId) => this.membersById.get(memberId))
      .filter((member): member is ConversationMemberEntity => member != null);
  }

  private buildClientMessageKey(
    conversationId: string,
    senderId: string,
    clientMessageId: string,
  ): string {
    return `${conversationId}:${senderId}:${clientMessageId}`;
  }

  private buildReadCursorKey(conversationId: string, userId: string): string {
    return `${conversationId}:${userId}`;
  }
}
