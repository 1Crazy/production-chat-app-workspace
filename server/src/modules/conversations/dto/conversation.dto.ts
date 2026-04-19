import type { ConversationMemberEntity } from '@app/infra/database/entities/conversation-member.entity';
import type {
  ConversationEntity,
  ConversationType,
} from '@app/infra/database/entities/conversation.entity';
import type { UserDiscoveryProfileDto } from '@app/modules/users/dto/user-profile.dto';

export interface ConversationMemberView {
  userId: string;
  role: ConversationMemberEntity['role'];
  joinedAt: string;
  profile: UserDiscoveryProfileDto;
}

export interface ConversationView {
  id: string;
  type: ConversationType;
  title: string | null;
  createdBy: string;
  latestSequence: number;
  members: ConversationMemberView[];
  createdAt: string;
  updatedAt: string;
}

export interface ConversationViewMember {
  member: ConversationMemberEntity;
  profile: UserDiscoveryProfileDto;
}

export interface UpsertConversationDto {
  reused: boolean;
  conversation: ConversationView;
}

export function toConversationView(params: {
  conversation: ConversationEntity;
  members: ConversationViewMember[];
}): ConversationView {
  return {
    id: params.conversation.id,
    type: params.conversation.type,
    title: params.conversation.title,
    createdBy: params.conversation.createdBy,
    latestSequence: params.conversation.latestSequence,
    members: params.members.map(({ member, profile }) => {
      return {
        userId: member.userId,
        role: member.role,
        joinedAt: member.joinedAt.toISOString(),
        profile,
      };
    }),
    createdAt: params.conversation.createdAt.toISOString(),
    updatedAt: params.conversation.updatedAt.toISOString(),
  };
}
