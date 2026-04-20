import type { MessageView } from './message.dto';

import type { ReadCursorView } from '@app/modules/conversations/dto/read-cursor.dto';
import type { UserDiscoveryProfileDto } from '@app/modules/users/dto/user-profile.dto';

export interface MessageHistoryCursorDto {
  beforeSequence: number;
}

export interface MessageHistoryPageDto {
  conversationId: string;
  latestSequence: number;
  items: MessageView[];
  readCursors: ReadCursorView[];
  memberProfiles: UserDiscoveryProfileDto[];
  nextCursor: MessageHistoryCursorDto | null;
}

export interface MessageSyncDto {
  conversationId: string;
  latestSequence: number;
  nextAfterSequence: number;
  hasMore: boolean;
  items: MessageView[];
}
