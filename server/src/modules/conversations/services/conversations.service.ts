import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import {
  type ConversationView,
  type UpsertConversationDto,
  toConversationView,
} from '../dto/conversation.dto';
import type { CreateDirectConversationDto } from '../dto/create-direct-conversation.dto';
import type { CreateGroupConversationDto } from '../dto/create-group-conversation.dto';

import { InMemoryChatModelRepository } from '@app/infra/database/repositories/in-memory-chat-model.repository';
import { AuthIdentityService } from '@app/modules/auth/services/auth-identity.service';
import { toUserDiscoveryProfileDto } from '@app/modules/users/dto/user-profile.dto';

@Injectable()
export class ConversationsService {
  private readonly maxGroupMembers = 200;

  constructor(
    private readonly chatModelRepository: InMemoryChatModelRepository,
    private readonly authIdentityService: AuthIdentityService,
  ) {}

  getHealth(): { module: string; status: string } {
    return {
      module: 'conversations',
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
      module: 'conversations',
      status: 'ready',
      models: ['conversation', 'conversation-member', 'read-cursor'],
      summary: this.chatModelRepository.getSummary(),
    };
  }

  createDirectConversation(
    requesterUserId: string,
    dto: CreateDirectConversationDto,
  ): UpsertConversationDto {
    const targetUser = this.resolveTargetUser(requesterUserId, dto.targetHandle);
    const existingConversation =
      this.chatModelRepository.findDirectConversationByMemberIds([
        requesterUserId,
        targetUser.id,
      ]);

    if (existingConversation) {
      return {
        reused: true,
        conversation: this.buildConversationView(existingConversation.id),
      };
    }

    const conversation = this.chatModelRepository.createConversation({
      type: 'direct',
      createdBy: requesterUserId,
      memberIds: [requesterUserId, targetUser.id],
    });

    return {
      reused: false,
      conversation: this.buildConversationView(conversation.id),
    };
  }

  createGroupConversation(
    requesterUserId: string,
    dto: CreateGroupConversationDto,
  ): UpsertConversationDto {
    const memberHandles = Array.from(
      new Set(dto.memberHandles.map((handle) => handle.trim())),
    );

    if (memberHandles.length < 2) {
      throw new BadRequestException('群聊至少需要 2 名其他成员');
    }

    const targetUsers = memberHandles.map((handle) => {
      return this.resolveTargetUser(requesterUserId, handle);
    });
    const memberIds = Array.from(
      new Set([requesterUserId, ...targetUsers.map((user) => user.id)]),
    );

    if (memberIds.length > this.maxGroupMembers) {
      throw new BadRequestException(`群聊成员上限为 ${this.maxGroupMembers} 人`);
    }

    const conversation = this.chatModelRepository.createConversation({
      type: 'group',
      title: dto.title.trim(),
      createdBy: requesterUserId,
      memberIds,
    });

    return {
      reused: false,
      conversation: this.buildConversationView(conversation.id),
    };
  }

  getConversationViewOrThrow(
    conversationId: string,
    requesterUserId: string,
  ): ConversationView {
    const conversation = this.chatModelRepository.getConversationOrThrow(
      conversationId,
    );

    if (!this.chatModelRepository.isConversationMember(conversationId, requesterUserId)) {
      throw new ForbiddenException('你不是该会话成员');
    }

    return this.buildConversationView(conversation.id);
  }

  private buildConversationView(conversationId: string): ConversationView {
    const conversation =
      this.chatModelRepository.getConversationOrThrow(conversationId);
    const members = this.chatModelRepository
      .listConversationMembers(conversationId)
      .map((member) => {
        const user = this.authIdentityService.getActiveUserById(member.userId);

        return {
          member,
          profile: toUserDiscoveryProfileDto(user),
        };
      });

    return toConversationView({
      conversation,
      members,
    });
  }

  private resolveTargetUser(requesterUserId: string, targetHandle: string) {
    const normalizedHandle = targetHandle.trim();
    const targetUser =
      this.authIdentityService.findActiveUserByHandle(normalizedHandle);

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
