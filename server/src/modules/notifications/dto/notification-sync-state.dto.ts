import type { ConversationSummaryView } from '@app/modules/conversations/dto/conversation-summary.dto';
import type { MessageSyncDto } from '@app/modules/messages/dto/message-history.dto';

export interface NotificationSyncStateDto {
  serverTime: string;
  unreadBadgeCount: number;
  conversations: ConversationSummaryView[];
  gaps: MessageSyncDto[];
  recoveredPushMessageId: string | null;
}
