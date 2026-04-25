import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import type { ConversationSummaryView } from '../dto/conversation-summary.dto';
import type {
  ConversationView,
  UpsertConversationDto,
} from '../dto/conversation.dto';
import type { CreateDirectConversationDto } from '../dto/create-direct-conversation.dto';
import type { CreateGroupConversationDto } from '../dto/create-group-conversation.dto';
import { toReadCursorView, type ReadCursorView } from '../dto/read-cursor.dto';
import type { UpdateReadCursorDto } from '../dto/update-read-cursor.dto';

import { ConversationViewService } from './conversation-view.service';

import { RateLimitService } from '@app/infra/abuse/services/rate-limit.service';
import { ChatModelRepository } from '@app/infra/database/repositories/chat-model.repository';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import { FriendshipsService } from '@app/modules/friendships/services/friendships.service';
import { ChatGateway } from '@app/modules/realtime/gateways/chat.gateway';

@Injectable()
export class ConversationsService {
  private readonly maxGroupMembers = 200;
  private readonly createGroupWindowMs = 60 * 60 * 1000;

  constructor(
    private readonly chatModelRepository: ChatModelRepository,
    private readonly authIdentityService: AuthIdentityService,
    private readonly friendshipsService: FriendshipsService,
    private readonly rateLimitService: RateLimitService,
    private readonly chatGateway: ChatGateway,
    private readonly conversationViewService: ConversationViewService,
  ) {}

  getHealth(): { module: string; status: string } {
    return {
      module: 'conversations',
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
      module: 'conversations',
      status: 'ready',
      models: ['conversation', 'conversation-member', 'read-cursor'],
      summary: await this.chatModelRepository.getSummary(),
    };
  }

  async createDirectConversation(
    requesterUserId: string,
    dto: CreateDirectConversationDto,
  ): Promise<UpsertConversationDto> {
    const targetUser = await this.resolveTargetUser(
      requesterUserId,
      dto.targetHandle,
      {
        requireFriendship: true,
      },
    );
    const existingConversation =
      await this.chatModelRepository.findDirectConversationByMemberIds([
        requesterUserId,
        targetUser.id,
      ]);

    if (existingConversation) {
      return {
        reused: true,
        conversation: await this.conversationViewService.buildConversationView(
          existingConversation.id,
        ),
      };
    }

    try {
      const conversation = await this.chatModelRepository.createConversation({
        type: 'direct',
        createdBy: requesterUserId,
        memberIds: [requesterUserId, targetUser.id],
      });
      const conversationView =
        await this.conversationViewService.buildConversationView(conversation.id);

      this.chatGateway.emitConversationCreated(conversationView);

      return {
        reused: false,
        conversation: conversationView,
      };
    } catch (error) {
      if (error instanceof Prisma.PrismaClientKnownRequestError) {
        const racedConversation =
          await this.chatModelRepository.findDirectConversationByMemberIds([
            requesterUserId,
            targetUser.id,
          ]);

        if (racedConversation) {
          return {
            reused: true,
            conversation: await this.conversationViewService.buildConversationView(
              racedConversation.id,
            ),
          };
        }
      }

      throw error;
    }
  }

  async createGroupConversation(
    requesterUserId: string,
    dto: CreateGroupConversationDto,
  ): Promise<UpsertConversationDto> {
    await this.rateLimitService.consumeOrThrow({
      scope: 'conversations.create-group',
      actorKey: requesterUserId,
      limit: 5,
      windowMs: this.createGroupWindowMs,
      message: '建群操作过于频繁，请稍后再试',
      metadata: {
        memberCount: dto.memberHandles.length,
      },
    });
    const memberHandles = Array.from(
      new Set(dto.memberHandles.map((handle) => handle.trim())),
    );

    if (memberHandles.length < 2) {
      throw new BadRequestException('群聊至少需要 2 名其他成员');
    }

    const targetUsers = await Promise.all(
      memberHandles.map((handle) => {
        return this.resolveTargetUser(requesterUserId, handle);
      }),
    );
    const memberIds = Array.from(
      new Set([requesterUserId, ...targetUsers.map((user) => user.id)]),
    );

    if (memberIds.length > this.maxGroupMembers) {
      throw new BadRequestException(`群聊成员上限为 ${this.maxGroupMembers} 人`);
    }

    const conversation = await this.chatModelRepository.createConversation({
      type: 'group',
      title: dto.title.trim(),
      createdBy: requesterUserId,
      memberIds,
    });
    const conversationView =
      await this.conversationViewService.buildConversationView(conversation.id);

    this.chatGateway.emitConversationCreated(conversationView);

    return {
      reused: false,
      conversation: conversationView,
    };
  }

  async getConversationViewOrThrow(
    conversationId: string,
    requesterUserId: string,
  ): Promise<ConversationView> {
    const conversation =
      await this.conversationViewService.getAccessibleConversationOrThrow(
        conversationId,
        requesterUserId,
      );

    return this.conversationViewService.buildConversationView(conversation.id);
  }

  listRecentConversations(
    requesterUserId: string,
  ): Promise<ConversationSummaryView[]> {
    return this.conversationViewService.listRecentConversations(requesterUserId);
  }

  async updateReadCursor(
    requesterUserId: string,
    conversationId: string,
    dto: UpdateReadCursorDto,
  ): Promise<ReadCursorView> {
    const conversation =
      await this.conversationViewService.getAccessibleConversationOrThrow(
        conversationId,
        requesterUserId,
      );
    const normalizedSequence = Math.min(
      dto.lastReadSequence,
      conversation.latestSequence,
    );
    const cursor = await this.chatModelRepository.updateReadCursor({
      conversationId,
      userId: requesterUserId,
      lastReadSequence: normalizedSequence,
    });
    const readCursorView = toReadCursorView(
      cursor,
      await this.conversationViewService.getUnreadCount(
        conversationId,
        requesterUserId,
      ),
    );

    await this.chatGateway.emitReadCursorUpdated(readCursorView);
    return readCursorView;
  }

  private async resolveTargetUser(
    requesterUserId: string,
    targetHandle: string,
    params?: {
      requireFriendship?: boolean;
    },
  ) {
    const normalizedHandle = targetHandle.trim();
    const targetUser = await this.authIdentityService.findActiveUserByHandle(
      normalizedHandle,
    );

    if (!targetUser) {
      throw new NotFoundException('目标用户不存在或已失效');
    }

    if (targetUser.id === requesterUserId) {
      throw new BadRequestException('不能和自己发起会话');
    }

    if (params?.requireFriendship) {
      await this.friendshipsService.assertDirectConversationAllowed(
        requesterUserId,
        targetUser.id,
      );
      return targetUser;
    }

    if (targetUser.discoveryMode === 'private') {
      throw new ForbiddenException('目标用户未开放联系人发现');
    }

    return targetUser;
  }
}
