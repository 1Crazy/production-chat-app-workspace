import type { DeviceSessionView, AuthUserView } from '@app/modules/auth/dto/auth-response.dto';
import type { ConversationView } from '@app/modules/conversations/dto/conversation.dto';
import type { ReadCursorView } from '@app/modules/conversations/dto/read-cursor.dto';
import type { MessageView } from '@app/modules/messages/dto/message.dto';

export interface UserPresenceView {
  userId: string;
  isOnline: boolean;
  activeConnectionCount: number;
  activeSessionCount: number;
  lastSeenAt: string | null;
}

export interface ConversationStateView {
  conversationId: string;
  latestSequence: number;
}

export interface ConnectionReadyEvent {
  connectionId: string;
  recovered: boolean;
  serverTime: string;
  user: AuthUserView;
  session: DeviceSessionView;
  activeConnectionCount: number;
  conversationStates: ConversationStateView[];
  presence: UserPresenceView[];
}

export interface ConnectionErrorEvent {
  code: 'UNAUTHORIZED' | 'UNKNOWN';
  message: string;
}

export interface ConversationCreatedEvent {
  conversation: ConversationView;
}

export interface MessageCreatedEvent {
  message: MessageView;
}

export interface ReadCursorUpdatedEvent {
  readCursor: ReadCursorView;
}

export interface TypingUpdatedEvent {
  conversationId: string;
  userId: string;
  isTyping: boolean;
  expiresAt: string | null;
}

export interface SessionRevokedEvent {
  sessionId: string;
  reason: string;
}
