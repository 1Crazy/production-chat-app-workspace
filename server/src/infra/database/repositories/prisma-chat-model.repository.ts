import { Injectable, NotFoundException } from '@nestjs/common';
import { Prisma, type Conversation, type ConversationMember, type Message, type ReadCursor } from '@prisma/client';

import type { ChatModelSummaryDto } from '../dto/chat-model-summary.dto';
import type { ConversationMemberEntity } from '../entities/conversation-member.entity';
import type { ConversationEntity, ConversationType } from '../entities/conversation.entity';
import type { MessageEntity, MessageStatus, MessageType } from '../entities/message.entity';
import type { ReadCursorEntity } from '../entities/read-cursor.entity';
import { PrismaService } from '../prisma.service';

import { ChatModelRepository } from './chat-model.repository';

@Injectable()
export class PrismaChatModelRepository extends ChatModelRepository {
  constructor(private readonly prismaService: PrismaService) {
    super();
  }

  override async getSummary(): Promise<ChatModelSummaryDto> {
    const [conversations, members, messages, readCursors] =
      await this.prismaService.$transaction([
        this.prismaService.conversation.count(),
        this.prismaService.conversationMember.count(),
        this.prismaService.message.count(),
        this.prismaService.readCursor.count(),
      ]);

    return {
      conversations,
      members,
      messages,
      readCursors,
    };
  }

  override async createConversation(params: {
    type: ConversationType;
    title?: string | null;
    createdBy: string;
    memberIds: string[];
  }): Promise<ConversationEntity> {
    const normalizedMemberIds = Array.from(
      new Set([params.createdBy, ...params.memberIds]),
    );
    const directKey =
      params.type === 'direct' && normalizedMemberIds.length === 2
        ? [...normalizedMemberIds].sort().join(':')
        : null;

    const conversation = await this.prismaService.conversation.create({
      data: {
        type: params.type,
        title: params.title ?? null,
        createdBy: params.createdBy,
        directKey,
        members: {
          createMany: {
            data: normalizedMemberIds.map((userId) => {
              return {
                userId,
                role:
                  params.type === 'group' && userId === params.createdBy
                    ? 'owner'
                    : 'member',
              };
            }),
          },
        },
      },
    });

    return this.toConversationEntity(conversation);
  }

  override async findDirectConversationByMemberIds(
    memberIds: string[],
  ): Promise<ConversationEntity | null> {
    const directKey = Array.from(new Set(memberIds)).sort().join(':');
    const conversation = await this.prismaService.conversation.findUnique({
      where: {
        directKey,
      },
    });

    return conversation ? this.toConversationEntity(conversation) : null;
  }

  override async getConversationOrThrow(
    conversationId: string,
  ): Promise<ConversationEntity> {
    const conversation = await this.prismaService.conversation.findUnique({
      where: {
        id: conversationId,
      },
    });

    if (!conversation) {
      throw new NotFoundException('会话不存在');
    }

    return this.toConversationEntity(conversation);
  }

  override async listConversations(): Promise<ConversationEntity[]> {
    const conversations = await this.prismaService.conversation.findMany();

    return conversations.map((conversation) => {
      return this.toConversationEntity(conversation);
    });
  }

  override async listConversationMembers(
    conversationId: string,
  ): Promise<ConversationMemberEntity[]> {
    const members = await this.prismaService.conversationMember.findMany({
      where: {
        conversationId,
      },
      orderBy: {
        joinedAt: 'asc',
      },
    });

    return members.map((member) => {
      return this.toConversationMemberEntity(member);
    });
  }

  override async listConversationIdsForUser(userId: string): Promise<string[]> {
    const memberships = await this.prismaService.conversationMember.findMany({
      where: {
        userId,
      },
      select: {
        conversationId: true,
      },
    });

    return memberships.map((membership) => membership.conversationId);
  }

  override async listConversationMemberUserIds(
    conversationId: string,
  ): Promise<string[]> {
    const members = await this.prismaService.conversationMember.findMany({
      where: {
        conversationId,
      },
      orderBy: {
        joinedAt: 'asc',
      },
      select: {
        userId: true,
      },
    });

    return members.map((member) => member.userId);
  }

  override async isConversationMember(
    conversationId: string,
    userId: string,
  ): Promise<boolean> {
    const member = await this.prismaService.conversationMember.findUnique({
      where: {
        conversationId_userId: {
          conversationId,
          userId,
        },
      },
      select: {
        id: true,
      },
    });

    return member != null;
  }

  override async createMessage(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
    type: MessageType;
    status?: MessageStatus;
    content: Record<string, unknown>;
  }): Promise<MessageEntity> {
    const now = new Date();
    try {
      const message = await this.prismaService.$transaction(async (tx) => {
        const conversation = await tx.conversation.update({
          where: {
            id: params.conversationId,
          },
          data: {
            latestSequence: {
              increment: 1,
            },
            updatedAt: now,
          },
        });

        return tx.message.create({
          data: {
            conversationId: params.conversationId,
            senderId: params.senderId,
            clientMessageId: params.clientMessageId,
            type: params.type,
            status: params.status ?? 'sent',
            sequence: conversation.latestSequence,
            content: params.content as Prisma.InputJsonObject,
            createdAt: now,
            updatedAt: now,
          },
        });
      });

      return this.toMessageEntity(message);
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError) {
        const existingMessage = await this.findMessageByClientKey({
          conversationId: params.conversationId,
          senderId: params.senderId,
          clientMessageId: params.clientMessageId,
        });

        if (existingMessage) {
          return existingMessage;
        }
      }

      throw error;
    }
  }

  override async findMessageByClientKey(params: {
    conversationId: string;
    senderId: string;
    clientMessageId: string;
  }): Promise<MessageEntity | null> {
    const message = await this.prismaService.message.findUnique({
      where: {
        conversationId_senderId_clientMessageId: {
          conversationId: params.conversationId,
          senderId: params.senderId,
          clientMessageId: params.clientMessageId,
        },
      },
    });

    return message ? this.toMessageEntity(message) : null;
  }

  override async listMessages(conversationId: string): Promise<MessageEntity[]> {
    const messages = await this.prismaService.message.findMany({
      where: {
        conversationId,
      },
      orderBy: {
        sequence: 'asc',
      },
    });

    return messages.map((message) => this.toMessageEntity(message));
  }

  override async findLatestMessage(
    conversationId: string,
  ): Promise<MessageEntity | null> {
    const message = await this.prismaService.message.findFirst({
      where: {
        conversationId,
      },
      orderBy: {
        sequence: 'desc',
      },
    });

    return message ? this.toMessageEntity(message) : null;
  }

  override async listMessagesAfterSequence(
    conversationId: string,
    sequence: number,
  ): Promise<MessageEntity[]> {
    const messages = await this.prismaService.message.findMany({
      where: {
        conversationId,
        sequence: {
          gt: sequence,
        },
      },
      orderBy: {
        sequence: 'asc',
      },
    });

    return messages.map((message) => this.toMessageEntity(message));
  }

  override async getMessageOrThrow(messageId: string): Promise<MessageEntity> {
    const message = await this.prismaService.message.findUnique({
      where: {
        id: messageId,
      },
    });

    if (!message) {
      throw new NotFoundException('消息不存在');
    }

    return this.toMessageEntity(message);
  }

  override async updateReadCursor(params: {
    conversationId: string;
    userId: string;
    lastReadSequence: number;
  }): Promise<ReadCursorEntity> {
    const existingCursor = await this.prismaService.readCursor.findUnique({
      where: {
        conversationId_userId: {
          conversationId: params.conversationId,
          userId: params.userId,
        },
      },
    });
    const nextLastReadSequence = Math.max(
      existingCursor?.lastReadSequence ?? 0,
      params.lastReadSequence,
    );
    const cursor = await this.prismaService.readCursor.upsert({
      where: {
        conversationId_userId: {
          conversationId: params.conversationId,
          userId: params.userId,
        },
      },
      update: {
        lastReadSequence: nextLastReadSequence,
        updatedAt: new Date(),
      },
      create: {
        conversationId: params.conversationId,
        userId: params.userId,
        lastReadSequence: nextLastReadSequence,
      },
    });

    return this.toReadCursorEntity(cursor);
  }

  override async findReadCursor(
    conversationId: string,
    userId: string,
  ): Promise<ReadCursorEntity | null> {
    const cursor = await this.prismaService.readCursor.findUnique({
      where: {
        conversationId_userId: {
          conversationId,
          userId,
        },
      },
    });

    return cursor ? this.toReadCursorEntity(cursor) : null;
  }

  override async listReadCursorsForConversation(
    conversationId: string,
  ): Promise<ReadCursorEntity[]> {
    const cursors = await this.prismaService.readCursor.findMany({
      where: {
        conversationId,
      },
      orderBy: {
        updatedAt: 'desc',
      },
    });

    return cursors.map((cursor) => this.toReadCursorEntity(cursor));
  }

  private toConversationEntity(conversation: Conversation): ConversationEntity {
    return {
      id: conversation.id,
      type: conversation.type as ConversationEntity['type'],
      title: conversation.title,
      createdBy: conversation.createdBy,
      directKey: conversation.directKey,
      latestSequence: conversation.latestSequence,
      createdAt: conversation.createdAt,
      updatedAt: conversation.updatedAt,
    };
  }

  private toConversationMemberEntity(
    member: ConversationMember,
  ): ConversationMemberEntity {
    return {
      id: member.id,
      conversationId: member.conversationId,
      userId: member.userId,
      role: member.role as ConversationMemberEntity['role'],
      joinedAt: member.joinedAt,
    };
  }

  private toMessageEntity(message: Message): MessageEntity {
    return {
      id: message.id,
      conversationId: message.conversationId,
      senderId: message.senderId,
      clientMessageId: message.clientMessageId,
      type: message.type as MessageEntity['type'],
      status: message.status as MessageEntity['status'],
      sequence: message.sequence,
      content: this.toMessageContent(message.content),
      createdAt: message.createdAt,
      updatedAt: message.updatedAt,
    };
  }

  private toReadCursorEntity(cursor: ReadCursor): ReadCursorEntity {
    return {
      id: cursor.id,
      conversationId: cursor.conversationId,
      userId: cursor.userId,
      lastReadSequence: cursor.lastReadSequence,
      updatedAt: cursor.updatedAt,
    };
  }

  private toMessageContent(value: Prisma.JsonValue): Record<string, unknown> {
    if (value && typeof value === 'object' && !Array.isArray(value)) {
      return value as Record<string, unknown>;
    }

    return {};
  }
}
