import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '@prisma/client';

import {
  type ConversationSummaryView,
  toConversationSummaryView,
} from '../dto/conversation-summary.dto';
import {
  type ConversationView,
  type UpsertConversationDto,
  toConversationView,
} from '../dto/conversation.dto';
import type { CreateDirectConversationDto } from '../dto/create-direct-conversation.dto';
import type { CreateGroupConversationDto } from '../dto/create-group-conversation.dto';
import { toReadCursorView, type ReadCursorView } from '../dto/read-cursor.dto';
import type { UpdateReadCursorDto } from '../dto/update-read-cursor.dto';

import type { MessageEntity } from '@app/infra/database/entities/message.entity';
import { ChatModelRepository } from '@app/infra/database/repositories/chat-model.repository';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import { ChatGateway } from '@app/modules/realtime/gateways/chat.gateway';
import { toUserDiscoveryProfileDto } from '@app/modules/users/dto/user-profile.dto';

@Injectable()
export class ConversationsService {
  private readonly maxGroupMembers = 200;

  constructor(
    private readonly chatModelRepository: ChatModelRepository,
    private readonly authIdentityService: AuthIdentityService,
    private readonly chatGateway: ChatGateway,
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
    );
    const existingConversation =
      await this.chatModelRepository.findDirectConversationByMemberIds([
        requesterUserId,
        targetUser.id,
      ]);

    if (existingConversation) {
      return {
        reused: true,
        conversation: await this.buildConversationView(existingConversation.id),
      };
    }

    try {
      const conversation = await this.chatModelRepository.createConversation({
        type: 'direct',
        createdBy: requesterUserId,
        memberIds: [requesterUserId, targetUser.id],
      });
      const conversationView = await this.buildConversationView(conversation.id);

      // 新会话建立后立即推送给成员，后续客户端重连时再通过 connection.ready 做房间恢复。
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
            conversation: await this.buildConversationView(racedConversation.id),
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
    const conversationView = await this.buildConversationView(conversation.id);

    // 群聊创建事件需要直接推给初始成员，避免成员必须手动刷新才能看到新群。
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
    const conversation = await this.getAccessibleConversationOrThrow(
      conversationId,
      requesterUserId,
    );

    return this.buildConversationView(conversation.id);
  }

  async listRecentConversations(
    requesterUserId: string,
  ): Promise<ConversationSummaryView[]> {
    await this.authIdentityService.getActiveUserById(requesterUserId);

    const conversationIdSet = new Set(
      await this.chatModelRepository.listConversationIdsForUser(requesterUserId),
    );
    const conversations = (await this.chatModelRepository.listConversations())
      .filter((conversation) => conversationIdSet.has(conversation.id))
      .sort((left, right) => {
        return right.updatedAt.getTime() - left.updatedAt.getTime();
      });

    return Promise.all(
      conversations.map((conversation) => {
        return this.buildConversationSummaryView(conversation.id, requesterUserId);
      }),
    );
  }

  async updateReadCursor(
    requesterUserId: string,
    conversationId: string,
    dto: UpdateReadCursorDto,
  ): Promise<ReadCursorView> {
    const conversation = await this.getAccessibleConversationOrThrow(
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
      await this.getUnreadCount(conversationId, requesterUserId),
    );

    // 已读游标的变更需要实时同步给会话其他成员和当前用户其他设备。
    await this.chatGateway.emitReadCursorUpdated(readCursorView);
    return readCursorView;
  }

  private async buildConversationView(
    conversationId: string,
  ): Promise<ConversationView> {
    const conversation =
      await this.chatModelRepository.getConversationOrThrow(conversationId);
    const members = await Promise.all(
      (await this.chatModelRepository.listConversationMembers(conversationId)).map(
        async (member) => {
          const user = await this.authIdentityService.getActiveUserById(
            member.userId,
          );

          return {
            member,
            profile: toUserDiscoveryProfileDto(user),
          };
        },
      ),
    );

    return toConversationView({
      conversation,
      members,
    });
  }

  private async buildConversationSummaryView(
    conversationId: string,
    requesterUserId: string,
  ): Promise<ConversationSummaryView> {
    const conversation =
      await this.chatModelRepository.getConversationOrThrow(conversationId);
    const latestMessage =
      await this.chatModelRepository.findLatestMessage(conversationId);

    return toConversationSummaryView({
      id: conversation.id,
      type: conversation.type,
      title: await this.resolveConversationTitle(conversation.id, requesterUserId),
      memberCount: (
        await this.chatModelRepository.listConversationMemberUserIds(
          conversation.id,
        )
      ).length,
      latestSequence: conversation.latestSequence,
      lastMessagePreview: this.buildLastMessagePreview(latestMessage),
      lastMessageAt: latestMessage?.createdAt ?? null,
      unreadCount: await this.getUnreadCount(conversation.id, requesterUserId),
      updatedAt: conversation.updatedAt,
    });
  }

  private async getAccessibleConversationOrThrow(
    conversationId: string,
    requesterUserId: string,
  ) {
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

  private async resolveConversationTitle(
    conversationId: string,
    requesterUserId: string,
  ): Promise<string> {
    const conversation =
      await this.chatModelRepository.getConversationOrThrow(conversationId);

    if (conversation.type === 'group') {
      return conversation.title ?? '未命名群聊';
    }

    const peer = (
      await this.chatModelRepository.listConversationMembers(conversationId)
    ).find((member) => member.userId !== requesterUserId);

    if (!peer) {
      return '和自己';
    }

    return (await this.authIdentityService.getActiveUserById(peer.userId))
      .nickname;
  }

  private buildLastMessagePreview(message: MessageEntity | null): string {
    if (!message) {
      return '还没有消息';
    }

    if (message.type === 'text') {
      return String(message.content.text ?? '');
    }

    if (message.type === 'image') {
      return '[图片]';
    }

    if (message.type === 'audio') {
      return '[语音]';
    }

    if (message.type === 'file') {
      return '[文件]';
    }

    return '[系统消息]';
  }

  private async getUnreadCount(
    conversationId: string,
    requesterUserId: string,
  ): Promise<number> {
    const conversation =
      await this.chatModelRepository.getConversationOrThrow(conversationId);
    const cursor = await this.chatModelRepository.findReadCursor(
      conversationId,
      requesterUserId,
    );

    return Math.max(conversation.latestSequence - (cursor?.lastReadSequence ?? 0), 0);
  }

  private async resolveTargetUser(
    requesterUserId: string,
    targetHandle: string,
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

    // 当前还没有好友/邀请体系，首期直接复用联系人发现规则控制可建聊对象。
    if (targetUser.discoveryMode === 'private') {
      throw new ForbiddenException('目标用户未开放联系人发现');
    }

    return targetUser;
  }
}
