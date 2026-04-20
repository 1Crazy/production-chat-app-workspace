export const REALTIME_NAMESPACE = '/chat';

export const REALTIME_EVENTS = {
  connectionReady: 'connection.ready',
  connectionError: 'connection.error',
  presenceUpdated: 'presence.updated',
  conversationCreated: 'conversation.created',
  messageCreated: 'message.created',
  readCursorUpdated: 'read-cursor.updated',
  typingUpdated: 'typing.updated',
  sessionRevoked: 'session.revoked',
} as const;

export function buildUserRoom(userId: string): string {
  return `user:${userId}`;
}

export function buildSessionRoom(sessionId: string): string {
  return `session:${sessionId}`;
}

export function buildConversationRoom(conversationId: string): string {
  return `conversation:${conversationId}`;
}
