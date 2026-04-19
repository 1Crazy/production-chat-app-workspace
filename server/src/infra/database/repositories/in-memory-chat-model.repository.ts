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

@Injectable()
export class InMemoryChatModelRepository {
  private readonly conversationsById = new Map<string, ConversationEntity>();
  private readonly conversationIdsByDirectKey = new Map<string, string>();
  private readonly membersById = new Map<string, ConversationMemberEntity>();
  private readonly memberIdsByConversation = new Map<string, Set<string>>();
  private readonly messagesById = new Map<string, MessageEntity>();
  private readonly messageIdsByConversation = new Map<string, string[]>();
  private readonly messageIdsByClientKey = new Map<string, string>();
  private readonly readCursorsByKey = new Map<string, ReadCursorEntity>();

  getSummary(): ChatModelSummaryDto {
    return {
      conversations: this.conversationsById.size,
      members: this.membersById.size,
      messages: this.messagesById.size,
      readCursors: this.readCursorsByKey.size,
    };
  }

  createConversation(params: {
    type: ConversationType;
    title?: string | null;
    createdBy: string;
    memberIds: string[];
  }): ConversationEntity {
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

  findDirectConversationByMemberIds(memberIds: string[]): ConversationEntity | null {
    const directKey = Array.from(new Set(memberIds)).sort().join(':');
    const conversationId = this.conversationIdsByDirectKey.get(directKey);

    if (!conversationId) {
      return null;
    }

    return this.conversationsById.get(conversationId) ?? null;
  }

  getConversationOrThrow(conversationId: string): ConversationEntity {
    const conversation = this.conversationsById.get(conversationId);

    if (!conversation) {
      throw new NotFoundException('会话不存在');
    }

    return conversation;
  }

  listConversationMembers(conversationId: string): ConversationMemberEntity[] {
    const memberIds = this.memberIdsByConversation.get(conversationId);

    if (!memberIds) {
      return [];
    }

    return Array.from(memberIds)
      .map((memberId) => this.membersById.get(memberId))
      .filter((member): member is ConversationMemberEntity => member != null);
  }

  addMember(params: {
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

  isConversationMember(conversationId: string, userId: string): boolean {
    return this.listConversationMembers(conversationId).some((member) => {
      return member.userId === userId;
    });
  }

  createMessage(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
    type: MessageType;
    status?: MessageStatus;
    content: Record<string, unknown>;
  }): MessageEntity {
    // 幂等键同时绑定发送人和会话，避免不同成员误用同一个 clientMessageId 时互相冲突。
    const clientKey = this.buildClientMessageKey(
      params.conversationId,
      params.senderId,
      params.clientMessageId,
    );
    const existingMessageId = this.messageIdsByClientKey.get(clientKey);

    if (existingMessageId) {
      return this.getMessageOrThrow(existingMessageId);
    }

    const conversation = this.getConversationOrThrow(params.conversationId);
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
      createdAt: now,
      updatedAt: now,
    };

    conversation.latestSequence = nextSequence;
    conversation.updatedAt = now;
    this.conversationsById.set(conversation.id, conversation);
    this.messagesById.set(message.id, message);
    this.messageIdsByClientKey.set(clientKey, message.id);

    const messageIds = this.messageIdsByConversation.get(params.conversationId) ?? [];
    messageIds.push(message.id);
    this.messageIdsByConversation.set(params.conversationId, messageIds);
    return message;
  }

  listMessages(conversationId: string): MessageEntity[] {
    const messageIds = this.messageIdsByConversation.get(conversationId) ?? [];
    return messageIds
      .map((messageId) => this.messagesById.get(messageId))
      .filter((message): message is MessageEntity => message != null);
  }

  listMessagesAfterSequence(
    conversationId: string,
    sequence: number,
  ): MessageEntity[] {
    return this.listMessages(conversationId).filter((message) => {
      return message.sequence > sequence;
    });
  }

  getMessageOrThrow(messageId: string): MessageEntity {
    const message = this.messagesById.get(messageId);

    if (!message) {
      throw new NotFoundException('消息不存在');
    }

    return message;
  }

  updateReadCursor(params: {
    conversationId: string;
    userId: string;
    lastReadSequence: number;
  }): ReadCursorEntity {
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

  findReadCursor(
    conversationId: string,
    userId: string,
  ): ReadCursorEntity | null {
    return this.readCursorsByKey.get(
      this.buildReadCursorKey(conversationId, userId),
    ) ?? null;
  }

  listReadCursorsForConversation(conversationId: string): ReadCursorEntity[] {
    return Array.from(this.readCursorsByKey.values()).filter((cursor) => {
      return cursor.conversationId === conversationId;
    });
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
