import { NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import type { Message, ReadCursor } from '@prisma/client';

import type { MessageEntity, MessageStatus, MessageType } from '../entities/message.entity';
import type { ReadCursorEntity } from '../entities/read-cursor.entity';
import type { PrismaService } from '../prisma.service';

export class PrismaMessageModelRepository {
  constructor(private readonly prismaService: PrismaService) {}

  async createMessage(params: {
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

  async findMessageByClientKey(params: {
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

  async listMessages(conversationId: string): Promise<MessageEntity[]> {
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

  async findLatestMessage(
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

  async listMessagesAfterSequence(
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

  async getMessageOrThrow(messageId: string): Promise<MessageEntity> {
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

  async updateReadCursor(params: {
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

  async findReadCursor(
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

  async listReadCursorsForConversation(
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
